local ADDON_NAME = ...
local RDE = _G.NiniKick or {}
_G.NiniKick = RDE

-- NiniKick · Important Cast visibility
--
-- Midnight-safe 원칙
--   * C_Spell.IsSpellImportant / notInterruptible 값은 secret일 수 있다.
--   * Lua if/비교로 읽지 않고 EvaluateColorValueFromBoolean -> indicator:SetAlpha로만 전달한다.
--   * 느낌표/점멸은 indicator의 자식이라 secret alpha를 그대로 상속한다.
--   * "내 차단/백업"은 NiniKick이 직접 계산한 non-secret 상태만 별도 자식 레이어에서 처리한다.

local indicators = {}
local frame = _G.NiniTools.EventDispatcher:CreateProxy("Kick.ImportantCast")
local castEventsRegistered = false
local animationDriver = CreateFrame("Frame")
local activeVisuals = {}
local activeVisualCount = 0
local CAST_EVENTS = {
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP",
}

local ALERT_TEXTURE = "Interface\\AddOns\\NiniTools\\Media\\ImportantAlert.tga"
local NT = _G.NiniTools or {}

local function framePreset()
  return NT.IMPORTANT_CAST_STYLES and NT.IMPORTANT_CAST_STYLES.DEFAULT or {}
end

local function noSnap(tex)
  -- 2.5.5: 크기가 부드럽게 변하도록 픽셀 맞춤을 끈다 (없는 클라이언트는 그냥 넘어감)
  if tex.SetSnapToPixelGrid then pcall(tex.SetSnapToPixelGrid,tex,false) end
  if tex.SetTexelSnappingBias then pcall(tex.SetTexelSnappingBias,tex,0) end
end

local function isSecret(v)
  return type(issecretvalue)=="function" and issecretvalue(v)
end

local function db()
  return type(RogueDefensivesDB)=="table" and RogueDefensivesDB or nil
end

local function enabled()
  local d=db()
  if not d or d.enabled==false or d.importantCastMarkerEnabled==false then return false end
  return type(RDE.IsActiveMythicPlus)=="function" and RDE.IsActiveMythicPlus() or false
end

local function stylePreset()
  local d=db() or {}
  local preset
  if type(NT.GetImportantCastStyle)=="function" then
    preset=NT:GetImportantCastStyle(d.importantCastMarkerStyle)
  end
  preset=preset or framePreset()
  return preset, math.max(.70,math.min(1.40,tonumber(d.importantCastMarkerScale) or 1))
end

local function markerPositionOffset()
  local d=db() or {}
  local key=d.importantCastMarkerPosition or "HEAD"
  if key=="NAME" then return -16 end
  if key=="BAR" then return -28 end
  return -4
end

local function deactivateVisual(ind)
  if not ind or not ind.visual then return end
  if ind.visualActive then
    ind.visualActive=false
    if activeVisuals[ind] then
      activeVisuals[ind]=nil
      activeVisualCount=math.max(0,activeVisualCount-1)
    end
  end
  ind.visual:Hide()
  if activeVisualCount==0 then animationDriver:SetScript("OnUpdate",nil) end
end

local function visualTick(ind,now)
  local visual=ind.visual
  if not visual then return end
  local preset=ind.stylePreset or framePreset()
  local fading=(ind.effectMode=="finish") and (now-(ind.finishAt or now)) or nil
  local f=NT.ImportantCastFrame and NT:ImportantCastFrame(preset,now,now-(ind.effectStartedAt or (now-1)),fading)
  if not f then return end
  local iconBase=ind.iconBase or 68
  local glowBase=ind.glowBase or 96
  ind.tex:SetSize(iconBase*f.iconScale,iconBase*f.iconScale)
  ind.tex:SetVertexColor(f.r,f.g,f.b,1)
  ind.tex:SetAlpha(f.iconAlpha)
  if ind.glow then
    if f.glowAlpha>0.01 then
      ind.glow:SetSize(glowBase*f.glowScale,glowBase*f.glowScale)
      ind.glow:SetVertexColor(f.r,f.g,f.b,1)
      ind.glow:SetAlpha(f.glowAlpha)
      ind.glow:Show()
    else
      ind.glow:Hide()
    end
  end
  if ind.mine and ind.mine:IsShown() then
    -- 내 담당 강조는 같은 크기로 겹쳐서 아이콘 자체를 밝게 한다 (두 번째 느낌표처럼 안 보이게)
    ind.mine:SetSize(iconBase*f.iconScale,iconBase*f.iconScale)
  end
  if ind.ring then
    if f.ringScale and f.ringAlpha>0.01 then
      ind.ring:SetSize(iconBase*f.ringScale,iconBase*f.ringScale)
      ind.ring:SetVertexColor(f.r,f.g,f.b,1)
      ind.ring:SetAlpha(f.ringAlpha)
      ind.ring:Show()
    else
      ind.ring:Hide()
    end
  end
  visual:SetAlpha(f.alpha)
  if f.done then
    ind:SetAlpha(0)
    ind.effectMode="main"
    visual:SetAlpha(1)
    ind.deactivateNow=true
  end
