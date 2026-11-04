local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools or {}

local VERSION = "2.4.2"
local floor = math.floor
local GetTime = GetTime
local IsSecret = issecretvalue or function() return false end

local GARROTE_SPELL_ID = 703
local ASSASSINATION_SPEC_ID = 259
local MAX_NAMEPLATES = 40
local SENSOR_BASE_WIDTH = 1
local SENSOR_AURA_WIDTH = 150
local COVERAGE_FRAME_WIDTH = 128

local DEFAULTS = {
  enabled = true,
  x = 0,
  y = -153,
  locked = true,
  throttle = 0.20,
  showFrom = 2,
  pulseFrom = 3,
  fontSize = 28,
  fontName = "GothamNarrowUltra",
  range = 8,
  breathScale = 0.04,
  garroteCoverage = true,
}

local db
local rangeLib
local providerName = "none"
local providerMinor = "?"
local warnedNoProvider = false
local elapsed = 0
local testCount = nil
local displayedCount = nil
local activeFontPath = STANDARD_TEXT_FONT
local activeFontName = "STANDARD_TEXT_FONT"
local currentSpecID = nil
local coverageActive = false
local coverageTotal = nil
local rangeUnits = {}
local wantedUnits = {}
local freeSensors = {}
local garroteSensors = {}
local sensorUnit = {}
local unitSensor = {}
local coverageLabels = {}
local coverageSensorReady = false
local coverageSensorAttempted = false
local coverageSensorStatus = "NOT_INITIALIZED"

local function MergeDefaults(dst, src)
  dst = type(dst)=="table" and dst or {}
  for k,v in pairs(src) do
    if dst[k]==nil then dst[k]=v end
  end
  return dst
end

local function BindDB()
  if NT and type(NT.BindModuleDB)=="function" then NT:BindModuleDB() end
  NiniEnemyCountDB = MergeDefaults(type(NiniEnemyCountDB)=="table" and NiniEnemyCountDB or {}, DEFAULTS)
  if type(NiniToolsDB)=="table" and type(NiniToolsDB.modules)=="table" then
    NiniToolsDB.modules.enemyCount = NiniEnemyCountDB
  end
  db = NiniEnemyCountDB
  return db
end

local function ResolveFont()
  local wanted = (db and db.fontName) or DEFAULTS.fontName
  -- 2.5.4: 기본값이면 NiniTools 공통 숫자 글꼴(GothamNarrowUltraKR 우선)을 따른다.
  if wanted == DEFAULTS.fontName and NT and type(NT.ResolveFont)=="function" then
    local ok, path, src = pcall(NT.ResolveFont, NT, "num")
    if ok and type(path)=="string" and path~="" then
      activeFontPath = path
      activeFontName = src or wanted
      return path
    end
  end
  if LibStub and type(LibStub.GetLibrary)=="function" then
    local ok, lsm = pcall(LibStub.GetLibrary, LibStub, "LibSharedMedia-3.0", true)
    if ok and lsm and type(lsm.Fetch)=="function" then
      local okFetch, path = pcall(lsm.Fetch, lsm, "font", wanted, true)
      if okFetch and type(path)=="string" and path~="" then
        activeFontPath = path
        activeFontName = wanted
        return path
      end
    end
  end
  activeFontPath = STANDARD_TEXT_FONT
  activeFontName = "STANDARD_TEXT_FONT (fallback)"
  return activeFontPath
end

-- Display frame only. Detection stays alive on the separate driver even while hidden.
local frame = CreateFrame("Frame", "NiniToolsEnemyCountFrame", UIParent)
frame:SetSize(COVERAGE_FRAME_WIDTH,54)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -153)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(false)

-- Crisp 1px solid black outline around the number.
-- WoW FontString outline color cannot be set independently, so eight 1px black
-- copies are drawn behind the main glyph. No glow or blur.
local outlineTexts = {}
local outlineOffsets = {
  {-1,0},{1,0},{0,-1},{0,1},
  {-1,-1},{1,-1},{-1,1},{1,1},
}
for i,off in ipairs(outlineOffsets) do
  local o = frame:CreateFontString(nil, "ARTWORK")
  o:SetPoint("CENTER", frame, "CENTER", off[1], off[2])
  o:SetFont(STANDARD_TEXT_FONT, 28, "")
  o:SetJustifyH("CENTER")
  o:SetTextColor(0,0,0,1)
  o:SetText("")
  outlineTexts[i]=o
end

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")
text:SetFont(STANDARD_TEXT_FONT, 28, "")
text:SetJustifyH("CENTER")
text:SetText("")

