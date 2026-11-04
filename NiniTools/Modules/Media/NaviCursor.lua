local _, NT = ...
if not NT then return end

-- Alive-only Navi cursor integrated into NiniTools.
-- No death state, no AFK test, no secure state driver.
-- 2.3.0: ring/glow/scale settings used by the unified Sound & Navi UI.

local driver = CreateFrame("Frame")
local mouseFrame = CreateFrame("Frame", nil, UIParent)
mouseFrame:SetSize(1, 1)
mouseFrame:SetFrameStrata("MEDIUM")
mouseFrame:Show()

local function clamp(v,lo,hi)
  v=tonumber(v) or lo
  if v<lo then return lo end
  if v>hi then return hi end
  return v
end

local function getDB()
  if NT.BindModuleDB then NT:BindModuleDB() end
  local db = NiniToolsDB and NiniToolsDB.modules and NiniToolsDB.modules.media
  if type(db)~="table" then return nil end
  if db.naviCursorEnabled==nil then db.naviCursorEnabled=true end
  if db.naviCursorRingEnabled==nil then db.naviCursorRingEnabled=true end
  if db.naviCursorGlowEnabled==nil then db.naviCursorGlowEnabled=true end
  if db.naviCursorScale==nil then db.naviCursorScale=100 end
  db.naviCursorScale=math.floor(clamp(db.naviCursorScale,70,140)+0.5)
  return db
end

local function CreateTextureRegion(name, width, height, x, y, textureOrAtlas, color, alpha)
  local region = CreateFrame("Frame", nil, mouseFrame)
  region.name = name
  region.baseWidth = width
  region.baseHeight = height
  region.baseX = x
  region.baseY = y
  region.baseAlpha = alpha or 1

  region:SetSize(width, height)
  region:SetPoint("CENTER", mouseFrame, "CENTER", x, y)

  local tex = region:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(region)

  local isAtlas = false
  if type(textureOrAtlas)=="string" then
    if C_Texture and C_Texture.GetAtlasInfo then
      local ok, info = pcall(C_Texture.GetAtlasInfo, textureOrAtlas)
      isAtlas = ok and info and true or false
    elseif GetAtlasInfo then
      local ok, info = pcall(GetAtlasInfo, textureOrAtlas)
      isAtlas = ok and info and true or false
    end
  end

  if isAtlas and tex.SetAtlas then
    pcall(tex.SetAtlas, tex, textureOrAtlas)
  else
    local ok = pcall(tex.SetTexture, tex, textureOrAtlas, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then pcall(tex.SetTexture, tex, textureOrAtlas) end
  end

  tex:SetBlendMode("ADD")
  tex:SetDesaturated(false)

  local r,g,b,a = unpack(color)
  tex:SetVertexColor(r,g,b,a)

  region.texture = tex
  region:SetAlpha(region.baseAlpha)
  return region
end

local background = CreateTextureRegion(
  "Navi Background 15",
  30, 30,
  56.817220306396, 48.241638183594,
  "Interface\\AddOns\\NiniTools\\Media\\Aura87.tga",
  {1,1,1,1},
  0.6
)

local modelRegion = CreateFrame("Frame", nil, mouseFrame)
modelRegion.baseWidth = 76.449096679688
modelRegion.baseHeight = 79.665534973145
modelRegion.baseX = 54.671766662597
modelRegion.baseY = 40.196268919083
modelRegion.baseAlpha = 0.5
modelRegion:SetSize(modelRegion.baseWidth, modelRegion.baseHeight)
modelRegion:SetPoint("CENTER", mouseFrame, "CENTER", modelRegion.baseX, modelRegion.baseY)
modelRegion:SetAlpha(modelRegion.baseAlpha)

local model = CreateFrame("PlayerModel", nil, modelRegion)
model:SetAllPoints(modelRegion)
if model.SetKeepModelOnHide then pcall(model.SetKeepModelOnHide, model, true) end

local function ConfigureModel()
  pcall(model.SetModel, model, 166890)
  if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0) end
  if model.ClearTransform then pcall(model.ClearTransform, model) end
  if model.SetPosition then pcall(model.SetPosition, model, -5.05, 0, -1.9) end
  if model.SetFacing then pcall(model.SetFacing, model, 0) end
  if model.SetAnimation then pcall(model.SetAnimation, model, 0) end
end
ConfigureModel()

local orb = CreateTextureRegion(
  "Navi Glow Alive 5",
  60, 60,
  53.602864837646, 43.95361328125,
  "Artifacts-Anim-Orb",
  {0.4627451300621,0.54901963472366,1,0.65000000596046},
  1
)

local circle = CreateTextureRegion(
  "Navi Glow Alive 2 2",
  55, 55,
  53.602864837646, 45.025573730469,
  "BonusChest-CircleGlow",
  {0,0.26274511218071,1,1},
  1
)

background:SetFrameLevel(mouseFrame:GetFrameLevel()+1)
modelRegion:SetFrameLevel(mouseFrame:GetFrameLevel()+2)
orb:SetFrameLevel(mouseFrame:GetFrameLevel()+3)
circle:SetFrameLevel(mouseFrame:GetFrameLevel()+4)

local pulseRegions = {background,orb,circle}
local born = GetTime()
local wasShown = false
local lastScale = nil

local function GetScale(db)
  return clamp((db and db.naviCursorScale) or 100,70,140)/100
end

local function ApplyAnchor(region, scale)
  region:ClearAllPoints()
  region:SetPoint("CENTER", mouseFrame, "CENTER", region.baseX*scale, region.baseY*scale)
end