end

local function animationOnUpdate()
  if activeVisualCount<=0 then
    animationDriver:SetScript("OnUpdate",nil)
    return
  end
  local now=GetTime()
  local finished
  for ind in pairs(activeVisuals) do
    visualTick(ind,now)
    if ind.deactivateNow then
      finished=finished or {}
      finished[#finished+1]=ind
    end
  end
  if finished then
    for _,ind in ipairs(finished) do
      ind.deactivateNow=nil
      deactivateVisual(ind)
    end
  end
end

local function activateVisual(ind)
  if not ind or not ind.visual then return end
  if not ind.visualActive then
    ind.visualActive=true
    activeVisuals[ind]=true
    activeVisualCount=activeVisualCount+1
  end
  ind.visual:Show()
  if activeVisualCount>0 and not animationDriver:GetScript("OnUpdate") then
    animationDriver:SetScript("OnUpdate",animationOnUpdate)
  end
end

local function applyVisualStyle(ind)
  if not ind or not ind.visual then return end
  local preset,scale=stylePreset()
  ind.stylePreset=preset
  ind.markerScale=scale
  local iconSize=(tonumber(preset.iconSize) or 68)*scale
  local glowSize=(tonumber(preset.glowSize) or iconSize/scale)*scale
  ind.iconBase=iconSize
  ind.glowBase=glowSize
  -- 바깥 틀은 크기 고정 · 그림은 가운데 기준으로만 커지고 작아진다 (위치가 흔들리지 않음)
  ind.visual:SetSize(iconSize,iconSize)
  ind.visual:SetScale(1)
  ind.visual:ClearAllPoints()
  ind.visual:SetPoint("BOTTOM",ind,"TOP",0,markerPositionOffset())
  for _,tex in ipairs({ind.tex,ind.glow,ind.ring}) do
    if tex then
      tex:ClearAllPoints()
      tex:SetPoint("CENTER",ind.visual,"CENTER",0,0)
    end
  end
  if ind.tex then ind.tex:SetSize(iconSize,iconSize) end
  if ind.glow then ind.glow:SetSize(glowSize,glowSize) end
  if ind.ring then ind.ring:SetSize(iconSize,iconSize); ind.ring:Hide() end
  if ind.mine then ind.mine:SetSize(iconSize,iconSize) end
end

local function hostileUnit(unit)
  if type(UnitCanAttack)~="function" then return false end
  local ok,value=pcall(UnitCanAttack,"player",unit)
  if not ok or isSecret(value) then return false end
  return value==true
end

local function makePulse(region,lowAlpha,highAlpha,duration)
  region:SetAlpha(lowAlpha)
  local pulse=region:CreateAnimationGroup()
  local up=pulse:CreateAnimation("Alpha")
  up:SetFromAlpha(lowAlpha)
  up:SetToAlpha(highAlpha)
  up:SetDuration(duration)
  up:SetSmoothing("IN_OUT")
  up:SetOrder(1)
  local down=pulse:CreateAnimation("Alpha")
  down:SetFromAlpha(highAlpha)
  down:SetToAlpha(lowAlpha)
  down:SetDuration(duration)
  down:SetSmoothing("IN_OUT")
  down:SetOrder(2)
  pulse:SetLooping("REPEAT")
  pulse:Play()
  return pulse
end

local function getIndicator(nameplate)
  local ind=indicators[nameplate]
  if ind then return ind end

  -- 기존 V가 있던 위치를 그대로 사용한다. 중요 여부는 이 부모 alpha만 secret-safe로 바뀐다.
  ind=CreateFrame("Frame",nil,nameplate)
  ind:SetFrameStrata("TOOLTIP")
  ind:SetFrameLevel(math.max((nameplate.GetFrameLevel and nameplate:GetFrameLevel() or 0)+20,100))
  ind:SetSize(118,52)
  ind:SetPoint("CENTER",nameplate,"CENTER",0,0)
  ind:SetAlpha(0)

  -- RC9: dark-red/fast-scale pulse -> bright scarlet/orange breathing glow.
  -- Default style stays steady; the optional pulse preset can add a small scale pulse.
  local visual=CreateFrame("Frame",nil,ind)
  visual:SetSize(68,68)
  visual:SetPoint("BOTTOM",ind,"TOP",0,-4)
  visual:SetAlpha(1)
  visual:SetScale(1)
  visual:Hide()

  -- 퍼지는 파동 고리 (강조형만 보임): 아이콘 복사본이 커지며 사라진다.
  local ring=visual:CreateTexture(nil,"BACKGROUND")
  ring:SetTexture(ALERT_TEXTURE)
  ring:SetPoint("CENTER",visual,"CENTER",0,0)
  ring:SetSize(68,68)
  ring:SetBlendMode("ADD")
  ring:Hide()
  noSnap(ring)

  -- Slightly enlarged additive copy behind the icon: visible glowing edge/halo.
  local glow=visual:CreateTexture(nil,"ARTWORK")
  glow:SetTexture(ALERT_TEXTURE)
  glow:SetPoint("CENTER",visual,"CENTER",0,0)
  glow:SetSize(96,96)
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1,0.12,0.04,1)
  glow:SetAlpha(0.30)
  noSnap(glow)

  local tex=visual:CreateTexture(nil,"OVERLAY")
  tex:SetTexture(ALERT_TEXTURE)
  tex:SetPoint("CENTER",visual,"CENTER",0,0)
  tex:SetSize(68,68)
  tex:SetBlendMode("BLEND")
  tex:SetVertexColor(1,0.12,0.04,1)
  noSnap(tex)

  ind.visual=visual
  ind.tex=tex
  ind.glow=glow
  ind.ring=ring
  ind.effectMode="main"
  ind.effectStartedAt=GetTime()
  ind.effectToken=0
  ind.visualActive=false

  -- 내 담당/백업 레이어는 기존 기능을 유지한다.
  -- 메인 느낌표의 밝은 주홍↔주황 + 외곽광 위에 담당 여부만 추가 강조한다.
  local mine=CreateFrame("Frame",nil,ind)
  mine:SetSize(74,74)
  mine:SetPoint("CENTER",visual,"CENTER",0,0)
  mine:Hide()

  local mineTex=mine:CreateTexture(nil,"OVERLAY")
  mineTex:SetTexture(ALERT_TEXTURE)
  mineTex:SetAllPoints()
  mineTex:SetBlendMode("ADD")
  mineTex:SetVertexColor(1,.88,.12,1)
  mine.tex=mineTex
  mine.pulse=makePulse(mineTex,.25,.95,.40)  -- 2.5.5: 내 담당 강조도 부드럽게 (예전 0.18초 깜빡임)

  ind.mine=mine
  applyVisualStyle(ind)
  indicators[nameplate]=ind
  return ind