-- Assassination Garrote coverage overlay.
-- The aura count itself is intentionally never read into Lua. Blizzard's
-- CustomAuraContainer layout moves a hidden sensor chain, and pre-positioned
-- labels are clipped so only the matching "Garrote / EnemyCount" value is visible.
local coverageViewport = CreateFrame("Frame", nil, frame)
coverageViewport:SetAllPoints(frame)
coverageViewport:SetClipsChildren(true)
coverageViewport:SetFrameLevel(frame:GetFrameLevel()+4)
coverageViewport:Hide()

local coverageTail = nil

local moveBG = frame:CreateTexture(nil,"BACKGROUND")
moveBG:SetAllPoints()
moveBG:SetColorTexture(0.05,0.65,1.0,0.18)
moveBG:Hide()

local moveLabel = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
moveLabel:SetPoint("TOP",frame,"BOTTOM",0,-2)
moveLabel:SetText("Nini Enemy Count")
moveLabel:Hide()

local driver = CreateFrame("Frame", nil, UIParent)

local function ApplyFonts()
  local fontPath=ResolveFont()
  local size=(db and db.fontSize) or DEFAULTS.fontSize
  text:SetFont(fontPath,size,"")
  for _,o in ipairs(outlineTexts) do o:SetFont(fontPath,size,"") end
  for _,entry in pairs(coverageLabels) do
    entry.main:SetFont(fontPath,size,"")
    for _,o in ipairs(entry.outlines) do o:SetFont(fontPath,size,"") end
  end
  moveLabel:SetFont(fontPath,12,"OUTLINE")
end

local function SetOutlineText(value)
  for _,o in ipairs(outlineTexts) do
    o:SetText(value)
    o:SetTextColor(0,0,0,1)
    o:SetAlpha(1)
  end
end


local function SetPlainTextShown(shown)
  text:SetShown(shown)
  for _,o in ipairs(outlineTexts) do o:SetShown(shown) end
end

local function GetCurrentSpecID()
  local getIndex=(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getInfo=(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if type(getIndex)~="function" or type(getInfo)~="function" then return nil end
  local okIndex,index=pcall(getIndex)
  if not okIndex or IsSecret(index) or not index then return nil end
  local okInfo,specID=pcall(getInfo,index)
  if not okInfo or IsSecret(specID) then return nil end
  return tonumber(specID)
end

local function RefreshCurrentSpec()
  currentSpecID=GetCurrentSpecID()
end

local function StopCoverageAnimations(entry)
  if entry.shake and entry.shake:IsPlaying() then entry.shake:Stop() end
  if entry.blink and entry.blink:IsPlaying() then entry.blink:Stop() end
  entry:SetAlpha(1)
end

local function StartCoverageAnimations(entry)
  if entry.shake and not entry.shake:IsPlaying() then entry.shake:Play() end
  if entry.blink and not entry.blink:IsPlaying() then entry.blink:Play() end
end

local function CoverageTailDistance(score)
  return score*SENSOR_AURA_WIDTH + (MAX_NAMEPLATES-score)*SENSOR_BASE_WIDTH
end

local function MakeCoverageLabel(score)
  local holder=CreateFrame("Frame",nil,coverageTail)
  holder:SetSize(COVERAGE_FRAME_WIDTH,54)
  holder:SetPoint("TOPLEFT",coverageTail,"TOPLEFT",-CoverageTailDistance(score),0)
  holder.outlines={}

  for _,off in ipairs(outlineOffsets) do
    local o=holder:CreateFontString(nil,"ARTWORK")
    o:SetPoint("CENTER",holder,"CENTER",off[1],off[2])
    o:SetFont(activeFontPath,(db and db.fontSize) or DEFAULTS.fontSize,"")
    o:SetJustifyH("CENTER")
    o:SetTextColor(0,0,0,1)
    holder.outlines[#holder.outlines+1]=o
  end

  holder.main=holder:CreateFontString(nil,"OVERLAY")
  holder.main:SetPoint("CENTER")
  holder.main:SetFont(activeFontPath,(db and db.fontSize) or DEFAULTS.fontSize,"")
  holder.main:SetJustifyH("CENTER")

  holder.shake=holder:CreateAnimationGroup()
  holder.shake:SetLooping("REPEAT")
  local shakeOffsets={2,-4,4,-2}
  for order,dx in ipairs(shakeOffsets) do
    local a=holder.shake:CreateAnimation("Translation")
    a:SetOffset(dx,0)
    a:SetDuration(0.055)
    a:SetOrder(order)
  end

  holder.blink=holder:CreateAnimationGroup()
  holder.blink:SetLooping("REPEAT")
  local fadeOut=holder.blink:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0.42)
  fadeOut:SetDuration(0.34)
  fadeOut:SetOrder(1)
  local fadeIn=holder.blink:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0.42)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.34)
  fadeIn:SetOrder(2)

  holder:Hide()
  coverageLabels[score]=holder
  return holder