local function ApplyGeometry(db, force)
  local scale=GetScale(db)
  if not force and lastScale==scale then return scale end
  lastScale=scale
  ApplyAnchor(background,scale)
  ApplyAnchor(orb,scale)
  ApplyAnchor(circle,scale)
  modelRegion:ClearAllPoints()
  modelRegion:SetPoint("CENTER",mouseFrame,"CENTER",modelRegion.baseX*scale,modelRegion.baseY*scale)
  return scale
end

local function ApplyPulse(region, factor, scale)
  region:SetSize(region.baseWidth*scale*factor, region.baseHeight*scale*factor)
end

local function ApplyVisibility(show,db)
  local ringOn = db and db.naviCursorRingEnabled~=false
  local glowOn = db and db.naviCursorGlowEnabled~=false
  background:SetShown(show and glowOn)
  modelRegion:SetShown(show)
  orb:SetShown(show and glowOn)
  circle:SetShown(show and ringOn)
end

local function CursorOnUpdate()
  local db=getDB()
  if not db or db.naviCursorEnabled==false then
    driver:SetScript("OnUpdate",nil)
    ApplyVisibility(false,db)
    wasShown=false
    return
  end

  if not wasShown then
    wasShown=true
    ConfigureModel()
    ApplyVisibility(true,db)
    born=GetTime()
  end

  local scale=ApplyGeometry(db,false)
  local x,y=GetCursorPosition()
  local invScale=1/UIParent:GetEffectiveScale()
  mouseFrame:ClearAllPoints()
  mouseFrame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x*invScale,y*invScale)

  local age=GetTime()-born
  if age<0.25 then
    local p=math.max(0,math.min(1,age/0.25))
    local f=math.max(0.001,p)

    background:SetSize(background.baseWidth*scale*f,background.baseHeight*scale*f)
    orb:SetSize(orb.baseWidth*scale*f,orb.baseHeight*scale*f)
    circle:SetSize(circle.baseWidth*scale*f,circle.baseHeight*scale*f)
    modelRegion:SetSize(modelRegion.baseWidth*scale*f,modelRegion.baseHeight*scale*f)

    background:SetAlpha(background.baseAlpha*p)
    orb:SetAlpha(orb.baseAlpha*p)
    circle:SetAlpha(circle.baseAlpha*p)
    modelRegion:SetAlpha(modelRegion.baseAlpha*p)
  else
    background:SetAlpha(background.baseAlpha)
    orb:SetAlpha(orb.baseAlpha)
    circle:SetAlpha(circle.baseAlpha)
    modelRegion:SetAlpha(modelRegion.baseAlpha)
    modelRegion:SetSize(modelRegion.baseWidth*scale,modelRegion.baseHeight*scale)

    local progress=((age-0.25)%0.75)/0.75
    local angle=(progress*2*math.pi)-(math.pi/2)
    local factor=1+(((math.sin(angle)+1)/2)*0.05)
    for _,region in ipairs(pulseRegions) do ApplyPulse(region,factor,scale) end
  end
end

local function SetDriverActive(active)
  if active then
    driver:SetScript("OnUpdate",CursorOnUpdate)
  else
    driver:SetScript("OnUpdate",nil)
  end
end

function NT:IsNaviCursorEnabled()
  local db=getDB()
  return db and db.naviCursorEnabled~=false or false
end

function NT:SetNaviCursorEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorEnabled=enabled and true or false
  if db.naviCursorEnabled then
    born=GetTime()
    ConfigureModel()
    ApplyGeometry(db,true)
    ApplyVisibility(true,db)
    wasShown=true
    SetDriverActive(true)
  else
    SetDriverActive(false)
    ApplyVisibility(false,db)
    wasShown=false
  end
  return true
end

function NT:IsNaviCursorRingEnabled()
  local db=getDB()
  return db and db.naviCursorRingEnabled~=false or false
end

function NT:SetNaviCursorRingEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorRingEnabled=enabled and true or false
  ApplyVisibility(db.naviCursorEnabled~=false,db)
  return true
end

function NT:IsNaviCursorGlowEnabled()
  local db=getDB()
  return db and db.naviCursorGlowEnabled~=false or false
end

function NT:SetNaviCursorGlowEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorGlowEnabled=enabled and true or false
  ApplyVisibility(db.naviCursorEnabled~=false,db)
  return true
end

function NT:GetNaviCursorScale()
  local db=getDB()
  return db and (tonumber(db.naviCursorScale) or 100) or 100
end

function NT:SetNaviCursorScale(value)
  local db=getDB()
  if not db then return false end
  db.naviCursorScale=math.floor(clamp(value,70,140)+0.5)
  ApplyGeometry(db,true)
  born=GetTime()
  return true
end

function NT:ResetNaviCursor()
  local db=getDB()
  born=GetTime()
  ConfigureModel()
  ApplyGeometry(db,true)
  ApplyVisibility(db and db.naviCursorEnabled~=false,db)
  return true
end

local events=_G.NiniTools.EventDispatcher:CreateProxy("Media.NaviCursor")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function()
  local db=getDB()
  if db and db.naviCursorEnabled~=false then
    ConfigureModel()
    ApplyGeometry(db,true)
    ApplyVisibility(true,db)
    born=GetTime()
    wasShown=true
    SetDriverActive(true)
  else
    wasShown=false
    SetDriverActive(false)
    ApplyVisibility(false,db)
  end
end)

SLASH_NINITOOLSNAVI1="/nnavi"
SlashCmdList.NINITOOLSNAVI=function(msg)
  msg=(msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if msg=="on" then
    NT:SetNaviCursorEnabled(true)
  elseif msg=="off" then
    NT:SetNaviCursorEnabled(false)
  elseif msg=="reset" then
    NT:ResetNaviCursor()
  else
    NT:Print("/nnavi on | off | reset")
    return
  end
  NT:Print("마우스 Navi "..(NT:IsNaviCursorEnabled() and "ON" or "OFF"))
end