end

local function startImportantEffect(ind)
  if not ind or not ind.visual then return end
  ind.effectToken=(ind.effectToken or 0)+1
  ind.effectMode="start"
  ind.effectStartedAt=GetTime()
  ind.finishAt=nil
  ind.deactivateNow=nil
  ind.visual:SetScale(1)
  ind.visual:SetAlpha(0)
  activateVisual(ind)
  visualTick(ind,GetTime())
end

local function finishImportantEffect(ind)
  if not ind or not ind.visual then return end
  ind.effectToken=(ind.effectToken or 0)+1
  local token=ind.effectToken
  if ind.mine then ind.mine:Hide() end
  if not ind.visualActive then
    ind:SetAlpha(0)
    return
  end

  -- 2.5.5: 0.18초 동안 부드럽게 사라진 뒤 애니메이션 목록에서 빠진다 (visualTick이 처리)
  if ind.effectMode~="finish" then
    ind.effectMode="finish"
    ind.finishAt=GetTime()
  end
  local _=token
end

local function updateAssignmentOverlay(unit,ind)
  if not ind or not ind.mine then return end
  local fn=RDE.GetInterruptVisualState
  if type(fn)~="function" then ind.mine:Hide(); return end

  local ok,active,assigned,backup=pcall(fn,unit)
  if not ok or active~=true or (assigned~=true and backup~=true) then
    ind.mine:Hide()
    return
  end

  if backup==true then
    ind.mine.tex:SetVertexColor(1,.16,.72,1)
  else
    ind.mine.tex:SetVertexColor(1,.88,.12,1)
  end
  ind.mine:Show()