end

local function SetCoverageLabelText(entry,value)
  entry.main:SetText(value)
  for _,o in ipairs(entry.outlines) do o:SetText(value) end
end

local function PrepareCoverageLabels(total)
  if not coverageTail then return end
  if coverageTotal==total then return end
  coverageTotal=total

  for score=0,MAX_NAMEPLATES do
    local entry=coverageLabels[score] or MakeCoverageLabel(score)
    if score<=total then
      SetCoverageLabelText(entry,("%d/%d"):format(score,total))
      if score==total and total>0 then
        StopCoverageAnimations(entry)
        entry.main:SetTextColor(0.28,1.0,0.38,1)
      else
        entry.main:SetTextColor(1.0,0.22,0.06,1)
        if coverageActive then StartCoverageAnimations(entry) else StopCoverageAnimations(entry) end
      end
      entry:Show()
    else
      StopCoverageAnimations(entry)
      entry:Hide()
    end
  end
end

local function PauseCoverageAnimations()
  for _,entry in pairs(coverageLabels) do
    StopCoverageAnimations(entry)
  end
end

local function ResumeCoverageAnimations(total)
  for score=0,total do
    local entry=coverageLabels[score]
    if entry then
      if score==total and total>0 then
        StopCoverageAnimations(entry)
      else
        StartCoverageAnimations(entry)
      end
    end
  end
end

local function ReleaseGarroteSensor(sensor)
  if not sensor then return end
  local oldUnit=sensorUnit[sensor]
  if oldUnit then unitSensor[oldUnit]=nil end
  sensorUnit[sensor]=nil

  -- Clear the unit binding before disabling, then force the container back to
  -- its 1px baseline. This prevents an out-of-range/removed unit from retaining
  -- the last 150px aura-layout extent and inflating the hidden coverage total.
  if type(sensor.SetUnit)=="function" then pcall(sensor.SetUnit,sensor,nil) end
  sensor:SetEnabled(false)
  -- AuraContainer may forbid untrusted layout changes after AddAuraGroup.
  -- Keep release resilient instead of letting a protected SetSize abort cleanup.
  if type(sensor.SetSize)=="function" then
    pcall(sensor.SetSize,sensor,SENSOR_BASE_WIDTH,1)
  end
end

local function ResetGarroteSensorUnit(unit)
  if not unit then return end
  local sensor=unitSensor[unit]
  if sensor then ReleaseGarroteSensor(sensor) end
end

local function DisableGarroteSensors()
  for _,sensor in ipairs(garroteSensors) do
    if sensorUnit[sensor] then ReleaseGarroteSensor(sensor) end
  end
end

local function MakeAuraElementInvisible(widget)
  -- initializeFrame runs before Blizzard locks the aura button down, but keep
  -- every button mutation guarded so a restricted button cannot break setup.
  if widget.SetMouseMotionEnabled then pcall(widget.SetMouseMotionEnabled,widget,false) end
  if widget.SetAlpha then pcall(widget.SetAlpha,widget,0) end
end

local function BuildGarroteSensors()
  local tailTemplate=nil
  local okTail,tailInfo=pcall(C_XMLUtil.GetTemplateInfo,"DisableUntrustedLayoutScriptsTemplate")
  if okTail and tailInfo then tailTemplate="DisableUntrustedLayoutScriptsTemplate" end

  -- Important: build and anchor the entire sensor chain before registering any
  -- aura group. AddAuraGroup marks an AuraContainer as forbidding untrusted
  -- layout scripts. If sensor 1 is configured before sensor 2 is anchored to
  -- it, sensor 2:SetPoint() can fail with UntrustedLayoutScriptExecution.
  --
  -- This is deliberately two-pass: first create/size/anchor every container,
  -- then register aura groups from the end of the chain back to the start.
  local previous=nil
  for i=1,MAX_NAMEPLATES do
    local sensor=CreateFrame("AuraContainer",nil,coverageViewport,"CustomAuraContainerTemplate")
    sensor:SetSize(SENSOR_BASE_WIDTH,1)
    if previous then
      sensor:SetPoint("TOPLEFT",previous,"TOPRIGHT",0,0)
    else
      sensor:SetPoint("TOPLEFT",coverageViewport,"TOPLEFT",0,0)
    end
    sensor:SetFlowLayoutAnchorPoint("TOPLEFT")
    sensor:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Down)
    sensor:SetFlowLayoutMaximumLineSize(math.huge)
    sensor:SetAlpha(0)
    sensor:SetEnabled(false)
    garroteSensors[i]=sensor
    previous=sensor
  end

  -- Configure in reverse order so a container never newly imposes forbidden
  -- layout aspects on a still-unrestricted dependent container.
  for i=#garroteSensors,1,-1 do
    local sensor=garroteSensors[i]
    sensor:AddAuraGroup("nini-garrote","HARMFUL|PLAYER",{
      maxFrameCount=1,
      candidateFilters={includeSpellIDs={[GARROTE_SPELL_ID]=true}},
      initializeFrame=MakeAuraElementInvisible,
      layout={
        elementWidth=SENSOR_AURA_WIDTH,
        elementHeight=1,
        elementSpacing=0,
        lineSpacing=0,
      },
    })
  end

  -- The tail uses Blizzard's safe layout template because it intentionally
  -- follows the final restricted AuraContainer.
  coverageTail=CreateFrame("Frame",nil,coverageViewport,tailTemplate)
  coverageTail:SetSize(COVERAGE_FRAME_WIDTH,54)
  if previous then
    coverageTail:SetPoint("TOPLEFT",previous,"TOPRIGHT",0,0)
  else
    coverageTail:SetPoint("TOPLEFT",coverageViewport,"TOPLEFT",0,0)
  end
end

local function InitGarroteSensors()
  if coverageSensorReady then return true end

  -- AuraContainer creation is forbidden in combat in 12.1.  RC5 initialized
  -- lazily on the first 2+ target scan, which normally happens after combat
  -- starts; that could fail once and leave the old attempted flag stuck false.
  -- Build the fixed sensor pool only out of combat and allow a later retry.
  if type(InCombatLockdown)=="function" and InCombatLockdown() then
    coverageSensorStatus="DEFERRED_IN_COMBAT"
    return false
  end

  if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo)~="function" then
    coverageSensorStatus="NO_C_XMLUTIL"
    return false
  end
  local okTemplate,templateInfo=pcall(C_XMLUtil.GetTemplateInfo,"CustomAuraContainerTemplate")
  if not okTemplate or not templateInfo then
    coverageSensorStatus="NO_AURA_TEMPLATE"
    return false
  end
  if not AnchorUtil or not AnchorUtil.FlowDirection then
    coverageSensorStatus="NO_ANCHORUTIL"
    return false
  end

  coverageSensorAttempted=true
  local ok,err=pcall(BuildGarroteSensors)
  if not ok then
    coverageSensorStatus="CREATE_FAILED: "..tostring(err)
    -- Do not permanently cache a failed attempt.  A later out-of-combat event
    -- may run after the required Blizzard UI pieces are fully available.
    coverageSensorAttempted=false
    return false
  end

  coverageSensorReady=true
  coverageSensorStatus="READY"
  PrepareCoverageLabels(0)
  return true
end