end

local function hideForUnit(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
  local ok,plate=pcall(C_NamePlate.GetNamePlateForUnit,unit)
  if ok and plate and indicators[plate] then
    local ind=indicators[plate]
    ind.effectToken=(ind.effectToken or 0)+1
    ind:SetAlpha(0)
    if ind.mine then ind.mine:Hide() end
    ind.effectMode="main"
    ind.visual:SetAlpha(1)
    ind.visual:SetScale(1)
    deactivateVisual(ind)
  end
end

local function finishForUnit(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
  local ok,plate=pcall(C_NamePlate.GetNamePlateForUnit,unit)
  if ok and plate and indicators[plate] then
    finishImportantEffect(indicators[plate])
  end
end

local function applySourceAlpha(unit,indicator,channel)
  if not (C_Spell and type(C_Spell.IsSpellImportant)=="function") then return false end
  if not (C_CurveUtil and type(C_CurveUtil.EvaluateColorValueFromBoolean)=="function") then return false end

  local values
  local notInterruptible,spellID
  if channel then
    if type(UnitChannelInfo)~="function" then return false end
    values={pcall(UnitChannelInfo,unit)}
    if values[1]~=true then return false end
    -- pcall success is [1]; UnitChannelInfo notInterruptible=[7], spellID=[8]
    notInterruptible=values[8]
    spellID=values[9]
  else
    if type(UnitCastingInfo)~="function" then return false end
    values={pcall(UnitCastingInfo,unit)}
    if values[1]~=true then return false end
    -- pcall success is [1]; UnitCastingInfo notInterruptible=[8], spellID=[9]
    notInterruptible=values[9]
    spellID=values[10]
  end

  -- spellID / isImportant / notInterruptible는 secret일 수 있다.
  -- 검사/비교하지 않고 secret-safe API 체인으로만 SetAlpha까지 전달한다.
  local okImp,isImportant=pcall(C_Spell.IsSpellImportant,spellID)
  if not okImp then return false end
  local okA,importantAlpha=pcall(C_CurveUtil.EvaluateColorValueFromBoolean,isImportant,1,0)
  if not okA then return false end
  local okF,finalAlpha=pcall(C_CurveUtil.EvaluateColorValueFromBoolean,notInterruptible,0,importantAlpha)
  if not okF then return false end
  return pcall(indicator.SetAlpha,indicator,finalAlpha) and true or false
end

local function updateDisplay(unit,preferChannel,restartEffect)
  if type(unit)~="string" or not unit:match("^nameplate%d+$") then return end
  if not enabled() or not UnitAffectingCombat("player") or not hostileUnit(unit) then
    hideForUnit(unit)
    return
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
  local ok,plate=pcall(C_NamePlate.GetNamePlateForUnit,unit)
  if not ok or not plate then return end
  local ind=getIndicator(plate)
  ind:SetAlpha(0)

  -- START 자체는 공개 이벤트다. 중요 여부는 계속 secret-safe alpha 체인만 결정한다.
  -- 따라서 START 때만 애니메이션 드라이버에 올리고, 실제 표시 여부는 부모 alpha에 맡긴다.
  if restartEffect==true then startImportantEffect(ind) end
  updateAssignmentOverlay(unit,ind)

  local handled=false
  -- START 이벤트 종류를 알면 해당 API를 먼저 사용한다. NAME_PLATE_UNIT_ADDED처럼
  -- 종류를 모를 때는 cast -> channel 순으로 시도한다. 성공 여부는 pcall 결과뿐이라 secret 분기가 아니다.
  if preferChannel==true then
    handled=applySourceAlpha(unit,ind,true)
    if not handled then handled=applySourceAlpha(unit,ind,false) end
  else
    handled=applySourceAlpha(unit,ind,false)
    if not handled then handled=applySourceAlpha(unit,ind,true) end
  end

  if handled then
    if restartEffect~=true and not ind.visualActive then
      ind.effectMode="main"
      ind.effectStartedAt=GetTime()-1   -- 시전 도중 보인 이름표는 튀어나오는 연출 없이
      ind.finishAt=nil
      ind.visual:SetAlpha(1)
      ind.visual:SetScale(1)
      activateVisual(ind)
    end
  elseif restartEffect~=true then
    -- START 직후 API 갱신 지연은 다음 프레임 재시도가 처리한다.
    -- 그 뒤에도 cast source가 없으면 CPU를 쓰지 않도록 즉시 드라이버에서 내린다.
    if ind.mine then ind.mine:Hide() end
    ind:SetAlpha(0)
    deactivateVisual(ind)
  end
end

local function hideAll()
  for _,ind in pairs(indicators) do
    if ind then
      ind.effectToken=(ind.effectToken or 0)+1
      ind:SetAlpha(0)
      if ind.mine then ind.mine:Hide() end
      ind.effectMode="main"
      if ind.visual then
        ind.visual:SetAlpha(1)
        ind.visual:SetScale(1)
      end
      deactivateVisual(ind)
    end
  end
end

local function refreshAll()
  if not enabled() then hideAll(); return end
  for i=1,40 do
    local unit="nameplate"..i
    local ok,exists=pcall(UnitExists,unit)
    if ok and exists==true then updateDisplay(unit,nil) end
  end
end

local function setCastEvents(flag)
  flag=flag and true or false
  if flag==castEventsRegistered then return end
  castEventsRegistered=flag
  for _,event in ipairs(CAST_EVENTS) do
    if flag then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
  end
  if not flag then hideAll() end
end

local function syncListening()
  setCastEvents(enabled())
  if castEventsRegistered then refreshAll() end
end

RDE.ImportantCastRefreshAll=syncListening
RDE.RefreshImportantCastStyle=function()
  for _,ind in pairs(indicators) do applyVisualStyle(ind) end
end

-- 필요한 상황에서만 고빈도 시전 이벤트를 듣는다.
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:SetScript("OnEvent",function(_,event,unit)
  if event=="PLAYER_LOGIN" then
    local d=db()
    if d and d.importantCastMarkerEnabled==nil then d.importantCastMarkerEnabled=true end
    C_Timer.After(.2,syncListening)
    return
  elseif event=="PLAYER_ENTERING_WORLD" then
    hideAll()
    C_Timer.After(.5,syncListening)
    return
  elseif event=="CHALLENGE_MODE_START" then
    C_Timer.After(.05,syncListening)
    return
  elseif event=="CHALLENGE_MODE_COMPLETED" then
    setCastEvents(false)
    return
  elseif event=="PLAYER_REGEN_ENABLED" then
    hideAll()
    return
  elseif event=="PLAYER_REGEN_DISABLED" then
    if castEventsRegistered then C_Timer.After(.05,refreshAll) end
    return
  elseif event=="NAME_PLATE_UNIT_REMOVED" then
    hideForUnit(unit)
    return
  elseif event=="UNIT_SPELLCAST_CHANNEL_START" then
    updateDisplay(unit,true,true)
    C_Timer.After(0,function() updateDisplay(unit,true,false) end)
    return
  elseif event=="UNIT_SPELLCAST_START" then
    updateDisplay(unit,false,true)
    -- Kick Core의 focus 상태가 같은 이벤트에서 먼저/나중에 갱신될 수 있으므로 다음 프레임에 한 번 더 담당 레이어만 맞춘다.
    C_Timer.After(0,function() updateDisplay(unit,false,false) end)
    return
  elseif event=="UNIT_SPELLCAST_STOP" or event=="UNIT_SPELLCAST_INTERRUPTED" or event=="UNIT_SPELLCAST_CHANNEL_STOP" then
    finishForUnit(unit)
    return
  elseif event=="NAME_PLATE_UNIT_ADDED" then
    updateDisplay(unit,nil)
  end
end)