local function SyncGarroteSensors(units,count)
  if not coverageSensorReady then return end
  wipe(wantedUnits)
  wipe(freeSensors)

  for i=1,count do
    wantedUnits[units[i]]=true
  end

  for _,sensor in ipairs(garroteSensors) do
    local oldUnit=sensorUnit[sensor]
    if oldUnit and not wantedUnits[oldUnit] then
      ReleaseGarroteSensor(sensor)
      oldUnit=nil
    end
    if not oldUnit then
      freeSensors[#freeSensors+1]=sensor
    end
  end

  for i=1,count do
    local unit=units[i]
    if not unitSensor[unit] then
      local sensor=table.remove(freeSensors)
      if not sensor then break end
      sensor:SetUnit(unit)
      sensor:SetEnabled(true)
      unitSensor[unit]=sensor
      sensorUnit[sensor]=unit
    end
  end
end

local function GarroteCoverageMode()
  if testCount~=nil then return false end
  if not db or db.garroteCoverage==false then return false end
  if currentSpecID~=ASSASSINATION_SPEC_ID then return false end
  return InitGarroteSensors()
end

local function RefreshRangeProvider()
  rangeLib=nil
  providerName="none"
  providerMinor="?"

  if not LibStub then
    if not warnedNoProvider then
      warnedNoProvider=true
      print("|cff00cfffNiniTools Enemy Count:|r LibStub을 찾을 수 없습니다.")
    end
    return
  end

  local ok,lib,minor=pcall(LibStub.GetLibrary,LibStub,"LibRangeCheck-3.0",true)
  if ok and lib and type(lib.GetRange)=="function" then
    rangeLib=lib
    providerName="LibRangeCheck-3.0"
    providerMinor=minor or (LibStub.minors and LibStub.minors["LibRangeCheck-3.0"]) or "?"
    warnedNoProvider=false
    return
  end

  if not warnedNoProvider then
    warnedNoProvider=true
    print("|cff00cfffNiniTools Enemy Count:|r LibRangeCheck-3.0을 찾을 수 없습니다.")
  end
end

local function CurrentRange()
  return (db and db.range) or DEFAULTS.range
end

local function IsHostileNameplate(unit)
  local exists=UnitExists(unit)
  if IsSecret(exists) or not exists then return false end
  local ok,canAttack=pcall(UnitCanAttack,"player",unit)
  if not ok or IsSecret(canAttack) then return false end
  return canAttack==true
end

local function IsUnitInRange(unit, range)
  if not rangeLib then return false end
  local ok,minRange,maxRange=pcall(rangeLib.GetRange,rangeLib,unit,true)
  if not ok then return false end
  if IsSecret(minRange) or IsSecret(maxRange) then return false end
  if maxRange==nil then return false end
  return maxRange<=range
end

local function ScanEnemies()
  wipe(rangeUnits)
  if testCount~=nil then return testCount,rangeUnits end
  if not db or db.enabled==false then return 0,rangeUnits end

  local _,class=UnitClass("player")
  if class~="ROGUE" then return 0,rangeUnits end
  if not rangeLib then return 0,rangeUnits end

  local range=CurrentRange()
  local count=0
  for i=1,MAX_NAMEPLATES do
    local unit="nameplate"..i
    if IsHostileNameplate(unit) then
      local ok,inRange=pcall(IsUnitInRange,unit,range)
      if ok and not IsSecret(inRange) and inRange==true then
        count=count+1
        rangeUnits[count]=unit
      end
    end
  end
  return count,rangeUnits
end

local function CountEnemies()
  local count=ScanEnemies()
  return count
end

local function GetAlertVisual(now)
  if NT and type(NT.GetAlertColor)=="function" then
    local r,g,b,t=NT:GetAlertColor(now)
    return r,g,b,t
  end
  local period=1.40
  local phase=((now%period)/period)*2*math.pi
  local t=(math.sin(phase-(math.pi/2))+1)*0.5
  return 1,0.22+(0.72-0.22)*t,0.05+(0.08-0.05)*t,t
end

local function SetNormalVisual(count)
  if coverageActive then PauseCoverageAnimations() end
  coverageActive=false
  coverageViewport:Hide()
  SetPlainTextShown(true)
  frame:SetScale(1)
  text:SetAlpha(1)
  local value=tostring(count)
  SetOutlineText(value)
  text:SetTextColor(1,0.9568628,0.4352941,1)
  text:SetText(value)
end

local function SetPulseVisual(count, now)
  if coverageActive then PauseCoverageAnimations() end
  coverageActive=false
  coverageViewport:Hide()
  SetPlainTextShown(true)
  local r,g,b,t=GetAlertVisual(now)
  local style=(NT and NT.ALERT_STYLE) or {}
  local alphaMin=tonumber(style.alphaMin) or 0.90
  local s=tostring(count)

  -- 3+ targets: a very subtle scale breath, synchronized with the color/alpha breath.
  -- 1.00 -> 1.04 -> 1.00 by default; small enough to avoid the old bobbing feel.
  local scaleAmount=tonumber(db and db.breathScale) or DEFAULTS.breathScale
  frame:SetScale(1 + scaleAmount*t)
  SetOutlineText(s)
  text:SetText(s)
  text:SetTextColor(r,g,b,1)
  text:SetAlpha(alphaMin+(1-alphaMin)*t)
end

local function ShowGarroteCoverage(count,units)
  local wasActive=coverageActive
  coverageActive=true
  frame:SetScale(1)
  SetPlainTextShown(false)
  PrepareCoverageLabels(count)
  if not wasActive then ResumeCoverageAnimations(count) end
  SyncGarroteSensors(units,count)
  coverageViewport:Show()
end

local function HideDisplay()
  displayedCount=nil
  if coverageActive then PauseCoverageAnimations() end
  coverageActive=false
  coverageViewport:Hide()
  DisableGarroteSensors()
  frame:Hide()
end

local function UpdateDisplay(now)
  if not db or db.enabled==false then
    HideDisplay()
    return
  end

  local count,units=ScanEnemies()
  if IsSecret(count) then HideDisplay(); return end
  if count<db.showFrom then HideDisplay(); return end

  displayedCount=count
  frame:Show()

  if GarroteCoverageMode() then
    ShowGarroteCoverage(count,units)
  else
    DisableGarroteSensors()
    if count>=db.pulseFrom then SetPulseVisual(count,now) else SetNormalVisual(count) end
  end
end

local function ApplyPosition()
  if not db then return end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER",UIParent,"CENTER",db.x or DEFAULTS.x,db.y or DEFAULTS.y)
  ApplyFonts()
end

local function SetLocked(locked)
  if not db then return end
  db.locked=locked and true or false
  frame:EnableMouse(not db.locked)

  if db.locked then
    frame:RegisterForDrag()
    moveBG:Hide(); moveLabel:Hide()
    return
  end

  frame:RegisterForDrag("LeftButton")
  moveBG:Show(); moveLabel:Show()
  if testCount==nil then testCount=2 end
  frame:Show(); SetNormalVisual(testCount)
end

frame:SetScript("OnDragStart",function(self)
  if not db or db.locked then return end
  self:StartMoving()
end)

frame:SetScript("OnDragStop",function(self)
  self:StopMovingOrSizing()
  if not db then return end
  local cx,cy=self:GetCenter()
  local ux,uy=UIParent:GetCenter()
  if cx and cy and ux and uy then
    db.x=floor((cx-ux)+0.5)
    db.y=floor((cy-uy)+0.5)
  end
end)

local function DriverOnUpdate(_,dt)
  if not db or db.enabled==false then
    driver:SetScript("OnUpdate",nil)
    elapsed=0
    return
  end
  elapsed=elapsed+dt

  if not coverageActive and displayedCount and frame:IsShown() and displayedCount>=db.pulseFrom then
    SetPulseVisual(displayedCount,GetTime())
  end

  if elapsed<db.throttle then return end
  elapsed=0
  UpdateDisplay(GetTime())
end

local function SetDriverActive(active)
  if active then
    driver:SetScript("OnUpdate",DriverOnUpdate)
  else
    driver:SetScript("OnUpdate",nil)
    elapsed=0
  end
end

local events=_G.NiniTools.EventDispatcher:CreateProxy("Combat.EnemyCount")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
local nameplateEventsRegistered=true
local function SyncNameplateEvents()
  local want=db and db.enabled~=false and db.garroteCoverage~=false or false
  if want==nameplateEventsRegistered then return end
  nameplateEventsRegistered=want
  for _,event in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED"}) do
    if want then events:RegisterEvent(event) else events:UnregisterEvent(event) end
  end
end
events:SetScript("OnEvent",function(_,event,arg1)
  if event=="ADDON_LOADED" and arg1==ADDON_NAME then
    BindDB(); ApplyPosition(); RefreshCurrentSpec(); RefreshRangeProvider(); SetLocked(db.locked); frame:Hide(); SetDriverActive(db.enabled~=false); SyncNameplateEvents(); return
  end
  if event=="PLAYER_LOGIN" then
    if not db then BindDB() end
    RefreshCurrentSpec(); RefreshRangeProvider(); ApplyFonts(); SetDriverActive(db.enabled~=false); SyncNameplateEvents()
    if db.garroteCoverage~=false then InitGarroteSensors() end
    UpdateDisplay(GetTime()); return
  end
  if event=="PLAYER_REGEN_ENABLED" then
    if db and db.garroteCoverage~=false and not coverageSensorReady then InitGarroteSensors() end
    if db then UpdateDisplay(GetTime()) end
    return
  end
  if event=="NAME_PLATE_UNIT_ADDED" or event=="NAME_PLATE_UNIT_REMOVED" then
    -- Nameplate tokens are recycled aggressively. While Garrote coverage is
    -- actually active, detach only the recycled token here. Do not force a full
    -- 1..40 range scan for every nameplate event; the existing 0.20s driver
    -- re-evaluates range membership and rebinds the token on its next pass.
    if coverageActive and coverageSensorReady then ResetGarroteSensorUnit(arg1) end
    return
  end
  if event=="PLAYER_SPECIALIZATION_CHANGED" then
    RefreshCurrentSpec()
    SyncNameplateEvents()
    DisableGarroteSensors()
    coverageTotal=nil
    UpdateDisplay(GetTime())
    return
  end
  if db then RefreshCurrentSpec(); RefreshRangeProvider(); SetDriverActive(db.enabled~=false); UpdateDisplay(GetTime()) end
end)

local function GarroteDebugReport()
  local function SortTokens(list)
    table.sort(list,function(a,b)
      local ai=tonumber(tostring(a):match("(%d+)$")) or math.huge
      local bi=tonumber(tostring(b):match("(%d+)$")) or math.huge
      if ai==bi then return tostring(a)<tostring(b) end
      return ai<bi
    end)
  end

  local rangeTokens={}
  for i=1,#rangeUnits do
    local unit=rangeUnits[i]
    if unit then rangeTokens[#rangeTokens+1]=unit end
  end
  SortTokens(rangeTokens)

  local sensorTokens={}
  for _,sensor in ipairs(garroteSensors) do
    local unit=sensorUnit[sensor]
    if unit then sensorTokens[#sensorTokens+1]=unit end
  end
  SortTokens(sensorTokens)

  local denominator=#rangeTokens
  local connected=#sensorTokens
  local labelDenominator=coverageActive and coverageTotal or nil

  print("|cff00cfffNiniTools Garrote Debug|r")
  print(("Active: %s / Spec: %s / AuraSensor: %s"):format(
    coverageActive and "ON" or "OFF",
    tostring(currentSpecID or "?"),
    coverageSensorReady and "READY" or tostring(coverageSensorStatus or "NOT READY")
  ))
  print(("EnemyCount(last scan): %d / Label denominator: %s"):format(
    denominator, tostring(labelDenominator or "-")
  ))
  print(("Range tokens (%d): %s"):format(
    denominator, denominator>0 and table.concat(rangeTokens,", ") or "none"
  ))
  print(("Connected sensors (%d): %s"):format(
    connected, connected>0 and table.concat(sensorTokens,", ") or "none"
  ))
  if coverageActive and connected~=denominator then
    print(("|cffff6666Mismatch:|r sensors %d / denominator %d"):format(connected,denominator))
  end
end

SLASH_NINITOOLSENEMYCOUNT1="/nec"
SLASH_NINITOOLSENEMYCOUNT2="/nenemy"
SlashCmdList.NINITOOLSENEMYCOUNT=function(msg)
  if not db then BindDB() end
  msg=(msg or ""):lower():match("^%s*(.-)%s*$")

  if msg=="unlock" then
    testCount=2; SetLocked(false); UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 이동 모드 - 드래그 후 /nec lock")
    return
  end
  if msg=="lock" then
    testCount=nil; SetLocked(true); UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 위치 잠금")
    return
  end
  if msg=="reset" then
    db.x,db.y=DEFAULTS.x,DEFAULTS.y; ApplyPosition(); UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 위치 초기화")
    return
  end
  if msg=="on" then
    db.enabled=true; SetDriverActive(true); SyncNameplateEvents(); UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r ON")
    return
  end
  if msg=="off" then
    db.enabled=false; testCount=nil; displayedCount=nil; SetDriverActive(false); SyncNameplateEvents(); HideDisplay()
    print("|cff00cfffNiniTools Enemy Count:|r OFF")
    return
  end
  if msg=="test off" then
    testCount=nil; UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 테스트 종료")
    return
  end

  local testNumber=msg:match("^test%s+(%d+)$")
  if testNumber then
    local n=tonumber(testNumber)
    testCount=n
    if db.enabled==false then db.enabled=true end
    SetDriverActive(true)
    UpdateDisplay(GetTime())
    print(("|cff00cfffNiniTools Enemy Count:|r 테스트 %d타겟"):format(n))
    return
  end

  if msg=="garrote on" then
    db.garroteCoverage=true
    SyncNameplateEvents()
    coverageTotal=nil
    InitGarroteSensors()
    UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 목조르기 커버리지 ON")
    return
  end
  if msg=="garrote off" then
    db.garroteCoverage=false
    SyncNameplateEvents()
    coverageTotal=nil
    DisableGarroteSensors()
    UpdateDisplay(GetTime())
    print("|cff00cfffNiniTools Enemy Count:|r 목조르기 커버리지 OFF")
    return
  end
  if msg=="garrote debug" then
    GarroteDebugReport()
    return
  end

  if msg=="status" then
    print("|cff00cfffNiniTools Enemy Count|r "..VERSION)
    print(("Provider: %s / Minor: %s"):format(tostring(providerName),tostring(providerMinor)))
    print(("Range: %dy / Show: %d+ / Breath: %d+"):format(CurrentRange(),db.showFrom,db.pulseFrom))
    print(("Font: %s / Breath: %.2fs / Scale: 1.00~%.2f / Enabled: %s"):format(
      tostring(activeFontName),
      tonumber((NT.ALERT_STYLE or {}).period) or 1.40,
      1 + (tonumber(db.breathScale) or DEFAULTS.breathScale),
      db.enabled~=false and "ON" or "OFF"
    ))
    local sensorOK=InitGarroteSensors()
    print(("Garrote/Enemy: %s / Spec: %s / AuraSensor: %s"):format(
      db.garroteCoverage~=false and "ON" or "OFF",
      tostring(currentSpecID or "?"),
      sensorOK and "READY" or tostring(coverageSensorStatus or "UNAVAILABLE")
    ))
    return
  end

  print("|cff00cfffNiniTools Enemy Count "..VERSION.."|r")
  print("/nec test 1 - 숨김 테스트")
  print("/nec test 2 - 일반 숫자 테스트")
  print("/nec test 3 - 숨쉬기 + 미세 크기 변화 + 검정 1px 외곽선 테스트")
  print("/nec test 5 - 5타겟 테스트")
  print("/nec test off - 테스트 종료")
  print("/nec unlock - 위치 이동")
  print("/nec lock - 위치 잠금")
  print("/nec reset - 위치 초기화")
  print("/nec on | off - 기능 켜기/끄기")
  print("/nec garrote on | off - 암살 목조르기 커버리지 켜기/끄기")
  print("/nec garrote debug - 범위 토큰/센서 연결 상태 확인")
  print("/nec status - 상태 확인")
  print("암살: EnemyCount 앞에 목조르기 대상 수를 붙여 7/12 형식으로 표시")
end

local API={
  frame=frame,
  driver=driver,
  UpdateDisplay=UpdateDisplay,
  CountEnemies=CountEnemies,
  CurrentRange=CurrentRange,
  GetRangeLib=function() return rangeLib end,
  GetRangeUnits=function() return rangeUnits end,
  IsGarroteCoverageReady=function() return coverageSensorReady or InitGarroteSensors() end,
  GetDB=function() if not db then BindDB() end; return db end,
  SetEnabled=function(v)
    if not db then BindDB() end
    db.enabled=v and true or false
    SyncNameplateEvents()
    if db.enabled==false then
      testCount=nil
      displayedCount=nil
      SetDriverActive(false)
      HideDisplay()
    else
      SetDriverActive(true)
    end
    UpdateDisplay(GetTime())
  end,
  SetGarroteCoverage=function(v)
    if not db then BindDB() end
    db.garroteCoverage=v and true or false
    SyncNameplateEvents()
    coverageTotal=nil
    if db.garroteCoverage==false then
      DisableGarroteSensors()
    else
      InitGarroteSensors()
    end
    UpdateDisplay(GetTime())
  end,
  IsGarroteCoverageEnabled=function()
    if not db then BindDB() end
    return db.garroteCoverage~=false
  end,
  IsEnabled=function() return db and db.enabled~=false end,
  SetUnlocked=function(v)
    if not db then BindDB() end
    if v then
      testCount=testCount or 2
      SetLocked(false)
    else
      testCount=nil
      SetLocked(true)
    end
    UpdateDisplay(GetTime())
  end,
  IsUnlocked=function() return db and db.locked==false end,
  ResetPosition=function()
    if not db then BindDB() end
    db.x,db.y=DEFAULTS.x,DEFAULTS.y
    ApplyPosition()
    UpdateDisplay(GetTime())
  end,
  GetFontSize=function()
    if not db then BindDB() end
    return tonumber(db.fontSize) or DEFAULTS.fontSize
  end,
  SetFontSize=function(v)
    if not db then BindDB() end
    v=math.floor((tonumber(v) or DEFAULTS.fontSize)+0.5)
    if v<18 then v=18 elseif v>48 then v=48 end
    db.fontSize=v
    ApplyFonts()
    UpdateDisplay(GetTime())
    return v
  end,
  AdjustFontSize=function(step)
    if not db then BindDB() end
    local current=tonumber(db.fontSize) or DEFAULTS.fontSize
    local v=math.floor(current + (tonumber(step) or 0) + 0.5)
    if v<18 then v=18 elseif v>48 then v=48 end
    db.fontSize=v
    ApplyFonts()
    UpdateDisplay(GetTime())
    return v
  end,
  SetTestCount=function(v)
    if not db then BindDB() end
    if v==nil or v==false then
      testCount=nil
    else
      local n=math.floor((tonumber(v) or 0)+0.5)
      testCount=math.max(0,n)
      if db.enabled==false then db.enabled=true end
      SetDriverActive(true)
    end
    UpdateDisplay(GetTime())
  end,
  GetTestCount=function() return testCount end,
}
_G.NiniEnemyCount=API
