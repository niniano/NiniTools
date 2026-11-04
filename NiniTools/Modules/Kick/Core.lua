local ADDON_NAME = ...
local RDE = _G.NiniKick or {}
_G.NiniKick = RDE
local VERSION = _G.NiniTools.VERSION

local defaults = {
  enabled=true, targetFilter=true, showTentative=true, showAlternates=true,
  x=0, y=155, scale=1, duration=2.2, unlocked=false, debug=false,
  voiceMode="MEDIA", ttsText="차단", ttsVoiceID=0, soundKey="NiniTools: Naowh Kick",
  interruptEnabled=true, rotationEnabled=true, interruptMarker=1, interruptOrder=2, interruptSize=2, smartDefensiveEnabled=true, smartDefensiveVolume=70,
  autoBriefing=true, briefingAssignmentActive=false, briefingOverrideEnabled=false, briefingOverrideMarker=0,
  briefingUnmarkedSoloEnabled=false, briefingAutoActive=false, briefingSavedState=nil,
  briefingParticipants={}, briefingLastText="", briefingLastSender="", briefingSessionInstanceID=0, briefingStateVersion=2,
  minimapAngle=225, minimapHide=false, settingsX=0, settingsY=0,
  combatTimerEnabled=true, combatTimerX=0, combatTimerY=105, combatTimerUnlocked=false, combatTimerEndHold=2.5, combatTimerTextSize=24, goodbyeEnabled=true, partyGreetingEnabled=true,
  ttsOverlap=false, soundChannel="Master",
  focusMacroEnabled=true, focusMacroName="NiniKickFocus", freeFocusSolo=false,
  autoInterruptMacroEnabled=true, autoInterruptMacroName="NiniKickAuto",
  defensiveEnabled=false, keepDefensiveWithNaowh=false, displayStyle="ICON", simpleShowMechanic=true, importantCastMarkerEnabled=true,
  importantCastMarkerStyle="PREMIUM", importantCastMarkerScale=1.0, importantCastMarkerPosition="HEAD",
  -- 2.0.23: 아이콘/텍스트 각각 끌 수 있다. 기존 사용자는 둘 다 켜진 상태로 시작한다.
  alertIconEnabled=true, alertTextEnabled=true,
  iconSize=40, timerTextSize=18, alertTextSize=18, textGap=8,
}
local db, isRogue, alert
-- 2.0.12: 단순 상태 플래그를 한 테이블로 묶어 top-level local 한도(200) 여유 확보
local MS={
  focusMacroUpdatePending=false,
  focusMacroFailureShown=false,
  macroEnsureScheduled=false,
  activeFocusMacroName="NiniKickFocus",
  lastKnownFocusMarker=nil,
  moveAnchorActive=false,
  ttsErrorShown=false,
  adaptivePack=false,
}
local minimapButton
local combatTimer
local combatTimerState={active=false,startTime=0,lastSecond=-1,serial=0}
local interruptState = {
  currentOrder=1,
  active=false,
  counted=false,
  evaluated=false,
  interruptible=nil,
  serial=0,
  lastStart=0,
  activeRule=nil,
  expectedOrder=nil,
  myOrder=nil,
  alertPlayed=false,
  backup=false,
  pendingInterrupt=false,
  pendingStop=false,
  castWindow=nil,
  castBarID=nil,
  lastDebugDecision=nil,
}
local MARKER_NAMES={"별","동그라미","다이아","세모","달","네모","가위표","해골"}
local FOCUS_MACRO_NAME="NiniKickFocus"
local LEGACY_FOCUS_MACRO_NAME="RogueDefFocus"
local ensureFocusMarkerMacro
local function getLSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end
RDE.BUILTIN_KICK_SOUND_KEY="NiniTools: Naowh Kick"
RDE.BUILTIN_KICK_SOUND_PATH="Interface\\AddOns\\NiniTools\\Media\\Sounds\\Kick.ogg"

-- Standalone UI theme: follow EllesmereUI when present; otherwise use NaowhUI cyan.
local function themeAccent()
  local EUI=_G.EllesmereUI
  if EUI and type(EUI.GetAccentColor)=="function" then
    local ok,r,g,b=pcall(EUI.GetAccentColor)
    if ok and tonumber(r) and tonumber(g) and tonumber(b) then return r,g,b end
  end
  return 0,207/255,1 -- NaowhUI #00CFFF fallback
end
local function themeFontPath(kind)
  -- 2.5.4: shared NiniTools resolver (NaowhKR body / GothamNarrowUltraKR numbers)
  local NTA=_G.NiniTools
  if NTA and type(NTA.ResolveFont)=="function" then
    local ok,p=pcall(NTA.ResolveFont,NTA,kind)
    if ok and type(p)=="string" and p~="" then return p end
  end
  local EUI=_G.EllesmereUI
  if EUI and type(EUI.GetFontPath)=="function" then
    local ok,p=pcall(EUI.GetFontPath)
    if ok and type(p)=="string" and p~="" then return p end
  end
  local LSM=getLSM()
  if LSM then
    local p=LSM:Fetch("font","Naowh",true)
    if type(p)=="string" and p~="" then return p end
  end
  local p=select(1,GameFontNormal:GetFont())
  return p or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
local function styleEdges(frame,r,g,b,a)
  if not frame then return end
  r,g,b,a=r or 0,g or 0,b or 0,a or 1
  if not frame.__nkEdges then
    local e={}
    e.t=frame:CreateTexture(nil,"BORDER"); e.t:SetPoint("TOPLEFT"); e.t:SetPoint("TOPRIGHT"); e.t:SetHeight(1)
    e.b=frame:CreateTexture(nil,"BORDER"); e.b:SetPoint("BOTTOMLEFT"); e.b:SetPoint("BOTTOMRIGHT"); e.b:SetHeight(1)
    e.l=frame:CreateTexture(nil,"BORDER"); e.l:SetPoint("TOPLEFT"); e.l:SetPoint("BOTTOMLEFT"); e.l:SetWidth(1)
    e.r=frame:CreateTexture(nil,"BORDER"); e.r:SetPoint("TOPRIGHT"); e.r:SetPoint("BOTTOMRIGHT"); e.r:SetWidth(1)
    frame.__nkEdges=e
  end
  for _,t in pairs(frame.__nkEdges) do t:SetColorTexture(r,g,b,a) end
end

local function P(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff00cfff니니차단|r "..tostring(msg)) end
local function copyDefaultValue(value)
  if type(value)~="table" then return value end
  local copy={}
  for k,v in pairs(value) do copy[k]=copyDefaultValue(v) end
  return copy
end
local function merge(d,s)
  d=type(d)=="table" and d or {}
  for k,v in pairs(s) do
    if d[k]==nil then d[k]=copyDefaultValue(v) end
  end
  return d
end
local function safeNum(v) if type(issecretvalue)=="function" and issecretvalue(v) then return nil end; local ok,n=pcall(tonumber,v); return ok and n or nil end
local function safeBool(v)
  if type(issecretvalue)=="function" and issecretvalue(v) then return nil end
  return type(v)=="boolean" and v or nil
end
local function safeText(v)
  if type(issecretvalue)=="function" and issecretvalue(v) then return nil end
  local ok,s=pcall(tostring,v)
  return ok and s or nil
end
local function clamp(v,lo,hi) v=tonumber(v) or lo; if v<lo then return lo elseif v>hi then return hi end; return v end
local function now() return GetTime and GetTime() or 0 end
local function activeMythicPlus()
  -- NiniKick interrupt alerts are intentionally Mythic+ only.
  -- A normal/heroic/mythic dungeon or raid must never trigger the focus interrupt voice.
  if not (C_ChallengeMode and type(C_ChallengeMode.GetActiveChallengeMapID)=="function") then return false end
  local ok,mapID=pcall(C_ChallengeMode.GetActiveChallengeMapID)
  mapID=ok and safeNum(mapID) or nil
  return mapID~=nil and mapID>0
end
RDE.IsActiveMythicPlus=activeMythicPlus

local function hideMacroCharLimitText()
  -- 매크로 UI가 로드된 뒤 글자수/길이 표시를 자동으로 숨긴다.
  -- 사용자가 쓰던 /run 한 줄과 같은 동작을 애드온에서 자동 적용한다.
  local f=_G.MacroFrameCharLimitText
  if not f then return false end

  if type(f.Hide)=="function" then
    pcall(f.Hide,f)
  end

  if not f.__NiniKickCharLimitHooked and type(hooksecurefunc)=="function" then
    local ok=pcall(hooksecurefunc,f,"Show",function(self)
      if self and type(self.Hide)=="function" then
        self:Hide()
      end
    end)
    if ok then
      f.__NiniKickCharLimitHooked=true
    end
  end
  return true
end

local function focusMarkerMacroBody(marker)
  marker=math.max(1,math.min(8,tonumber(marker) or 1))
  local focusLine="#showtooltip\n/focus [@mouseover,harm,nodead][harm,nodead]"
  -- 무징표 전담 브리핑이 활성화된 동안에는 대상에게 징표를 찍으면
  -- resolveInterruptRuleForFocus()의 unmarked 규칙이 즉시 깨진다.
  -- 이 경우 NiniKickFocus는 안전하게 주시만 잡고, 기존 파티 징표는 그대로 사용한다.
  if db and db.briefingUnmarkedSoloEnabled then
    return focusLine
  end
  -- Midnight 12.0.7의 /tm ~N은 대상이 무징표일 때만 징표를 설정한다.
  -- 기존 파티 징표를 덮어쓰거나 같은 대상에서 징표를 토글해 지우지 않는다.
  -- /focus 직후 @focus를 다시 참조하지 않고, 같은 입력 유닛에 직접 징표를 준다.
  -- 이렇게 해야 새 주시 반영 시점과 무관하게 마우스오버/현재 대상에 확실히 적용된다.
  return string.format("%s\n/tm [@mouseover,harm,nodead][harm,nodead] ~%d",focusLine,marker)
end

local function currentInterruptMacroIcon()
  local classFile
  if UnitClass then
    local ok,_,cf=pcall(UnitClass,"player")
    classFile=ok and safeText(cf) or nil
  end
  local spellByClass={
    ROGUE=1766,WARRIOR=6552,DEATHKNIGHT=47528,DEMONHUNTER=183752,SHAMAN=57994,
    MAGE=2139,WARLOCK=19647,PALADIN=96231,MONK=116705,EVOKER=351338,HUNTER=147362,
  }
  local spellID=spellByClass[classFile] or 1766
  if C_Spell and C_Spell.GetSpellInfo then
    local ok,info=pcall(C_Spell.GetSpellInfo,spellID)
    if ok and info and info.iconID then return info.iconID end
  end
  return 132219 -- Rogue Kick fallback
end

local function macroCounts()
  local accountCount,charCount=0,0
  if type(GetNumMacros)=="function" then
    local ok,a,c=pcall(GetNumMacros)
    if ok then accountCount=safeNum(a) or 0; charCount=safeNum(c) or 0 end
  end
  return accountCount,charCount
end

local function accountMacroRange()
  local accountCount=macroCounts()
  local accountMax=safeNum(_G.MAX_ACCOUNT_MACROS) or 120
  return 1,math.min(accountMax,accountCount),accountMax
end

local function characterMacroRange()
  local _,charCount=macroCounts()
  local accountMax=safeNum(_G.MAX_ACCOUNT_MACROS) or 120
  local charMax=safeNum(_G.MAX_CHARACTER_MACROS) or 18
  return accountMax+1,accountMax+math.min(charMax,charCount),charMax
end

local function findMacroInRange(name,first,last)
  if type(GetMacroInfo)~="function" or not name or name=="" then return 0 end
  if not first or not last or last<first then return 0 end
  for i=first,last do
    local ok,macroName=pcall(GetMacroInfo,i)
    macroName=ok and safeText(macroName) or nil
    if macroName==name then return i end
  end
  return 0
end

local function findCharacterMacroByName(name)
  local first,last=characterMacroRange()
  return findMacroInRange(name,first,last)
end

local function findAccountMacroByName(name)
  local first,last=accountMacroRange()
  return findMacroInRange(name,first,last)
end


local function scheduleFocusMacroEnsure(delay)
  if MS.macroEnsureScheduled then return end
  MS.macroEnsureScheduled=true
  local function run()
    MS.macroEnsureScheduled=false
    if db and db.focusMacroEnabled~=false then ensureFocusMarkerMacro(true) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay or .6,run) else run() end
end

ensureFocusMarkerMacro=function(silent)
  if not db or db.focusMacroEnabled==false then return false,"disabled" end
  if InCombatLockdown and InCombatLockdown() then
    MS.focusMacroUpdatePending=true
    return false,"combat"
  end
  if type(CreateMacro)~="function" or type(EditMacro)~="function" or type(GetMacroInfo)~="function" then
    return false,"api"
  end

  local configuredName=safeText(db.focusMacroName) or FOCUS_MACRO_NAME
  if configuredName=="" then configuredName=FOCUS_MACRO_NAME end

  local body=focusMarkerMacroBody(db.interruptMarker)
  local icon=currentInterruptMacroIcon()
  local index=0
  local name=configuredName

  -- 0.6.12: 주시+징표 매크로는 항상 현재 캐릭터 전용으로만 관리한다.
  -- 계정 공용 영역의 같은 이름 매크로는 절대 자동 수정/재사용하지 않는다.
  index=findCharacterMacroByName(configuredName)
  if index<=0 and configuredName~=LEGACY_FOCUS_MACRO_NAME then
    local legacyIndex=findCharacterMacroByName(LEGACY_FOCUS_MACRO_NAME)
    if legacyIndex>0 then index=legacyIndex; name=LEGACY_FOCUS_MACRO_NAME end
  end

  local ok,result=true,index
  local lastError=nil

  if index and index>0 then
    local infoOK,oldName,oldIcon,oldBody=pcall(GetMacroInfo,index)
    oldName=infoOK and safeText(oldName) or nil
    oldBody=infoOK and safeText(oldBody) or nil
    local oldIconText=infoOK and safeText(oldIcon) or nil
    local iconText=safeText(icon)
    if oldName~=name or oldBody~=body or oldIconText~=iconText then
      ok,result=pcall(EditMacro,index,name,icon,body)
      if not ok then lastError=safeText(result) or "캐릭터 전용 EditMacro 실패" end
    end
  else
    local _,charCount=macroCounts()
    local charMax=safeNum(_G.MAX_CHARACTER_MACROS) or 18
    if charCount>=charMax then
      ok=false
      lastError=string.format("캐릭터 전용 매크로 칸 가득 참 · %d/%d",charCount,charMax)
    else
      -- perCharacter=true : 캐릭터 전용 매크로 생성
      ok,result=pcall(CreateMacro,name,icon,body,true)
      if ok then
        index=safeNum(result) or 0
        if index<=0 then lastError="CreateMacro가 유효한 개인 매크로 번호를 반환하지 않음" end
      else
        index=0
        lastError=safeText(result) or "캐릭터 전용 CreateMacro 실패"
      end
    end
  end

  if not ok or not index or index<=0 then
    MS.focusMacroUpdatePending=true
    if not silent and not MS.focusMacroFailureShown then
      MS.focusMacroFailureShown=true
      local _,c=macroCounts()
      local cm=safeNum(_G.MAX_CHARACTER_MACROS) or 18
      local shared=findAccountMacroByName(configuredName)
      if shared<=0 and configuredName~=LEGACY_FOCUS_MACRO_NAME then shared=findAccountMacroByName(LEGACY_FOCUS_MACRO_NAME) end
      if shared>0 then
        P(string.format("개인 주시+징표 매크로 생성 실패 · 개인 %d/%d · 0.6.11 공용 매크로가 남아 있으면 /nk focusmacro migrate",c,cm))
      else
        P(string.format("개인 주시+징표 매크로 생성 실패 · 개인 %d/%d · %s",c,cm,lastError or "원인 미확인"))
      end
    end
    return false,lastError or "failed"
  end

  MS.activeFocusMacroName=name
  db.focusMacroName=configuredName
  MS.focusMacroUpdatePending=false
  MS.focusMacroFailureShown=false
  if not silent then
    local macroMode=db.briefingUnmarkedSoloEnabled and "무징표 전담 보호 · 주시만" or "무징표 대상에만 담당 징표+주시"
    P("포커스 갱신 · "..(MARKER_NAMES[db.interruptMarker] or "징표").." · 캐릭터 전용 · "..macroMode)
  end
  return true,"캐릭터 전용"
end

local function isGeneratedFocusMacroBody(body)
  body=safeText(body)
  if not body then return false end
  return body:find("/focus",1,true)~=nil and body:find("/tm",1,true)~=nil
end

local function migrateSharedFocusMacroToCharacter()
  if not db or db.focusMacroEnabled==false then return false,"disabled" end
  if InCombatLockdown and InCombatLockdown() then
    P("전투 중에는 매크로를 옮길 수 없습니다.")
    return false,"combat"
  end
  if type(DeleteMacro)~="function" or type(CreateMacro)~="function" or type(GetMacroInfo)~="function" then
    P("매크로 API를 사용할 수 없습니다.")
    return false,"api"
  end

  -- 이미 개인 매크로가 있으면 공용은 건드리지 않는다.
  local configuredName=safeText(db.focusMacroName) or FOCUS_MACRO_NAME
  if configuredName=="" then configuredName=FOCUS_MACRO_NAME end
  local personal=findCharacterMacroByName(configuredName)
  if personal<=0 and configuredName~=LEGACY_FOCUS_MACRO_NAME then personal=findCharacterMacroByName(LEGACY_FOCUS_MACRO_NAME) end
  if personal>0 then
    ensureFocusMarkerMacro(false)
    return true,"already-personal"
  end

  local shared=findAccountMacroByName(configuredName)
  local sharedName=configuredName
  if shared<=0 and configuredName~=LEGACY_FOCUS_MACRO_NAME then
    shared=findAccountMacroByName(LEGACY_FOCUS_MACRO_NAME)
    if shared>0 then sharedName=LEGACY_FOCUS_MACRO_NAME end
  end
  if shared<=0 then
    return ensureFocusMarkerMacro(false)
  end

  local okInfo,oldName,oldIcon,oldBody=pcall(GetMacroInfo,shared)
  oldName=okInfo and safeText(oldName) or sharedName
  oldBody=okInfo and safeText(oldBody) or nil
  if not okInfo or not isGeneratedFocusMacroBody(oldBody) then
    P("같은 이름의 공용 매크로가 있지만 니니차단 생성 매크로로 확인되지 않아 자동 삭제하지 않았습니다.")
    return false,"foreign-shared"
  end

  -- 0.6.11이 만든 공용 매크로만 제거하고 개인 매크로로 재생성한다.
  local delOK,delErr=pcall(DeleteMacro,shared)
  if not delOK then
    P("공용 매크로 제거 실패 · "..tostring(safeText(delErr) or "원인 미확인"))
    return false,"delete-failed"
  end

  local made,why=ensureFocusMarkerMacro(true)
  if made then
    P("0.6.11 공용 주시+징표 매크로 → 현재 캐릭터 전용으로 이동 완료")
    return true,"migrated"
  end

  -- 개인 생성 실패 시 기존 공용 매크로를 최대한 복구한다.
  local restoreName=oldName or sharedName
  local restoreIcon=oldIcon or currentInterruptMacroIcon()
  local restoreBody=oldBody or focusMarkerMacroBody(db.interruptMarker)
  pcall(CreateMacro,restoreName,restoreIcon,restoreBody,false)
  P("개인 매크로 생성에 실패하여 기존 공용 매크로를 복구했습니다. /nk focusmacro 로 상태를 확인하세요.")
  return false,why or "migrate-failed"
end

RDE.UpdateFocusMarkerMacro=ensureFocusMarkerMacro
RDE.GetFocusMarkerMacroBody=focusMarkerMacroBody


-- 2.0.5: Naowh-style focus-first auto interrupt macro.
-- Existing valid hostile focus is always prioritized.
-- With no valid focus, temporarily stores the current target in focus,
-- lets /targetenemy pick an interruptible caster, interrupts it,
-- then restores the original target and clears the temporary focus.
RDE.GetAutoInterruptMacroBody=function()
  local classFile
  if UnitClass then
    local ok,_,cf=pcall(UnitClass,"player")
    classFile=ok and safeText(cf) or nil
  end

  local spellByClass={
    ROGUE=1766,
    WARRIOR=6552,
    DEATHKNIGHT=47528,
    DEMONHUNTER=183752,
    SHAMAN=57994,
    MAGE=2139,
    WARLOCK=19647,
    PALADIN=96231,
    MONK=116705,
    EVOKER=351338,
    HUNTER=147362,
  }
  local spellID=spellByClass[classFile]
  if not spellID then return nil,nil,"class" end

  local spellName
  if C_Spell and type(C_Spell.GetSpellInfo)=="function" then
    local ok,info=pcall(C_Spell.GetSpellInfo,spellID)
    if ok and type(info)=="table" then spellName=safeText(info.name) end
  end
  -- User's primary class is Rogue; this fallback also keeps the exact requested
  -- Korean macro available if spell data happens to be late during login.
  if not spellName and classFile=="ROGUE" then spellName="발차기" end
  if not spellName or spellName=="" then return nil,spellID,"spell" end

  local body=table.concat({
    "#showtooltip "..spellName,
    "/cast [@focus,exists,nodead,harm] "..spellName,
    "/stopmacro [@focus,exists,nodead,harm]",
    "/focus target",
    "/cleartarget",
    "/targetenemy",
    "/cast "..spellName,
    "/target focus",
    "/clearfocus",
    "/startattack",
  },"\n")

  -- Retail character macros are still size-limited. The generated Korean Rogue
  -- version is ~200 bytes, comfortably below the limit.
  if #body>255 then return nil,spellID,"length" end
  return body,spellID,nil
end

RDE.ScheduleAutoInterruptMacroEnsure=function(delay)
  if RDE._autoInterruptMacroEnsureScheduled then return end
  RDE._autoInterruptMacroEnsureScheduled=true
  local function run()
    RDE._autoInterruptMacroEnsureScheduled=false
    if db and db.autoInterruptMacroEnabled~=false and RDE.UpdateAutoInterruptMacro then
      RDE.UpdateAutoInterruptMacro(true)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay or .6,run) else run() end
end

RDE.UpdateAutoInterruptMacro=function(silent)
  if not db or db.autoInterruptMacroEnabled==false then return false,"disabled" end
  if InCombatLockdown and InCombatLockdown() then
    RDE._autoInterruptMacroUpdatePending=true
    return false,"combat"
  end
  if type(CreateMacro)~="function" or type(EditMacro)~="function" or type(GetMacroInfo)~="function" then
    return false,"api"
  end

  local body,spellID,bodyWhy=RDE.GetAutoInterruptMacroBody()
  if not body then return false,bodyWhy or "body" end

  local name=safeText(db.autoInterruptMacroName) or "NiniKickAuto"
  if name=="" then name="NiniKickAuto" end
  local icon=currentInterruptMacroIcon()
  local index=findCharacterMacroByName(name)
  local ok,result=true,index
  local lastError=nil

  if index and index>0 then
    local infoOK,oldName,oldIcon,oldBody=pcall(GetMacroInfo,index)
    oldName=infoOK and safeText(oldName) or nil
    oldBody=infoOK and safeText(oldBody) or nil
    local oldIconText=infoOK and safeText(oldIcon) or nil
    local iconText=safeText(icon)
    if oldName~=name or oldBody~=body or oldIconText~=iconText then
      ok,result=pcall(EditMacro,index,name,icon,body)
      if not ok then lastError=safeText(result) or "오토 EditMacro 실패" end
    end
  else
    local _,charCount=macroCounts()
    local charMax=safeNum(_G.MAX_CHARACTER_MACROS) or 18
    if charCount>=charMax then
      ok=false
      lastError=string.format("캐릭터 전용 매크로 칸 가득 참 · %d/%d",charCount,charMax)
    else
      ok,result=pcall(CreateMacro,name,icon,body,true)
      if ok then
        index=safeNum(result) or 0
        if index<=0 then lastError="CreateMacro가 유효한 개인 매크로 번호를 반환하지 않음" end
      else
        index=0
        lastError=safeText(result) or "오토 CreateMacro 실패"
      end
    end
  end

  if not ok or not index or index<=0 then
    RDE._autoInterruptMacroUpdatePending=true
    if not silent and not RDE._autoInterruptMacroFailureShown then
      RDE._autoInterruptMacroFailureShown=true
      P("오토 생성 실패 · "..tostring(lastError or "원인 미확인"))
    end
    return false,lastError or "failed"
  end

  db.autoInterruptMacroName=name
  RDE._autoInterruptMacroUpdatePending=false
  RDE._autoInterruptMacroFailureShown=false
  if not silent then
    P("오토 갱신 · 주시 우선 → 무리 자동 차단 → 원래 대상 복귀 · 캐릭터 전용")
  end
  return true,"캐릭터 전용"
end

RDE.GetAutoInterruptMacroStatus=function()
  if not db then return "초기화 전" end
  if db.autoInterruptMacroEnabled==false then return "OFF" end
  local name=safeText(db.autoInterruptMacroName) or "NiniKickAuto"
  local index=findCharacterMacroByName(name)
  return index>0 and (name.." 준비됨") or (name.." 없음")
end
local function spellTexture(id) local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id); return info and info.iconID or 134400 end


-- 주문 발동 경보가 UI 프로필/다른 애드온에 의해 꺼지는 것을 방지한다.
-- 사용자가 요청한 고정값: 경보 사용 1, 투명도 0.65.
-- 2.0.12: 그래픽/전투 최적화 프리셋 묶음. do 블록 안 local은 top-level 한도에 포함되지 않음.
do
local function getCVarSafe(name)
  local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
  if not getter then return nil end
  local ok,value=pcall(getter,name)
  if not ok or (type(issecretvalue)=="function" and issecretvalue(value)) then return nil end
  return value
end

local function setCVarSafe(name,value)
  local setter=(C_CVar and C_CVar.SetCVar) or SetCVar
  if not setter then return false end
  local ok=pcall(setter,name,tostring(value))
  return ok and true or false
end

-- NaowhQOL graphics/performance preset, reconstructed from the user's saved
-- cvarManaged profile. Gameplay/UI CVars that are unrelated to graphics are
-- intentionally kept separate so this button does not unexpectedly alter UI behavior.
local NAOWH_GRAPHICS_PRESET={
  VSync="0", MSAAQuality="0", LowLatencyMode="3", renderScale="1",
  GxApi="D3D12", GxMaxFrameLatency="2",
  ResampleQuality="3", ResampleAlwaysSharpen="1", ResampleSharpness="0",
  TextureFilteringMode="5", ffxAntiAliasingMode="4", shadowRt="0",
  graphicsProjectedTextures="1", graphicsTextureResolution="2", graphicsSpellDensity="0",
  graphicsLiquidDetail="2", graphicsShadowQuality="1", graphicsGroundClutter="0",
  graphicsViewDistance="3", graphicsEnvironmentDetail="3", graphicsParticleDensity="3",
  graphicsOutlineMode="2", graphicsSSAO="0", graphicsDepthEffects="0", graphicsComputeEffects="0",
  raidGraphicsProjectedTextures="1", raidGraphicsTextureResolution="2", raidGraphicsSpellDensity="0",
  raidGraphicsLiquidDetail="0", raidGraphicsShadowQuality="0", raidGraphicsGroundClutter="0",
  raidGraphicsViewDistance="0", raidGraphicsEnvironmentDetail="0", raidGraphicsParticleDensity="3",
  raidGraphicsOutlineMode="2", raidGraphicsSSAO="0", raidGraphicsDepthEffects="0", raidGraphicsComputeEffects="0",
  RAIDsettingsEnabled="1", physicsLevel="1",
  useTargetFPS="0", useMaxFPS="0", useMaxFPSBk="0", maxFPS="200", maxFPSBk="30", maxFPSLoading="30",
  cameraDistanceMaxZoomFactor="2.6", cameraShake="0", ShakeStrengthCamera="0", ShakeStrengthUI="0",
  ffxGlow="0", ffxDeath="0", ffxVenari="0", ffxLingeringVenari="0", ffxNether="0", overrideScreenFlash="1",
}

local NAOWH_COMBAT_PRESET={
  SpellQueueWindow="96",
  advancedCombatLogging="1",
  disableServerNagle="1",
}

local function eachPresetKey(fn)
  local seen={}
  for k,v in pairs(NAOWH_GRAPHICS_PRESET) do seen[k]=true; fn(k,v,"graphics") end
  for k,v in pairs(NAOWH_COMBAT_PRESET) do if not seen[k] then fn(k,v,"combat") end end
end

local function backupOptimizationCVars(force)
  if not db then return false,0 end
  if type(db.graphicsBackup)~="table" or force then db.graphicsBackup={} end
  local n=0
  eachPresetKey(function(name)
    if force or db.graphicsBackup[name]==nil then
      local value=getCVarSafe(name)
      if value~=nil then db.graphicsBackup[name]=tostring(value); n=n+1 end
    end
  end)
  db.graphicsBackupVersion=1
  return true,n
end

local function applyOptimizationPreset(preset,label)
  if InCombatLockdown and InCombatLockdown() then
    P("전투 중에는 그래픽/성능 설정을 변경하지 않습니다. 전투 종료 후 다시 눌러주세요.")
    return false,0,0
  end
  if type(db.graphicsBackup)~="table" or next(db.graphicsBackup)==nil then backupOptimizationCVars(false) end
  local changed,failed=0,0
  for name,value in pairs(preset) do
    local current=getCVarSafe(name)
    if current~=nil and tostring(current)==tostring(value) then
      -- already correct
    elseif setCVarSafe(name,value) then changed=changed+1 else failed=failed+1 end
  end
  db.graphicsLastAction=label or "프리셋 적용"
  db.graphicsLastChanged=changed
  db.graphicsLastFailed=failed
  P(string.format("%s · %d개 변경%s",db.graphicsLastAction,changed,failed>0 and (" · 실패 "..failed) or ""))
  
  return true,changed,failed
end

local function applyNaowhGraphicsPreset()
  return applyOptimizationPreset(NAOWH_GRAPHICS_PRESET,"Naowh 그래픽 최적화 적용")
end

local function applyNaowhCombatPreset()
  return applyOptimizationPreset(NAOWH_COMBAT_PRESET,"전투 성능 옵션 적용")
end

local function restoreOptimizationBackup()
  if InCombatLockdown and InCombatLockdown() then
    P("전투 중에는 설정을 복원하지 않습니다. 전투 종료 후 다시 눌러주세요.")
    return false
  end
  if not db or type(db.graphicsBackup)~="table" or next(db.graphicsBackup)==nil then
    P("복원할 그래픽 설정 백업이 없습니다.")
    return false
  end
  local changed,failed=0,0
  for name,value in pairs(db.graphicsBackup) do
    local current=getCVarSafe(name)
    if current~=nil and tostring(current)==tostring(value) then
    elseif setCVarSafe(name,value) then changed=changed+1 else failed=failed+1 end
  end
  db.graphicsLastAction="백업 설정 복원"; db.graphicsLastChanged=changed; db.graphicsLastFailed=failed
  P(string.format("그래픽/성능 백업 복원 · %d개 변경%s",changed,failed>0 and (" · 실패 "..failed) or ""))
  
  return true
end

local function presetMatchCount(preset)
  local total,match=0,0
  for name,value in pairs(preset) do
    total=total+1
    local current=getCVarSafe(name)
    if current~=nil and tostring(current)==tostring(value) then match=match+1 end
  end
  return match,total
end

RDE.ApplyNaowhGraphicsPreset=applyNaowhGraphicsPreset
RDE.ApplyNaowhCombatPreset=applyNaowhCombatPreset
RDE.BackupOptimizationCVars=function(force) return backupOptimizationCVars(force~=false) end
RDE.RestoreGraphicsBackup=restoreOptimizationBackup
RDE.GetOptimizationSummary=function()
  if not db then return "초기화 전" end
  local gm,gt=presetMatchCount(NAOWH_GRAPHICS_PRESET)
  local cm,ct=presetMatchCount(NAOWH_COMBAT_PRESET)
  local backupN=0
  if type(db.graphicsBackup)=="table" then for _ in pairs(db.graphicsBackup) do backupN=backupN+1 end end
  local last=db.graphicsLastAction and (" · 최근: "..db.graphicsLastAction) or ""
  return string.format("그래픽 %d/%d · 전투 %d/%d · 백업 %d개%s",gm,gt,cm,ct,backupN,last)
end


local function enforceSpellActivationOverlays()
  local enabled=getCVarSafe("displaySpellActivationOverlays")
  if tostring(enabled or "")~="1" then
    setCVarSafe("displaySpellActivationOverlays","1")
  end

  local opacity=safeNum(getCVarSafe("spellActivationOverlayOpacity"))
  if not opacity or math.abs(opacity-0.65)>0.001 then
    setCVarSafe("spellActivationOverlayOpacity","0.65")
  end
end
RDE.EnforceSpellActivationOverlays=enforceSpellActivationOverlays
RDE.NAOWH_GRAPHICS_PRESET=NAOWH_GRAPHICS_PRESET
RDE.NAOWH_COMBAT_PRESET=NAOWH_COMBAT_PRESET
end


local function validTtsVoiceID(requested)
  local wanted=safeNum(requested) or 0
  local fn=C_VoiceChat and C_VoiceChat.GetTtsVoices
  if not fn then return 0 end
  local ok,voices=pcall(fn)
  if not ok or type(voices)~="table" then return 0 end
  for _,voice in ipairs(voices) do
    if type(voice)=="table" and safeNum(voice.voiceID)==wanted then return wanted end
  end
  return 0
end

local function speakTTS(text, requestedVoiceID)
  if not (C_VoiceChat and C_VoiceChat.SpeakText) then return end

  -- Current client signature, matching NSRT:
  -- SpeakText(voiceID, text, speechRate, volume, allowOverlap)
  -- Do not use Enum.VoiceTtsDestination; that enum is absent on this client.
  local voiceID=validTtsVoiceID(requestedVoiceID)
  local rate=0
  if C_TTSSettings and C_TTSSettings.GetSpeechRate then
    local ok,value=pcall(C_TTSSettings.GetSpeechRate)
    if ok then rate=safeNum(value) or 0 end
  end
  local volume=100
  local overlap=db.ttsOverlap and true or false
  local ok=pcall(C_VoiceChat.SpeakText,voiceID,tostring(text or ""),rate,volume,overlap)
  if not ok and db.debug and not MS.ttsErrorShown then
    MS.ttsErrorShown=true
    P("게임 TTS 재생에 실패했습니다. TTS 목소리 설정을 확인해주세요.")
  end
end

local function speakDefensive(text)
  -- 생존기 알림은 기본 게임 TTS로 고정한다.
  -- 차단에 선택한 SharedMedia 음향/목소리는 교란·그망·회피·소멸에 적용하지 않는다.
  speakTTS(text, 0)
end

local function speakInterrupt(text)
  -- 2.0.28: 차단 음성은 NiniTools 내장 Naowh Kick으로 고정한다.
  -- 외부 SharedMedia/TTS 선택값은 더 이상 차단 알림에 사용하지 않는다.
  local channel=(db and db.soundChannel) or "Master"
  if PlaySoundFile then
    pcall(PlaySoundFile,RDE.BUILTIN_KICK_SOUND_PATH,channel)
  end
end

local function setFontSize(fs,fontObject,size)
  local _,_,flags=fontObject:GetFont()
  fs:SetFont(themeFontPath(),size,flags or "")
end

-- 2.0.23: 아이콘과 텍스트를 각각 끌 수 있다.
-- 둘 다 끄면 화면에는 아무것도 그리지 않고 음성만 남는다.
local function alertShowsIcon() return db.alertIconEnabled~=false end
local function alertShowsText() return db.alertTextEnabled~=false end

local function layoutSimpleAlert()
  if not alert then return end
  local iconSize=clamp(db.iconSize,24,80)
  local gap=clamp(db.textGap,0,24)
  local frameWidth=390
  local showIcon=alertShowsIcon()
  local showText=alertShowsText()
  local labelWidth=math.max(120,frameWidth-(showIcon and iconSize or 0)-gap-14)
  local subText=alert.sub:GetText() or ""
  local subVisible=showText and db.simpleShowMechanic~=false and subText~=""

  alert.icon:SetShown(showIcon)
  alert.text:SetShown(showText)
  alert.sub:SetShown(subVisible)
  if alert.accent then alert.accent:SetShown(showIcon) end

  -- 프레임 폭을 고정해 문구 길이가 달라도 왼쪽 아이콘 기준점이 움직이지 않는다.
  alert:SetSize(frameWidth,iconSize)
  alert.icon:SetSize(iconSize,iconSize)
  alert.icon:ClearAllPoints(); alert.icon:SetPoint("LEFT",4,0)
  if alert.accent then
    alert.accent:ClearAllPoints(); alert.accent:SetPoint("TOPLEFT",alert.icon,"TOPRIGHT",math.max(3,math.floor(gap/2)),-3); alert.accent:SetPoint("BOTTOMLEFT",alert.icon,"BOTTOMRIGHT",math.max(3,math.floor(gap/2)),3); alert.accent:SetWidth(2)
  end
  alert.text:SetWidth(labelWidth)
  alert.sub:SetWidth(labelWidth)
  alert.text:ClearAllPoints()
  alert.sub:ClearAllPoints()
  if not showText then return end
  if showIcon then
    if subVisible then
      alert.text:SetPoint("TOPLEFT",alert.icon,"TOPRIGHT",gap,-2)
      alert.sub:SetPoint("BOTTOMLEFT",alert.icon,"BOTTOMRIGHT",gap,2)
    else
      alert.text:SetPoint("LEFT",alert.icon,"RIGHT",gap,0)
    end
  else
    -- 아이콘이 없으면 텍스트가 프레임 왼쪽을 기준점으로 삼는다.
    if subVisible then
      alert.text:SetPoint("TOPLEFT",4,-2)
      alert.sub:SetPoint("BOTTOMLEFT",4,2)
    else
      alert.text:SetPoint("LEFT",4,0)
    end
  end
end

local function applyAlertStyle()
  if not alert then return end
  db.displayStyle="ICON"
  local iconSize=clamp(db.iconSize,24,80)
  local timerSize=clamp(db.timerTextSize,10,36)
  local textSize=clamp(db.alertTextSize,10,36)

  alert.bg:Hide()
  styleEdges(alert,0,0,0,0)
  local ar,ag,ab=themeAccent(); if alert.accent then alert.accent:SetColorTexture(ar,ag,ab,0) end
  alert.icon:SetSize(iconSize,iconSize)
  alert.icon:SetBackdrop(nil)
  alert.icon.border:Hide()
  alert.icon.cd:SetHideCountdownNumbers(true)
  alert.icon.cd:SetDrawBling(false)
  alert.icon.cd:SetDrawEdge(false)
  alert.icon.cd:SetReverse(true)

  alert.icon.count:SetFont(themeFontPath("num"),timerSize,"OUTLINE")
  alert.icon.count:SetTextColor(1,1,1,1)
  alert.icon.count:SetShadowColor(0,0,0,0)
  alert.icon.count:SetShadowOffset(0,0)

  setFontSize(alert.text,GameFontNormal,textSize)
  setFontSize(alert.sub,GameFontDisableSmall,math.max(9,textSize-4))
  alert.timer:Hide()
  layoutSimpleAlert()
end

local function buildAlert()
  local f=CreateFrame("Frame","NiniKickNSRTAlert",UIParent,"BackdropTemplate")
  f:SetPoint("CENTER",UIParent,"CENTER",db.x,db.y); f:SetScale(db.scale)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(self) if db.unlocked then self:StartMoving() end end)
  f:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local _,_,_,x,y=self:GetPoint(); db.x,db.y=x,y
  end)
  f.bg=f:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(.012,.016,.022,.86)
  f.accent=f:CreateTexture(nil,"OVERLAY")
  f.icon=CreateFrame("Frame",nil,f,"BackdropTemplate")
  f.icon.tex=f.icon:CreateTexture(nil,"ARTWORK"); f.icon.tex:SetAllPoints(); f.icon.tex:SetTexCoord(.07,.93,.07,.93)
  f.icon.cd=CreateFrame("Cooldown",nil,f.icon,"CooldownFrameTemplate"); f.icon.cd:SetAllPoints(); f.icon.cd:SetDrawEdge(false)
  f.icon.count=f.icon:CreateFontString(nil,"OVERLAY","NumberFontNormalHuge"); f.icon.count:SetPoint("CENTER",0,0)
  f.icon.border=f.icon:CreateTexture(nil,"OVERLAY"); f.icon.border:SetAllPoints(); f.icon.border:SetColorTexture(0,0,0,.28)
  f.icon.edgeTop=f.icon:CreateTexture(nil,"OVERLAY"); f.icon.edgeTop:SetColorTexture(0,0,0,1); f.icon.edgeTop:SetPoint("TOPLEFT"); f.icon.edgeTop:SetPoint("TOPRIGHT"); f.icon.edgeTop:SetHeight(1)
  f.icon.edgeBottom=f.icon:CreateTexture(nil,"OVERLAY"); f.icon.edgeBottom:SetColorTexture(0,0,0,1); f.icon.edgeBottom:SetPoint("BOTTOMLEFT"); f.icon.edgeBottom:SetPoint("BOTTOMRIGHT"); f.icon.edgeBottom:SetHeight(1)
  f.icon.edgeLeft=f.icon:CreateTexture(nil,"OVERLAY"); f.icon.edgeLeft:SetColorTexture(0,0,0,1); f.icon.edgeLeft:SetPoint("TOPLEFT"); f.icon.edgeLeft:SetPoint("BOTTOMLEFT"); f.icon.edgeLeft:SetWidth(1)
  f.icon.edgeRight=f.icon:CreateTexture(nil,"OVERLAY"); f.icon.edgeRight:SetColorTexture(0,0,0,1); f.icon.edgeRight:SetPoint("TOPRIGHT"); f.icon.edgeRight:SetPoint("BOTTOMRIGHT"); f.icon.edgeRight:SetWidth(1)
  f.text=f:CreateFontString(nil,"OVERLAY","GameFontNormalHuge"); f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(false)
  f.sub=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(false)
  f.timer=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.timer:SetJustifyH("RIGHT")
  f:SetScript("OnUpdate",function(self,elapsed)
    if not self._expires or not self:IsShown() then self._niniUpdateElapsed=0; return end
    self._niniUpdateElapsed=(self._niniUpdateElapsed or 0)+(elapsed or 0)
    if self._niniUpdateElapsed<0.05 then return end
    self._niniUpdateElapsed=0
    local remain=self._expires-now(); if remain<0 then remain=0 end
    self.icon.count:SetText(string.format("%.1f",remain))
    if remain<=3 then self.icon.count:SetTextColor(1,.12,.08,1) else self.icon.count:SetTextColor(1,1,1,1) end
  end)
  f:Hide(); alert=f; applyAlertStyle()
end

local function showMoveAnchor()
  if not alert then return end
  if alert._hideTimer and alert._hideTimer.Cancel then alert._hideTimer:Cancel(); alert._hideTimer=nil end
  alert._serial=(alert._serial or 0)+1
  alert._expires=nil
  applyAlertStyle()
  alert.icon.tex:SetTexture(spellTexture(1966))
  alert.icon.cd:Clear(); alert.icon.count:SetText("")
  alert.text:SetText("위치 이동")
  alert.text:SetTextColor(1,.82,0,1)
  alert.sub:SetText("프레임을 드래그한 뒤 위치 고정")
  alert.icon.count:SetText("")
  layoutSimpleAlert()
  -- move mode: keep it clean with no frame background/border
  alert.bg:Hide()
  styleEdges(alert,0,0,0,0)
  if alert.accent then alert.accent:SetColorTexture(0,0,0,0) end
  alert:SetBackdrop(nil)
  alert:Show(); alert:SetAlpha(1)
  MS.moveAnchorActive=true
end

local function hideMoveAnchor()
  MS.moveAnchorActive=false
  if not alert then return end
  if alert._hideTimer and alert._hideTimer.Cancel then alert._hideTimer:Cancel(); alert._hideTimer=nil end
  alert._expires=nil
  applyAlertStyle()
  alert.icon.cd:Clear(); alert.icon.count:SetText(""); alert:Hide()
end

local function setUnlockState(flag)
  db.unlocked=flag and true or false
  alert:SetBackdrop(nil)
  if db.unlocked then showMoveAnchor(); P("알림 위치 이동 가능") else hideMoveAnchor(); P("알림 위치 잠금") end
  
end

local function formatCombatDuration(seconds)
  local total=math.max(0,math.floor((tonumber(seconds) or 0)+0.0001))
  local h=math.floor(total/3600)
  local m=math.floor((total%3600)/60)
  local sec=total%60
  if h>0 then return string.format("%d:%02d:%02d",h,m,sec) end
  return string.format("%d:%02d",m,sec)
end

local function refreshCombatTimerStyle()
  if not combatTimer or not db then return end
  local size=clamp(db.combatTimerTextSize or 24,12,48)
  combatTimer.text:SetFont(themeFontPath("num"),size,"OUTLINE")
  local ar,ag,ab=themeAccent()
  combatTimer.text:SetTextColor(ar,ag,ab,1)
  combatTimer.text:SetShadowColor(0,0,0,.85)
  combatTimer.text:SetShadowOffset(1,-1)
end

local function updateCombatTimerText(force)
  if not combatTimer or not combatTimerState.active then return end
  local elapsed=math.max(0,now()-(combatTimerState.startTime or now()))
  local sec=math.floor(elapsed)
  if force or sec~=combatTimerState.lastSecond then
    combatTimerState.lastSecond=sec
    combatTimer.text:SetText(formatCombatDuration(elapsed))
  end
end

local function showCombatTimerMoveAnchor()
  if not combatTimer or not db then return end
  refreshCombatTimerStyle()
  combatTimer.text:SetText("0:00")
  local ar,ag,ab=themeAccent()
  combatTimer.text:SetTextColor(ar,ag,ab,1)
  combatTimer:EnableMouse(true)
  combatTimer:Show()
end

local function hideCombatTimerMoveAnchor()
  if not combatTimer or not db then return end
  refreshCombatTimerStyle()
  combatTimer:EnableMouse(false)
  if combatTimerState.active and db.combatTimerEnabled~=false then
    updateCombatTimerText(true)
    combatTimer:Show()
  else
    combatTimer:Hide()
  end
end

local function setCombatTimerUnlockState(flag)
  if not db or not combatTimer then return end
  db.combatTimerUnlocked=flag and true or false
  if db.combatTimerUnlocked then
    showCombatTimerMoveAnchor()
    P("전투시간 위치 이동 가능")
  else
    hideCombatTimerMoveAnchor()
    P("전투시간 위치 잠금")
  end
  
end

RDE.SnapCombatTimerCoord=function(v)
  v=tonumber(v) or 0
  return math.floor(v+0.5)
end

-- 2.0.1: 캐릭터 전환/재접속에도 유지되는 계정 공통 전투시간 위치.
-- top-level local을 추가하지 않아 Lua 200-local 제한을 피한다.
RDE.CombatTimerSharedDB=function(create)
  if type(NiniToolsDB)~="table" then
    if not create then return nil end
    NiniToolsDB={}
  end
  if type(NiniToolsDB.ui)~="table" then
    if not create then return nil end
    NiniToolsDB.ui={}
  end
  if type(NiniToolsDB.ui.combatTimer)~="table" then
    if not create then return nil end
    NiniToolsDB.ui.combatTimer={}
  end
  return NiniToolsDB.ui.combatTimer
end

RDE.SaveCombatTimerSharedPosition=function(x,y)
  local shared=RDE.CombatTimerSharedDB(true)
  shared.x=RDE.SnapCombatTimerCoord(x or 0)
  shared.y=RDE.SnapCombatTimerCoord(y or 105)
  shared.saved=true
  if db then
    db.combatTimerX=shared.x
    db.combatTimerY=shared.y
  end
end

RDE.LoadCombatTimerSharedPosition=function()
  if not db then return 0,105 end
  local shared=RDE.CombatTimerSharedDB(true)

  -- 첫 2.0.1 실행에서는 기존에 맞춰둔 위치를 그대로 승격한다.
  if shared.saved~=true then
    shared.x=RDE.SnapCombatTimerCoord(db.combatTimerX or 0)
    shared.y=RDE.SnapCombatTimerCoord(db.combatTimerY or 105)
    shared.saved=true
  end

  local x=RDE.SnapCombatTimerCoord(shared.x or db.combatTimerX or 0)
  local y=RDE.SnapCombatTimerCoord(shared.y or db.combatTimerY or 105)
  shared.x,shared.y=x,y
  db.combatTimerX,db.combatTimerY=x,y
  return x,y
end

RDE.ApplyCombatTimerPosition=function()
  if not db or not combatTimer then return end
  local x,y=RDE.LoadCombatTimerSharedPosition()
  combatTimer:ClearAllPoints()
  combatTimer:SetPoint("CENTER",UIParent,"CENTER",x,y)
end

local function resetCombatTimerPosition()
  if not db or not combatTimer then return end
  RDE.SaveCombatTimerSharedPosition(0,105)
  RDE.ApplyCombatTimerPosition()
  if db.combatTimerUnlocked then showCombatTimerMoveAnchor() end
end

local function startCombatTimer()
  if not db or db.combatTimerEnabled==false or not combatTimer or combatTimerState.active then return end
  combatTimerState.serial=(combatTimerState.serial or 0)+1
  combatTimerState.active=true
  combatTimerState.startTime=now()
  combatTimerState.lastSecond=-1
  refreshCombatTimerStyle()
  if db.combatTimerUnlocked then
    showCombatTimerMoveAnchor()
  else
    updateCombatTimerText(true)
    combatTimer:Show()
  end
end

local function stopCombatTimer()
  if not combatTimerState.active then return end
  local elapsed=math.max(0,now()-(combatTimerState.startTime or now()))
  combatTimerState.active=false
  combatTimerState.lastSecond=-1
  combatTimerState.serial=(combatTimerState.serial or 0)+1
  local serial=combatTimerState.serial
  if not db or db.combatTimerEnabled==false or not combatTimer then return end
  if db.combatTimerUnlocked then
    showCombatTimerMoveAnchor()
    return
  end
  refreshCombatTimerStyle()
  combatTimer.text:SetText(formatCombatDuration(elapsed))
  combatTimer:Show()
  local hold=clamp(db.combatTimerEndHold or 2.5,1,8)
  local function hideFinal()
    if not combatTimer or not db then return end
    if combatTimerState.serial~=serial or combatTimerState.active or db.combatTimerUnlocked then return end
    combatTimer:Hide()
  end
  if C_Timer and C_Timer.After then C_Timer.After(hold,hideFinal) else hideFinal() end
end

local function setCombatTimerEnabled(flag)
  if not db or not combatTimer then return end
  db.combatTimerEnabled=flag and true or false
  combatTimerState.serial=(combatTimerState.serial or 0)+1
  if not db.combatTimerEnabled then
    combatTimerState.active=false
    combatTimer:Hide()
    P("전투시간 꺼짐")
  else
    P("전투시간 켜짐")
    local inCombat=false
    if type(UnitAffectingCombat)=="function" then
      local ok,v=pcall(UnitAffectingCombat,"player")
      inCombat=ok and safeBool(v)==true
    end
    if inCombat then startCombatTimer()
    elseif db.combatTimerUnlocked then showCombatTimerMoveAnchor() end
  end
  
end

local function previewCombatTimer()
  if not combatTimer or not db then return end
  combatTimerState.serial=(combatTimerState.serial or 0)+1
  local serial=combatTimerState.serial
  refreshCombatTimerStyle()
  combatTimer.text:SetText("1:23")
  combatTimer:Show()
  if C_Timer and C_Timer.After then
    C_Timer.After(2.5,function()
      if not combatTimer or combatTimerState.serial~=serial or combatTimerState.active or db.combatTimerUnlocked then return end
      combatTimer:Hide()
    end)
  end
end

local function buildCombatTimer()
  local f=CreateFrame("Frame","NiniKickCombatTimer",UIParent)
  f:SetSize(190,54)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(false)
  f:RegisterForDrag("LeftButton")
  f.text=f:CreateFontString(nil,"OVERLAY")
  f.text:SetPoint("CENTER")
  f.text:SetWidth(170)
  f.text:SetJustifyH("CENTER")
  f:SetScript("OnDragStart",function(self)
    if db and db.combatTimerUnlocked then self:StartMoving() end
  end)
  f:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    if not db then return end
    local x,y=self:GetCenter(); local ux,uy=UIParent:GetCenter()
    if x and y and ux and uy then
      local px=RDE.SnapCombatTimerCoord(x-ux)
      local py=RDE.SnapCombatTimerCoord(y-uy)
      RDE.SaveCombatTimerSharedPosition(px,py)
      self:ClearAllPoints()
      self:SetPoint("CENTER",UIParent,"CENTER",px,py)
    end
  end)
  f:SetScript("OnUpdate",function(self,elapsed)
    if db and db.combatTimerUnlocked then self._niniUpdateElapsed=0; return end
    if not combatTimerState.active then self._niniUpdateElapsed=0; return end
    self._niniUpdateElapsed=(self._niniUpdateElapsed or 0)+(elapsed or 0)
    if self._niniUpdateElapsed<0.10 then return end
    self._niniUpdateElapsed=0
    updateCombatTimerText(false)
  end)
  combatTimer=f
  RDE.ApplyCombatTimerPosition()
  refreshCombatTimerStyle()
  f:Hide()
  if db.combatTimerUnlocked then C_Timer.After(0,showCombatTimerMoveAnchor) end
end


local function show(rule,payload,textOverride,voiceOverride,iconOverride,voiceProfile)
  if not db.enabled then return end
  -- 개인 생존기 방어 알림은 도적 전용이다. 차단 로테이션은 모든 직업에서 사용한다.
  if voiceProfile~="INTERRUPT" then
    -- 2.5.1: 생존기 담당 판정은 Naowh adapter 한 곳에서만 한다.
    -- 단순 addon load가 아니라 실제 활성 프로필(enabled=true)일 때만 양보하며,
    -- 사용자가 "NiniTools 알림 유지"를 켜면 언제나 NiniTools가 우선한다.
    local nt=_G.NiniTools
    local adapters=nt and nt.Adapters
    if adapters and type(adapters.IsNaowhReminderOwner)=="function" then
      local ok,owned=pcall(adapters.IsNaowhReminderOwner,adapters)
      if ok and owned then return end
    end
    if not isRogue or db.defensiveEnabled==false then return end
  end
  local actions=RDE.ACTIONS or {}
  local action=actions[rule.action] or actions.FEINT or {
    spellID=1966,
    text="차단",
    tts="차단",
    color={0.00,0.81,1.00},
  }
  local timerFlag=payload and safeBool(payload.timerKnown) or nil
  local timerKnown=timerFlag~=false
  local dur=safeNum(payload and payload.totalDuration) or safeNum(rule.displayDuration) or db.duration
  if dur<.2 or dur>30 then dur=db.duration; timerKnown=false end
  applyAlertStyle()
  alert.icon.tex:SetTexture(iconOverride or spellTexture(action.spellID))
  alert.icon.cd:Clear(); alert.icon.count:SetText("")
  if timerKnown then alert.icon.cd:SetCooldown(now(),dur) end
  local txt=textOverride or action.text
  if rule.tentative and db.showTentative then txt=txt.." ?" end
  alert.text:SetText(txt)
  local color=action.color or {1,.82,0}; alert.text:SetTextColor(color[1] or 1,color[2] or .82,color[3] or 0,1)
  local sub=rule.name or ""
  if db.showAlternates and rule.alts and #rule.alts>0 then
    local a={}; for _,k in ipairs(rule.alts) do a[#a+1]=(RDE.ACTIONS[k] and RDE.ACTIONS[k].text or k) end
    sub=sub.."  ·  "..table.concat(a,"/")
  end
  if db.simpleShowMechanic==false then sub="" end
  alert.sub:SetText(sub)
  if alert._hideTimer and alert._hideTimer.Cancel then alert._hideTimer:Cancel(); alert._hideTimer=nil end
  alert._serial=(alert._serial or 0)+1
  local serial=alert._serial
  if timerKnown then
    alert._expires=now()+dur
    alert.icon.count:SetText(string.format("%.1f",dur))
    if dur<=3 then alert.icon.count:SetTextColor(1,.12,.08,1) else alert.icon.count:SetTextColor(1,1,1,1) end
  else
    alert._expires=nil
    alert.icon.count:SetText("")
  end
  layoutSimpleAlert()
  -- 2.0.23: 아이콘과 텍스트를 모두 끄면 화면에는 아무것도 띄우지 않는다.
  -- 위치 이동 중에는 앵커를 봐야 하므로 예외로 둔다.
  local visualOn=(voiceProfile~="INTERRUPT") and (alertShowsIcon() or alertShowsText() or db.unlocked)
  if visualOn then
    alert:Hide(); alert:Show(); alert:SetAlpha(1)
  else
    alert:Hide()
  end
  if voiceProfile=="INTERRUPT" then speakInterrupt(voiceOverride or txt) else speakDefensive(voiceOverride or action.tts or txt) end
  local hideAfter=math.max(.4,(timerKnown and dur or db.duration)+.25)
  local function hideCurrent()
    if alert and alert._serial==serial then
      alert.icon.cd:Clear(); alert.icon.count:SetText(""); alert._hideTimer=nil; alert._expires=nil
      if db.unlocked then showMoveAnchor() else alert:Hide() end
    end
  end
  if C_Timer and C_Timer.NewTimer then alert._hideTimer=C_Timer.NewTimer(hideAfter,hideCurrent) else C_Timer.After(hideAfter,hideCurrent) end
end



local function registerTargetRules()
  -- Standalone 1.0: EXBoss TargetAlert is no longer used.
  -- PLAYER/AURA filtering is handled directly by Blizzard unit/cast/aura events below.
end

local INTERRUPT_SPELLS={
  [1766]={cd=15,classFile="ROGUE",name="발차기"},
  [6552]={cd=15,classFile="WARRIOR",name="들이치기"},
  [47528]={cd=15,classFile="DEATHKNIGHT",name="정신 얼리기"},
  [183752]={cd=15,classFile="DEMONHUNTER",name="분열"},
  [57994]={cd=12,classFile="SHAMAN",name="날카로운 바람"},
  [2139]={cd=24,classFile="MAGE",name="마법 차단"},
  [19647]={cd=24,classFile="WARLOCK",name="주문 잠금"},
  [119910]={cd=24,classFile="WARLOCK",name="지옥사냥개 지배"},
  [147362]={cd=24,classFile="HUNTER",name="반격의 사격"},
  [187707]={cd=15,classFile="HUNTER",name="재갈"},
  [106839]={cd=15,classFile="DRUID",name="두개골 강타"},
  [78675]={cd=60,classFile="DRUID",name="태양 광선"},
  [96231]={cd=15,classFile="PALADIN",name="비난"},
  [116705]={cd=15,classFile="MONK",name="손날 찌르기"},
  [351338]={cd=40,classFile="EVOKER",name="진압"},
  [15487]={cd=45,classFile="PRIEST",name="침묵"},
}

local partyKickState={}
local recentInterrupts={}
local rotationRoster={}
local rebuildRotationRoster

local function refreshImportantCastVisuals()
  local fn=RDE.ImportantCastRefreshAll
  if type(fn)=="function" then
    pcall(fn)
  end
end

local function clearActiveInterruptCast()
  interruptState.active=false
  interruptState.counted=false
  interruptState.evaluated=false
  interruptState.interruptible=nil
  interruptState.serial=interruptState.serial+1
  interruptState.lastStart=0
  interruptState.activeRule=nil
  interruptState.expectedOrder=nil
  interruptState.myOrder=nil
  interruptState.alertPlayed=false
  interruptState.backup=false
  interruptState.pendingInterrupt=false
  interruptState.pendingStop=false
  interruptState.castWindow=nil
  interruptState.castBarID=nil
  interruptState.lastDebugDecision=nil
  refreshImportantCastVisuals()
end

local function resetInterruptState(quiet)
  interruptState.currentOrder=1
  MS.adaptivePack=false
  clearActiveInterruptCast()
  if not quiet and db and db.debug then P("차단 순서를 1번으로 초기화했습니다.") end
  
end

local function currentRotationSize(rule)
  local value=rule and rule.size or db.interruptSize
  return (value==3) and 3 or 2
end

local function currentInterruptOrder(rule)
  local size=currentRotationSize(rule)
  local value=rule and rule.order or db.interruptOrder
  return math.max(1,math.min(size,tonumber(value) or 1))
end

local function copyArray(value)
  local out={}
  if type(value)=="table" then
    for i,item in ipairs(value) do
      if type(item)=="table" then
        local row={}
        for k,v in pairs(item) do row[k]=v end
        out[i]=row
      else
        out[i]=item
      end
    end
  end
  return out
end

local function briefingParticipantsInline(participants)
  if type(participants)~="table" then return "" end
  local tokens={}
  for i=1,#participants do
    local item=participants[i]
    local token=type(item)=="table" and safeText(item.token) or nil
    if token then tokens[#tokens+1]=token end
  end
  return #tokens>0 and (" ["..table.concat(tokens,"→").."]") or ""
end

local function saveBriefingBaseState()
  if not db or db.briefingAutoActive then return end
  db.briefingSavedState={
    interruptEnabled=db.interruptEnabled and true or false,
    rotationEnabled=db.rotationEnabled and true or false,
    interruptMarker=tonumber(db.interruptMarker) or 1,
    interruptOrder=tonumber(db.interruptOrder) or 1,
    interruptSize=(db.interruptSize==3) and 3 or 2,
    assignmentActive=db.briefingAssignmentActive and true or false,
    overrideEnabled=db.briefingOverrideEnabled and true or false,
    overrideMarker=tonumber(db.briefingOverrideMarker) or 0,
    unmarkedSoloEnabled=db.briefingUnmarkedSoloEnabled and true or false,
    participants=copyArray(db.briefingParticipants),
    lastText=tostring(db.briefingLastText or ""),
    lastSender=tostring(db.briefingLastSender or ""),
  }
  db.briefingAutoActive=true
end

local function restoreBriefingBaseState()
  if not db or not db.briefingAutoActive or type(db.briefingSavedState)~="table" then return false end
  local saved=db.briefingSavedState
  db.interruptEnabled=saved.interruptEnabled~=false
  db.rotationEnabled=saved.rotationEnabled and true or false
  db.interruptMarker=math.max(1,math.min(8,tonumber(saved.interruptMarker) or 1))
  db.interruptSize=(saved.interruptSize==3) and 3 or 2
  db.interruptOrder=math.max(1,math.min(db.interruptSize,tonumber(saved.interruptOrder) or 1))
  db.briefingAssignmentActive=saved.assignmentActive and true or false
  db.briefingOverrideEnabled=saved.overrideEnabled and true or false
  db.briefingOverrideMarker=tonumber(saved.overrideMarker) or 0
  db.briefingUnmarkedSoloEnabled=saved.unmarkedSoloEnabled and true or false
  db.briefingParticipants=copyArray(saved.participants)
  db.briefingLastText=tostring(saved.lastText or "")
  db.briefingLastSender=tostring(saved.lastSender or "")
  return true
end

local function clearBriefingAssignment(keepBase)
  if not db then return end
  local restored=false
  if not keepBase then restored=restoreBriefingBaseState() end

  db.briefingAutoActive=false
  db.briefingSavedState=nil
  if not restored then
    db.briefingAssignmentActive=false
    db.briefingOverrideEnabled=false
    db.briefingOverrideMarker=0
    db.briefingUnmarkedSoloEnabled=false
    db.briefingParticipants={}
    db.briefingLastText=""
    db.briefingLastSender=""
  end

  wipe(rotationRoster)
  resetInterruptState(true)
  C_Timer.After(.05,rebuildRotationRoster)
  ensureFocusMarkerMacro(true)
  
end

local function readFocusMarker()
  if not UnitExists("focus") then
    MS.lastKnownFocusMarker=nil
    return nil,"none"
  end
  local ok,value=pcall(GetRaidTargetIndex,"focus")
  if not ok then return MS.lastKnownFocusMarker,"error" end
  if type(issecretvalue)=="function" and issecretvalue(value) then
    return MS.lastKnownFocusMarker,"secret"
  end
  if value==nil then
    MS.lastKnownFocusMarker=nil
    return nil,"none"
  end
  local marker=safeNum(value)
  if marker and marker>=1 and marker<=8 then
    MS.lastKnownFocusMarker=marker
    return marker,"plain"
  end
  return MS.lastKnownFocusMarker,"unknown"
end

local function baseInterruptRule()
  return {
    marker=tonumber(db.interruptMarker) or 1,
    rotationEnabled=db.rotationEnabled and true or false,
    size=(db.interruptSize==3) and 3 or 2,
    order=tonumber(db.interruptOrder) or 1,
    source=(db.freeFocusSolo and not db.briefingAssignmentActive and not db.rotationEnabled) and "free" or "base",
  }
end

local function resolveInterruptRuleForFocus()
  local marker,state=readFocusMarker()
  local assignmentActive=db.briefingAssignmentActive and true or false
  local overrideMarker=tonumber(db.briefingOverrideMarker) or 0

  if assignmentActive and db.briefingOverrideEnabled and marker and marker==overrideMarker then
    return {marker=overrideMarker,rotationEnabled=false,size=1,order=1,source="override"},marker,state
  end

  local base=baseInterruptRule()
  if assignmentActive and state=="none" then
    if db.briefingUnmarkedSoloEnabled then
      return {marker=0,rotationEnabled=false,size=1,order=1,source="unmarked"},nil,"none"
    end
    return nil,nil,"none"
  end
  if assignmentActive and marker and marker~=base.marker then
    return nil,marker,"other-marker"
  end
  return base,marker,state
end

local function groupUnits()
  local units={"player"}
  if IsInRaid and IsInRaid() then
    local count=GetNumGroupMembers and GetNumGroupMembers() or 0
    for i=1,count do units[#units+1]="raid"..i end
  else
    local count=GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for i=1,count do units[#units+1]="party"..i end
  end
  return units
end

local function safeUnitClass(unit)
  if not unit or not UnitExists(unit) then return nil end
  local ok,_,classFile=pcall(UnitClass,unit)
  local value=ok and safeText(classFile) or nil
  return value
end

local function safeUnitRole(unit)
  if not unit or not UnitExists(unit) or not UnitGroupRolesAssigned then return nil end
  local ok,role=pcall(UnitGroupRolesAssigned,unit)
  return ok and safeText(role) or nil
end

local function safeUnitSpecID(unit)
  if not unit or not UnitExists(unit) then return nil end
  if unit=="player" and GetSpecialization and GetSpecializationInfo then
    local spec=GetSpecialization()
    if spec then
      local ok,id=pcall(GetSpecializationInfo,spec)
      return ok and safeNum(id) or nil
    end
  end
  if GetInspectSpecialization then
    local ok,id=pcall(GetInspectSpecialization,unit)
    return ok and safeNum(id) or nil
  end
  return nil
end

local function playerClassFile()
  return safeUnitClass("player")
end

local function playerClassLabel()
  if UnitClass then
    local ok,name=pcall(UnitClass,"player")
    name=ok and safeText(name) or nil
    if name and name~="" then return name end
  end
  return "나"
end

local function defaultInterruptProfile(classFile,specID,token)
  if classFile=="ROGUE" then return 1766,15 end
  if classFile=="WARRIOR" then return 6552,15 end
  if classFile=="DEATHKNIGHT" then return 47528,15 end
  if classFile=="DEMONHUNTER" then return 183752,15 end
  if classFile=="SHAMAN" then return 57994,12 end
  if classFile=="MAGE" then return 2139,24 end
  if classFile=="WARLOCK" then return 19647,24 end
  if classFile=="PALADIN" then return 96231,15 end
  if classFile=="MONK" then return 116705,15 end
  if classFile=="EVOKER" then return 351338,40 end
  if classFile=="HUNTER" then
    if specID==255 or token=="생냥" then return 187707,15 end
    return 147362,24
  end
  if classFile=="DRUID" then
    if specID==102 or token=="조드" then return 78675,60 end
    if specID==103 or specID==104 or token=="야드" or token=="수드" then return 106839,15 end
    return nil,nil
  end
  if classFile=="PRIEST" then
    if specID==258 or token=="암사" then return 15487,45 end
    return nil,nil
  end
  return nil,nil
end

local function findUnitForParticipant(participant,used)
  if type(participant)~="table" then return nil end
  if participant.kind=="PLAYER" then return "player" end
  local matches={}
  local exactSpec={}
  local wantedSpec=safeNum(participant.specID)
  for _,unit in ipairs(groupUnits()) do
    if not used[unit] and UnitExists(unit) then
      local classFile=safeUnitClass(unit)
      local role=safeUnitRole(unit)
      local classOK=not participant.classFile or classFile==participant.classFile
      local roleOK=not participant.role or role==participant.role
      if classOK and roleOK then
        matches[#matches+1]=unit
        if wantedSpec and safeUnitSpecID(unit)==wantedSpec then exactSpec[#exactSpec+1]=unit end
      end
    end
  end
  if wantedSpec and #exactSpec==1 then return exactSpec[1] end
  -- 같은 직업/역할 후보가 여러 명이면 임의로 한 명을 골라 쿨을 잘못 추적하지 않는다.
  if #matches==1 then return matches[1] end
  return nil
end

rebuildRotationRoster=function()
  wipe(rotationRoster)
  if not db or not db.rotationEnabled then return end
  local size=(db.interruptSize==3) and 3 or 2
  local myOrder=math.max(1,math.min(size,tonumber(db.interruptOrder) or 1))
  local participants=type(db.briefingParticipants)=="table" and db.briefingParticipants or {}
  local used={}

  for order=1,size do
    local participant=type(participants[order])=="table" and participants[order] or nil
    local unit
    if participant then
      unit=findUnitForParticipant(participant,used)
    elseif order==myOrder then
      unit="player"
    end
    if unit then used[unit]=true end

    local classFile=(participant and participant.classFile) or safeUnitClass(unit)
    local specID=(participant and safeNum(participant.specID)) or safeUnitSpecID(unit)
    local token=(participant and safeText(participant.token)) or (order==myOrder and playerClassLabel() or (order.."순번"))
    local spellID,cooldown=defaultInterruptProfile(classFile,specID,token)
    if unit and partyKickState[unit] and partyKickState[unit].spellID then
      spellID=partyKickState[unit].spellID
      cooldown=partyKickState[unit].cooldown or cooldown
    end

    rotationRoster[order]={
      order=order,
      unit=unit,
      classFile=classFile,
      specID=specID,
      token=token,
      spellID=spellID,
      cooldown=cooldown,
    }
  end

  -- 브리핑 참가자 정보가 없더라도 내 순서는 현재 플레이어로 확실히 둔다.
  local myClass=playerClassFile()
  local mySpec=safeUnitSpecID("player")
  local mySpell,myCooldown=defaultInterruptProfile(myClass,mySpec,playerClassLabel())
  rotationRoster[myOrder]=rotationRoster[myOrder] or {order=myOrder,token=playerClassLabel()}
  rotationRoster[myOrder].unit="player"
  rotationRoster[myOrder].classFile=myClass
  rotationRoster[myOrder].specID=mySpec
  rotationRoster[myOrder].spellID=mySpell
  rotationRoster[myOrder].cooldown=myCooldown
end

local function playerInterruptSpellID()
  local spellID=defaultInterruptProfile(playerClassFile(),safeUnitSpecID("player"),playerClassLabel())
  return spellID
end

function RDE.GetPlayerInterruptTrackerInfo()
  local spellID,cooldown=defaultInterruptProfile(playerClassFile(),safeUnitSpecID("player"),playerClassLabel())
  if not spellID or not cooldown then return nil end
  return {spellID=spellID,cooldown=cooldown,classFile=playerClassFile()}
end

-- Party tracker helper: expose the same interrupt-profile resolver used by the
-- briefing/backup logic so the tracker can show every interrupt-capable party
-- member immediately, even before their first kick.
function RDE.GetInterruptTrackerUnitInfo(unit)
  unit=safeText(unit)
  if not unit or (unit~="player" and not unit:match("^party[1-4]$")) then return nil end
  if not UnitExists or not UnitExists(unit) then return nil end
  local classFile=safeUnitClass(unit)
  local specID=safeUnitSpecID(unit)
  local spellID,cooldown=defaultInterruptProfile(classFile,specID,nil)
  if not spellID or not cooldown then return nil end
  local name
  if UnitName then
    local ok,n=pcall(UnitName,unit)
    name=ok and safeText(n) or nil
  end
  return {unit=unit,name=name,classFile=classFile,specID=specID,spellID=spellID,cooldown=cooldown}
end

local function playerKickRemaining()
  local spellID=playerInterruptSpellID()
  if not spellID then return nil end
  local info=C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
  if type(info)~="table" then return nil end
  local start=safeNum(info.startTime) or 0
  local duration=safeNum(info.duration) or 0
  local modRate=safeNum(info.modRate) or 1
  local enabled=safeBool(info.isEnabled)
  if duration>604800 then return 0 end
  if enabled==false and duration<=.5 then return 0 end
  -- GCD나 짧은 입력 잠금은 발차기 자체 쿨로 보지 않는다.
  if duration<=1.5 then return 0 end
  if modRate<=0 then modRate=1 end
  local remaining=(start+(duration/modRate))-now()
  if remaining<0 then remaining=0 end
  return remaining
end

local function focusCastRemaining()
  local duration
  if UnitCastingDuration then
    local ok,value=pcall(UnitCastingDuration,"focus")
    if ok then duration=value end
  end
  if not duration and UnitChannelDuration then
    local ok,value=pcall(UnitChannelDuration,"focus")
    if ok then duration=value end
  end
  if not duration or not duration.GetRemainingDuration then return nil end
  local ok,value=pcall(duration.GetRemainingDuration,duration)
  if not ok then return nil end
  local remaining=safeNum(value)
  if remaining and remaining>=0 and remaining<=30 then return remaining end
  return nil
end

local function participantCooldownRemaining(order)
  local entry=rotationRoster[order]
  if not entry or not entry.unit then return nil end
  if entry.unit=="player" then return playerKickRemaining() end

  local state=partyKickState[entry.unit]
  if state and state.readyAt then
    local remaining=state.readyAt-now()
    if remaining<0 then remaining=0 end
    return remaining
  end

  -- 실제 사용을 아직 보지 못한 파티원은, 차단 기술을 가진 직업으로 확인된 경우 준비 상태로 본다.
  if entry.spellID and entry.cooldown then return 0 end
  return nil
end

local function participantAvailable(order,castWindow)
  local remaining=participantCooldownRemaining(order)
  if remaining==nil then return nil end
  if remaining<=.05 then return true end
  if castWindow and remaining<=castWindow+.05 then return true end
  return false
end

local function firstAvailableOrder(rule,castWindow)
  local size=currentRotationSize(rule)
  local expected=interruptState.expectedOrder or interruptState.currentOrder or 1
  for offset=0,size-1 do
    local order=((expected-1+offset)%size)+1
    local available=participantAvailable(order,castWindow)
    if available==true then return order end
    -- 앞 순번의 상태를 알 수 없으면 뒤 사람에게 섣불리 백업 소리를 내지 않는다.
    if available==nil then return nil,"unknown" end
  end
  return nil,"none"
end

local function orderForUnit(unit,rule)
  if not unit then return nil end
  local size=currentRotationSize(rule)
  for order=1,size do
    if rotationRoster[order] and rotationRoster[order].unit==unit then return order end
  end
  return nil
end

local function nextOrder(order,rule)
  local size=currentRotationSize(rule)
  local value=(tonumber(order) or 1)+1
  if value>size then value=1 end
  return value
end

local function normalizeInterruptUnit(unit)
  unit=safeText(unit)
  if not unit then return nil end
  if unit=="pet" then return "player" end
  local partyIndex=unit:match("^partypet(%d+)$")
  if partyIndex then return "party"..partyIndex end
  local raidIndex=unit:match("^raidpet(%d+)$")
  if raidIndex then return "raid"..raidIndex end
  if unit=="player" or unit:match("^party%d+$") or unit:match("^raid%d+$") then return unit end
  return nil
end

local function recordInterruptUse(unit,spellID)
  local profile=INTERRUPT_SPELLS[spellID]
  unit=normalizeInterruptUnit(unit)
  if not profile or not unit or not UnitExists(unit) then return false end
  local t=now()
  local cooldown=profile.cd or 15
  partyKickState[unit]={spellID=spellID,cooldown=cooldown,lastUsed=t,readyAt=t+cooldown}
  recentInterrupts[unit]={time=t,spellID=spellID}
  if type(RDE.InterruptTrackerOnInterruptUse)=="function" then
    pcall(RDE.InterruptTrackerOnInterruptUse,unit,spellID,cooldown,t)
  end
  for _,entry in pairs(rotationRoster) do
    if entry.unit==unit then
      entry.spellID=spellID
      entry.cooldown=cooldown
      entry.classFile=entry.classFile or profile.classFile
    end
  end
  if db and db.debug then
    P("차단 사용 감지: "..unit.." · "..tostring(profile.name or spellID).." · "..cooldown.."초")
  end
  return true
end

local function recentInterrupterUnit()
  local t=now()
  local bestUnit,bestDelta
  for unit,data in pairs(recentInterrupts) do
    if type(data)=="table" and data.time then
      local delta=t-data.time
      if delta>=-.08 and delta<=.7 and (not bestDelta or delta<bestDelta) then
        bestUnit,bestDelta=unit,delta
      end
    end
  end
  return bestUnit
end

local function tokenFromInterruptedBy(interruptedBy)
  if interruptedBy==nil then return nil end
  if UnitTokenFromGUID then
    local ok,unit=pcall(UnitTokenFromGUID,interruptedBy)
    unit=ok and normalizeInterruptUnit(unit) or nil
    if unit then return unit end
  end

  -- UnitTokenFromGUID가 파티원을 돌려주지 않는 경우, 직업이 로테이션 안에서 유일할 때만 제한적으로 복원한다.
  if UnitClassFromGUID then
    local ok,_,classFile=pcall(UnitClassFromGUID,interruptedBy)
    classFile=ok and safeText(classFile) or nil
    if classFile then
      local matched=nil
      for _,entry in pairs(rotationRoster) do
        if entry.unit and entry.classFile==classFile then
          if matched and matched~=entry.unit then return nil end
          matched=entry.unit
        end
      end
      return matched
    end
  end
  return nil
end

local function resolveActualInterrupter(interruptedBy)
  -- interruptedBy가 안전하게 unit으로 복원되면 그것을 우선한다.
  -- 같은 순간 두 명이 발차기를 눌렀을 때 단순히 가장 최근 SUCCEEDED만 고르면 실제 차단자를 뒤바꿀 수 있다.
  return tokenFromInterruptedBy(interruptedBy) or recentInterrupterUnit()
end

local function setCurrentOrder(value,reason)
  interruptState.currentOrder=tonumber(value) or 1
  if db.debug then P("다음 차단 순번: "..interruptState.currentOrder..(reason and (" · "..reason) or "")) end
  
end

local function updateOrderAfterCast(interrupted,eventName,interruptedBy)
  local rule=interruptState.activeRule or baseInterruptRule()
  if not rule.rotationEnabled then return end
  local expected=interruptState.expectedOrder or interruptState.currentOrder or 1
  local actualUnit=interrupted and resolveActualInterrupter(interruptedBy) or nil
  local actualOrder=actualUnit and orderForUnit(actualUnit,rule) or nil

  if actualOrder then
    local entry=rotationRoster[actualOrder]
    if actualUnit~="player" and entry and entry.cooldown and not (partyKickState[actualUnit] and partyKickState[actualUnit].lastUsed and now()-partyKickState[actualUnit].lastUsed<1) then
      partyKickState[actualUnit]={spellID=entry.spellID,cooldown=entry.cooldown,lastUsed=now(),readyAt=now()+entry.cooldown}
    end
    if actualOrder~=expected then
      MS.adaptivePack=true
      setCurrentOrder(nextOrder(actualOrder,rule),"실제 "..actualOrder.."순번 차단으로 적응")
    else
      setCurrentOrder(nextOrder(expected,rule),"정상 차단")
    end
  elseif interrupted and actualUnit then
    -- 로테이션 외 인원이 차단했다면 원래 담당자의 차단은 사용되지 않았으므로 순서를 유지한다.
    MS.adaptivePack=true
    setCurrentOrder(expected,"외부 차단 · 원래 순번 유지")
  elseif interrupted then
    -- UNIT_SPELLCAST_INTERRUPTED는 실제 차단을 뜻하지만 차단자를 식별하지 못한 경우
    -- 잘못된 순번 이동보다 현재 순번 유지가 안전하다.
    setCurrentOrder(expected,"차단자 미확인 · 순번 유지")
  else
    -- STOP / CHANNEL_STOP / FAILED 등은 차단 사용을 보장하지 않는다.
    -- 스턴, 몹 사망, 자연 완료 때문에 로테이션이 넘어가지 않도록 반드시 현재 순번을 유지한다.
    setCurrentOrder(expected,(eventName or "시전 종료").." · 순번 유지")
  end
end

local function alertDecision(rule)
  if not rule.rotationEnabled then
    -- 단독/자유 주시에서는 내 차단기가 실제로 준비됐을 때만 소리를 낸다.
    -- 로테이션 모드는 아래 기존 규칙(내 정식 순번은 쿨과 무관하게 알림)을 그대로 유지한다.
    local remaining=playerKickRemaining()
    if remaining==nil then return false,false,"solo-cooldown-unknown" end
    if remaining<=.05 then return true,false,"solo-ready" end
    return false,false,"solo-cooldown"
  end
  local expected=interruptState.expectedOrder or interruptState.currentOrder or 1
  local myOrder=interruptState.myOrder or currentInterruptOrder(rule)

  -- 내 정식 순서는 현재 발차기 쿨과 무관하게 항상 알린다.
  if expected==myOrder then return true,false,"assigned" end

  local castWindow=focusCastRemaining()
  interruptState.castWindow=castWindow
  local availableOrder,why=firstAvailableOrder(rule,castWindow)
  if availableOrder==myOrder then return true,true,"backup" end
  return false,false,why or "rotation"
end

local function scheduleCooldownRechecks(rule)
  local serial=interruptState.serial
  if not rule.rotationEnabled then
    -- 시전 시작 때 발차기가 쿨이어도, 시전 도중 쿨이 돌아오면 그 순간 다시 판단한다.
    local remaining=playerKickRemaining()
    if remaining and remaining>.05 and remaining<30 then
      C_Timer.After(math.max(.05,remaining+.03),function()
        if not db or not db.interruptEnabled then return end
        if serial~=interruptState.serial or not interruptState.active then return end
        if RDE.ReevaluateActiveInterrupt then RDE.ReevaluateActiveInterrupt("내 차단 쿨 회복") end
      end)
    end
    return
  end
  local size=currentRotationSize(rule)
  local scheduled={}
  for order=1,size do
    local remaining=participantCooldownRemaining(order)
    if remaining and remaining>.05 and remaining<30 then
      local bucket=math.floor(remaining*20+.5)
      if not scheduled[bucket] then
        scheduled[bucket]=true
        C_Timer.After(math.max(.05,remaining+.03),function()
          if not db or not db.interruptEnabled then return end
          if serial~=interruptState.serial or not interruptState.active then return end
          if RDE.ReevaluateActiveInterrupt then RDE.ReevaluateActiveInterrupt("차단 쿨 회복") end
        end)
      end
    end
  end
end

local function evaluateFocusInterruptCast(playAlert,reason)
  if not activeMythicPlus() then return false end
  if not db.interruptEnabled or not interruptState.active then return false end
  if not playerInterruptSpellID() then
    if db.debug then P("현재 전문화에서 사용할 수 있는 차단기를 확인하지 못해 차단 알림을 건너뜁니다.") end
    return false
  end
  interruptState.evaluated=true

  -- 공개 UNIT_SPELLCAST_INTERRUPTIBLE / NOT_INTERRUPTIBLE 이벤트만 차단 가능 여부에 사용한다.
  if interruptState.interruptible==false then
    interruptState.counted=false
    if db.debug then P("주시 시전은 차단 불가 이벤트로 확인되어 건너뜁니다.") end
    return false
  end

  local rule=interruptState.activeRule or baseInterruptRule()
  interruptState.counted=true
  local rotationEnabled=rule.rotationEnabled and true or false
  local size=currentRotationSize(rule)
  local current=interruptState.expectedOrder or interruptState.currentOrder or 1
  local myOrder=interruptState.myOrder or currentInterruptOrder(rule)
  local shouldAlert,backup,decision=alertDecision(rule)
  local markerLabel=(rule.source=="unmarked") and "무징표" or (MARKER_NAMES[rule.marker] or "징표")
  local detail
  if rule.source=="override" then
    detail=markerLabel.." · 조건부 단독 차단"
  elseif rule.source=="unmarked" then
    detail="무징표 주시 · 전담 차단"
  elseif rule.source=="free" then
    detail="자유 주시 · 단독 차단"
  elseif backup then
    detail=markerLabel.." · 백업 차단 · 원래 "..current.."순번"
  elseif rotationEnabled then
    detail=markerLabel.." · "..size.."인 로테 · "..current.."순번"
  else
    detail=markerLabel.." · 단독 차단"
  end

  if playAlert and shouldAlert and not interruptState.alertPlayed then
    interruptState.alertPlayed=true
    interruptState.backup=backup and true or false
    local fake={action="FEINT",name=detail}
    show(fake,{timerKnown=false},"차단",db.ttsText or "차단",spellTexture(playerInterruptSpellID() or 1766),"INTERRUPT")
    if db.debug then P("차단 알림 실행: "..detail.." · 판단="..tostring(decision)) end
  elseif playAlert and db.debug and not interruptState.alertPlayed then
    local debugKey=table.concat({tostring(current),tostring(myOrder),tostring(decision)},"|")
    if interruptState.lastDebugDecision~=debugKey then
      interruptState.lastDebugDecision=debugKey
      P("차단 알림 보류: 현재 "..current.."순번 / 내 순서 "..myOrder.." · 판단="..tostring(decision))
    end
  end

  refreshImportantCastVisuals()
  return shouldAlert
end

function RDE.ReevaluateActiveInterrupt(reason)
  if not interruptState.active or interruptState.alertPlayed then return end
  evaluateFocusInterruptCast(true,reason or "재평가")
end

local function focusCastBarIDSafe(value)
  local id=safeNum(value)
  if id then return id end
  local function read(fn)
    if type(fn)~="function" then return nil end
    local ok,a,b,c,d,e,f,g,h,i,j=pcall(fn,"focus")
    if not ok then return nil end
    return safeNum(j)
  end
  return read(UnitCastingInfo) or read(UnitChannelInfo)
end

local function castBarMatchesActive(castBarID)
  local incoming=focusCastBarIDSafe(castBarID)
  local activeID=safeNum(interruptState.castBarID)
  if incoming and activeID and incoming~=activeID then
    if db and db.debug then P("이전 시전 종료 이벤트 무시 · castBarID "..incoming.." / 현재 "..activeID) end
    return false
  end
  return true
end

local function finishFocusInterruptCast(interrupted,eventName,interruptedBy,castBarID)
  if not interruptState.active then return end
  if not castBarMatchesActive(castBarID) then return end
  updateOrderAfterCast(interrupted and true or false,eventName,interruptedBy)
  clearActiveInterruptCast()
end

local function queueInterruptedFinish(eventName,interruptedBy,castBarID)
  if not interruptState.active or interruptState.pendingInterrupt then return end
  if not castBarMatchesActive(castBarID) then return end
  interruptState.pendingInterrupt=true
  local serial=interruptState.serial
  C_Timer.After(.06,function()
    if serial~=interruptState.serial or not interruptState.active then return end
    finishFocusInterruptCast(true,eventName,interruptedBy,castBarID)
  end)
end

local function queueNaturalFinish(eventName,castBarID)
  if not interruptState.active or interruptState.pendingStop then return end
  if not castBarMatchesActive(castBarID) then return end
  interruptState.pendingStop=true
  local serial=interruptState.serial
  C_Timer.After(.06,function()
    if serial~=interruptState.serial or not interruptState.active then return end
    if interruptState.pendingInterrupt then return end
    finishFocusInterruptCast(false,eventName,nil,castBarID)
  end)
end

local function beginFocusInterruptCast(eventName,castBarID)
  if not activeMythicPlus() then
    clearActiveInterruptCast()
    return
  end
  if not db or not db.interruptEnabled or not UnitExists("focus") then return end

  local rule,focusMarker,markerState=resolveInterruptRuleForFocus()
  if not rule then
    if db.debug then
      P("주시 징표가 담당 징표와 달라 시전을 무시합니다: "..tostring(MARKER_NAMES[focusMarker] or markerState or "없음"))
    end
    return
  end

  local t=now()
  local incomingCastBarID=focusCastBarIDSafe(castBarID)
  if interruptState.active then
    local activeCastBarID=safeNum(interruptState.castBarID)
    if incomingCastBarID and activeCastBarID and incomingCastBarID==activeCastBarID then
      if db.debug then P("같은 castBarID START 중복 무시 · "..incomingCastBarID) end
      return
    end
    local elapsed=t-(interruptState.lastStart or 0)
    if elapsed<.35 then
      if db.debug then P("중복 시전 시작 무시: "..tostring(eventName or "START")) end
      return
    end
    clearActiveInterruptCast()
  end

  if rule.rotationEnabled and not next(rotationRoster) then rebuildRotationRoster() end

  interruptState.serial=interruptState.serial+1
  local serial=interruptState.serial
  interruptState.active=true
  interruptState.counted=false
  interruptState.evaluated=false
  interruptState.interruptible=nil
  interruptState.lastStart=t
  interruptState.activeRule=rule
  interruptState.expectedOrder=interruptState.currentOrder or 1
  interruptState.myOrder=currentInterruptOrder(rule)
  interruptState.alertPlayed=false
  interruptState.backup=false
  interruptState.pendingInterrupt=false
  interruptState.pendingStop=false
  interruptState.castWindow=focusCastRemaining()
  interruptState.castBarID=incomingCastBarID
  refreshImportantCastVisuals()

  if db.debug then
    local markerLabel=(rule.source=="unmarked") and "무징표" or (MARKER_NAMES[rule.marker] or "징표")
    local mode=rule.rotationEnabled and (currentRotationSize(rule).."인 "..currentInterruptOrder(rule).."차단 · 현재"..(interruptState.currentOrder or 1)) or ((rule.source=="override" and "조건부 " or rule.source=="unmarked" and "전담 " or "").."단독")
    P("주시 시전 시작: "..tostring(eventName or "START").." · 설정="..markerLabel.." "..mode.." · 징표판정="..tostring(markerState)..(interruptState.castBarID and (" · castBarID="..interruptState.castBarID) or "")..(MS.adaptivePack and " · 적응형" or ""))
  end

  -- 공개 INTERRUPTIBLE/NOT_INTERRUPTIBLE 이벤트가 도착할 시간을 조금 기다린다.
  C_Timer.After(.15,function()
    if not db or not db.interruptEnabled then return end
    if serial~=interruptState.serial or not interruptState.active then return end
    evaluateFocusInterruptCast(true,"시전 시작")
    scheduleCooldownRechecks(rule)
  end)
end

function RDE.ApplyBriefingAssignment(result)
  if not db or type(result)~="table" then return false end
  db.freeFocusSolo=false
  local sender=tostring(result.sender or "")
  local automatic=sender~="" and sender~="수동" and sender~="테스트"
  if automatic then
    saveBriefingBaseState()
  elseif db.briefingAutoActive then
    -- 사용자가 수동 문장을 적용하면 현재 내용을 새 수동 기준으로 삼는다.
    clearBriefingAssignment(true)
  end
  local changed=false
  if type(result.base)=="table" then
    local base=result.base
    local marker=tonumber(base.marker)
    local size=tonumber(base.size) or 1
    local order=tonumber(base.order) or 1
    if marker and marker>=1 and marker<=8 then
      db.interruptMarker=marker
      db.interruptEnabled=true
      if size<=1 then
        db.rotationEnabled=false
        db.interruptSize=2
        db.interruptOrder=1
      elseif size==2 or size==3 then
        db.rotationEnabled=true
        db.interruptSize=size
        db.interruptOrder=math.max(1,math.min(size,order))
      else
        return false,"unsupported-size"
      end
      db.briefingParticipants=type(base.participants)=="table" and base.participants or {}
      db.briefingAssignmentActive=true
      changed=true
    end
  end
  if type(result.override)=="table" then
    local marker=tonumber(result.override.marker)
    if marker and marker>=1 and marker<=8 then
      db.briefingOverrideEnabled=true
      db.briefingOverrideMarker=marker
      db.briefingAssignmentActive=true
      changed=true
    end
  end
  if result.unmarkedSolo==true then
    db.briefingUnmarkedSoloEnabled=true
    db.briefingAssignmentActive=true
    changed=true
  elseif result.unmarkedSolo==false then
    db.briefingUnmarkedSoloEnabled=false
    changed=true
  end
  if result.clearOverride then
    db.briefingOverrideEnabled=false
    db.briefingOverrideMarker=0
    changed=true
  end
  if changed then
    db.briefingLastText=tostring(result.sourceText or "")
    db.briefingLastSender=tostring(result.sender or "")
    rebuildRotationRoster()
    resetInterruptState(true)
    
    ensureFocusMarkerMacro(true)
    local baseText=db.rotationEnabled and (MARKER_NAMES[db.interruptMarker].." "..currentRotationSize().."인"..briefingParticipantsInline(db.briefingParticipants).." · 나는 "..currentInterruptOrder().."차") or (MARKER_NAMES[db.interruptMarker].." 단독")
    local overrideText=db.briefingOverrideEnabled and (" · "..MARKER_NAMES[db.briefingOverrideMarker].." 조건부 단독") or ""
    local unmarkedText=db.briefingUnmarkedSoloEnabled and " · 무징표 주시 전담" or ""
    P("브리핑 자동 적용 · "..baseText..overrideText..unmarkedText)
    return true
  end
  if automatic and db.briefingAutoActive then clearBriefingAssignment(false) end
  return false
end

function RDE.ClearBriefingAssignment(keepBase)
  clearBriefingAssignment(keepBase and true or false)
end

function RDE.ClearAutoBriefingAssignment(reason)
  if not db or not db.briefingAutoActive then return false end
  clearBriefingAssignment(false)
  if db.debug and reason then P("자동 브리핑 종료 · 수동 설정 복원 · "..tostring(reason)) end
  return true
end

-- 새 쐐기 세션에 브리핑/수동 배정이 하나도 없을 때 이전 세션의 로테이션을 들고 오지 않는다.
-- 차단 알림 자체는 유지하되, 자유 주시 단독차단 상태로 시작한다.
function RDE.ResetUnassignedInterruptSession(reason)
  if not db then return false end
  if db.briefingAutoActive then restoreBriefingBaseState() end
  db.briefingAutoActive=false
  db.briefingSavedState=nil
  db.briefingAssignmentActive=false
  db.briefingOverrideEnabled=false
  db.briefingOverrideMarker=0
  db.briefingUnmarkedSoloEnabled=false
  db.briefingParticipants={}
  db.briefingLastText=""
  db.briefingLastSender=""
  db.freeFocusSolo=true
  db.rotationEnabled=false
  wipe(rotationRoster)
  MS.adaptivePack=false
  resetInterruptState(true)
  ensureFocusMarkerMacro(true)
  
  if db.debug and reason then P("브리핑 없는 새 쐐기 · 자유 주시 단독으로 초기화 · "..tostring(reason)) end
  return true
end

function RDE.ActivateManualBriefingBase()
  if not db then return false end
  db.freeFocusSolo=false
  if RDE.MarkBriefingSessionConfigured then RDE.MarkBriefingSessionConfigured("manual") end
  db.briefingAutoActive=false
  db.briefingSavedState=nil
  db.briefingAssignmentActive=true
  db.briefingParticipants=type(db.briefingParticipants)=="table" and db.briefingParticipants or {}
  db.briefingLastSender="수동"
  rebuildRotationRoster()
  resetInterruptState(true)
  
  return true
end

function RDE.SetBriefingOverrideMarker(marker)
  if not db then return false end
  if RDE.MarkBriefingSessionConfigured then RDE.MarkBriefingSessionConfigured("manual-override") end
  db.briefingAutoActive=false
  db.briefingSavedState=nil
  marker=tonumber(marker) or 0
  if marker>=1 and marker<=8 then
    db.briefingOverrideEnabled=true
    db.briefingOverrideMarker=marker
    db.briefingAssignmentActive=true
    db.briefingLastSender="수동"
    rebuildRotationRoster()
    resetInterruptState(true)
    
    P("조건부 단독 징표 수동 설정 · "..(MARKER_NAMES[marker] or marker))
    return true
  end
  db.briefingOverrideEnabled=false
  db.briefingOverrideMarker=0
  resetInterruptState(true)
  
  P("조건부 단독 징표 사용 안 함")
  return true
end


local function briefingParticipantText()
  return briefingParticipantsInline(db and db.briefingParticipants)
end

function RDE.GetBriefingSummary()
  if not db then return "초기화 전" end
  local base=db.rotationEnabled and (MARKER_NAMES[db.interruptMarker].." "..currentRotationSize().."인 "..currentInterruptOrder().."차단"..briefingParticipantText()) or (MARKER_NAMES[db.interruptMarker].." 단독")
  local override=db.briefingOverrideEnabled and (" / "..MARKER_NAMES[db.briefingOverrideMarker].." 조건부 단독") or ""
  local unmarked=db.briefingUnmarkedSoloEnabled and " / 무징표 주시 전담" or ""
  return base..override..unmarked
end

local function getMDTMarkerHint()
  if not UnitFullName then return nil end
  local mdt=_G.MDT
  if type(mdt)~="table" or type(mdt.FocusMarker_GetAssignments)~="function" then return nil end
  local ok,assignments=pcall(mdt.FocusMarker_GetAssignments,mdt)
  if not ok or type(assignments)~="table" then return nil end

  local okName,name,realm=pcall(UnitFullName,"player")
  name=okName and safeText(name) or nil
  realm=okName and safeText(realm) or nil
  if not name then return nil end
  local full=(realm and realm~="") and (name.."-"..realm) or name
  local marker=safeNum(assignments[full])
  if not marker and (not realm or realm=="") then marker=safeNum(assignments[name]) end
  if marker and marker>=1 and marker<=8 then return marker end
  return nil
end


function RDE.GetKickStateSummary()
  if not db then return "초기화 전" end
  if db.rotationEnabled and not next(rotationRoster) then rebuildRotationRoster() end
  local parts={}
  local size=db.rotationEnabled and currentRotationSize() or 1
  for order=1,size do
    local entry=rotationRoster[order]
    local token=entry and entry.token or (order.."순번")
    local unit=entry and entry.unit or "미확인"
    local remaining=participantCooldownRemaining(order)
    local cdText=remaining==nil and "?" or (remaining<=.05 and "준비" or string.format("%.1f초",remaining))
    parts[#parts+1]=order..":"..tostring(token).."("..tostring(unit)..","..cdText..")"
  end
  local mdtMarker=getMDTMarkerHint()
  local mdtText=mdtMarker and (" · MDT참고 "..(MARKER_NAMES[mdtMarker] or tostring(mdtMarker))) or ""
  return "현재 "..(interruptState.currentOrder or 1).."순번 · "..(MS.adaptivePack and "적응형" or "기본").." · "..table.concat(parts," / ")..mdtText
end


local interruptEventFrame=_G.NiniTools.EventDispatcher:CreateProxy("Kick.Interrupt")
interruptEventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
interruptEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
interruptEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
interruptEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
interruptEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
interruptEventFrame:RegisterEvent("RAID_TARGET_UPDATE")
interruptEventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE","focus")
interruptEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE","focus")

-- 2.0.6: UNIT_SPELLCAST_SUCCEEDED is a very busy global event.
-- NiniKick only needs it to track party interrupt cooldowns inside an active M+.
-- Keep the listener completely unregistered everywhere else.
RDE.UpdateKickSucceededEventRegistration=function(forceOff)
  if not interruptEventFrame then return end
  local shouldListen=(forceOff~=true) and activeMythicPlus()
  if shouldListen then
    if not interruptEventFrame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
      interruptEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
  elseif interruptEventFrame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
    interruptEventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  end
end

interruptEventFrame:SetScript("OnEvent",function(_,event,unit,castGUID,spellID,arg4,arg5)
  local interruptedBy,castBarID
  if event=="UNIT_SPELLCAST_INTERRUPTED" or event=="UNIT_SPELLCAST_CHANNEL_STOP" then
    interruptedBy=arg4
    castBarID=arg5
  else
    castBarID=arg4
  end
  if event=="PLAYER_ENTERING_WORLD" then
    wipe(partyKickState)
    wipe(recentInterrupts)
    wipe(rotationRoster)
    resetInterruptState(true)
    RDE.UpdatePartyGreetingState(RDE._partyGreetingInitialized~=true)
    RDE.UpdateKickSucceededEventRegistration()
    C_Timer.After(.5,function() rebuildRotationRoster(); RDE.UpdateKickSucceededEventRegistration() end)
    if db and db.debug then P("화면 전환 · 차단 상태 초기화") end
    return
  elseif event=="PLAYER_REGEN_ENABLED" then
    resetInterruptState(true)
    if db and db.debug then P("전투 종료 · 기본 로테이션 1순번으로 복귀") end
    return
  elseif event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_SPECIALIZATION_CHANGED" then
    if event=="GROUP_ROSTER_UPDATE" then RDE.UpdatePartyGreetingState(false) end
    C_Timer.After(.2,rebuildRotationRoster)
    return
  elseif event=="PLAYER_FOCUS_CHANGED" then
    MS.lastKnownFocusMarker=nil
    readFocusMarker()
    clearActiveInterruptCast()
    if db and db.debug then P("주시 변경 · 현재순번 유지 "..(interruptState.currentOrder or 1)) end
    return
  elseif event=="RAID_TARGET_UPDATE" then
    readFocusMarker()
    return
  elseif event=="SPELL_UPDATE_COOLDOWN" then
    if interruptState.active and not interruptState.alertPlayed then evaluateFocusInterruptCast(true,"내 차단 쿨 갱신") end
    return
  elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
    if not activeMythicPlus() then return end
    -- RegisterUnitEvent only accepts up to four unit tokens.  Previous builds
    -- passed the whole party+pet list in one call, so party kick events were
    -- not reliably registered.  Listen globally and immediately discard any
    -- unit that is not the player/party (or their pet) before touching spellID.
    local kickUnit=normalizeInterruptUnit(unit)
    if not kickUnit or (kickUnit~="player" and not kickUnit:match("^party[1-4]$")) then return end
    local sid=safeNum(spellID)
    if sid and recordInterruptUse(kickUnit,sid) and interruptState.active and not interruptState.alertPlayed then
      evaluateFocusInterruptCast(true,"파티 차단 쿨 갱신")
    end
    return
  end

  -- 차단 판단/음성은 활성 Mythic+에서만 사용한다. 레이드/일반 던전에서는 주시 시전을 완전히 무시한다.
  if not activeMythicPlus() then
    clearActiveInterruptCast()
    return
  end

  -- castGUID/spellID는 비교·저장·출력하지 않는다. 공개 castBarID만 같은 시전의 START/STOP/INTERRUPTED 결합에 사용하고, interruptedBy는 unit token 복원에만 제한적으로 사용한다.
  if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_CHANNEL_START" then
    beginFocusInterruptCast(event,castBarID)
  elseif event=="UNIT_SPELLCAST_INTERRUPTIBLE" then
    if interruptState.active then interruptState.interruptible=true end
  elseif event=="UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
    if interruptState.active then interruptState.interruptible=false end
  elseif event=="UNIT_SPELLCAST_INTERRUPTED" then
    queueInterruptedFinish(event,interruptedBy,castBarID)
  elseif event=="UNIT_SPELLCAST_CHANNEL_STOP" then
    if interruptedBy~=nil then queueInterruptedFinish(event,interruptedBy,castBarID)
    else queueNaturalFinish(event,castBarID) end
  elseif event=="UNIT_SPELLCAST_STOP" then
    queueNaturalFinish(event,castBarID)
  elseif event=="UNIT_SPELLCAST_FAILED" then
    clearActiveInterruptCast()
  end
end)










local function runPreviewCycle()
  show({action="FEINT",name="차단 테스트"},{totalDuration=2},"차단",db.ttsText or "차단",spellTexture(playerInterruptSpellID() or 1766),"INTERRUPT")
end

function RDE.PutCommandInChat(command)
  command=tostring(command or "")
  if command=="" then return end
  if type(ChatFrame_OpenChat)=="function" then
    ChatFrame_OpenChat(command)
  else
    P("채팅 입력창을 열 수 없습니다. 복사 버튼을 사용하세요: "..command)
  end
end

local function openSettings()
  -- 2.0.22: 구형 /nk advanced 호출도 통합 차단 탭으로 라우팅한다.
  if _G.NiniTools and type(_G.NiniTools.ToggleUI)=="function" then
    _G.NiniTools:ToggleUI("KICK")
    return
  end
  P("통합 차단 탭이 아직 준비되지 않았습니다.")
end

-- 2.0.20: 예전 니니차단 창의 설정을 니니툴즈 설정창에서 그대로 다룰 수 있게 노출한다.
-- 내부 적용 함수(applyAlertStyle 등)를 그대로 호출하므로 동작은 기존 창과 동일하다.
RDE.MARKER_NAMES=MARKER_NAMES

RDE.SetInterruptMarker=function(index)
  if not db then return false end
  index=tonumber(index)
  if not index or index<1 or index>8 then return false end

  -- Manual correction after an auto briefing should only change my assigned marker.
  -- Keep the parsed rotation size/order and participant roster intact.
  if db.briefingAssignmentActive then
    if RDE.MarkBriefingSessionConfigured then RDE.MarkBriefingSessionConfigured("manual-marker") end
    db.briefingAutoActive=false
    db.briefingSavedState=nil
    db.freeFocusSolo=false
    db.briefingLastSender="수동"
    db.interruptMarker=index
    rebuildRotationRoster()
    resetInterruptState(true)
  else
    clearBriefingAssignment(true)
    db.interruptMarker=index
    if RDE.ActivateManualBriefingBase then RDE.ActivateManualBriefingBase() end
  end
  ensureFocusMarkerMacro(true)
  return true
end

RDE.SetRotationSize=function(size)
  if not db then return false end
  size=tonumber(size)
  -- size=1 is the UI's explicit "없음" choice: one assigned target, no rotation.
  if size==1 then
    db.rotationEnabled=false
    db.interruptSize=2 -- keep a valid stored size for future 2/3-person re-enable
    db.interruptOrder=1
    return true
  end
  if size~=2 and size~=3 then return false end
  db.rotationEnabled=true
  db.interruptSize=size
  if (db.interruptOrder or 1)>size then db.interruptOrder=size end
  return true
end

RDE.SetInterruptOrder=function(order)
  if not db then return false end
  order=tonumber(order)
  if not order or order<1 or order>3 then return false end
  db.interruptOrder=order
  
  return true
end

-- ImportantCast.lua가 네임플레이트별 담당 강조에 사용하는 읽기 전용 상태.
-- focus가 아닌 nameplate에는 절대 담당 상태를 전달하지 않는다.
-- 중요 시전 여부 자체는 secret-safe ImportantCast 레이어가 처리하며 이 함수는 관여하지 않는다.
RDE.GetInterruptVisualState=function(unit)
  local marker=(db and db.interruptMarker) or 1
  if not db or type(unit)~="string" or type(UnitIsUnit)~="function" then
    return false,false,false,marker
  end
  local ok,same=pcall(UnitIsUnit,unit,"focus")
  if not ok or safeBool(same)~=true then
    return false,false,false,marker
  end
  if not activeMythicPlus() or not interruptState.active then
    return false,false,false,marker
  end

  local rule=interruptState.activeRule or baseInterruptRule()
  if not rule then return false,false,false,marker end
  marker=tonumber(rule.marker) or marker

  local backup=interruptState.backup and true or false
  local assigned=false
  if not backup then
    if not rule.rotationEnabled then
      assigned=true
    else
      local expected=interruptState.expectedOrder or interruptState.currentOrder or 1
      local myOrder=interruptState.myOrder or currentInterruptOrder(rule)
      assigned=(expected==myOrder)
    end
  end
  return true,assigned,backup,marker
end

RDE.GetInterruptConfig=function()
  if not db then return nil end
  return {
    marker=db.interruptMarker or 1,
    markerName=MARKER_NAMES[db.interruptMarker or 1] or "?",
    size=db.interruptSize or 2,
    order=db.interruptOrder or 1,
    rotationEnabled=db.rotationEnabled and true or false,
    briefingActive=db.briefingAssignmentActive and true or false,
  }
end



-- 크기/간격 조절. step 은 +1 / -1 방향.
local SIZE_SPEC={
  icon   ={key="iconSize",            default=40, lo=24, hi=80, step=2,   apply="alert"},
  timer  ={key="timerTextSize",       default=18, lo=10, hi=36, step=1,   apply="alert"},
  combat ={key="combatTimerTextSize", default=24, lo=12, hi=48, step=1,   apply="combat"},
  text   ={key="alertTextSize",       default=18, lo=10, hi=36, step=1,   apply="alert"},
  gap    ={key="textGap",             default=8,  lo=0,  hi=24, step=1,   apply="alert"},
  scale  ={key="scale",               default=1,  lo=.70,hi=2.0,step=.05, apply="scale"},
}

RDE.AdjustAlertSize=function(name, direction)
  if not db then return nil end
  local spec=SIZE_SPEC[name]
  direction=tonumber(direction)
  if not spec or not direction or direction==0 then return nil end
  local current=db[spec.key] or spec.default
  local value=clamp(current + (direction>0 and spec.step or -spec.step), spec.lo, spec.hi)
  db[spec.key]=value
  if spec.apply=="alert" then applyAlertStyle()
  elseif spec.apply=="combat" then refreshCombatTimerStyle()
  elseif spec.apply=="scale" then alert:SetScale(value) end
  
  return value
end

RDE.SetDisplayOption=function(key, value)
  if not db then return false end
  if key=="alertIconEnabled" or key=="alertTextEnabled" then
    db[key]=value and true or false
    applyAlertStyle()
    
    return true
  elseif key=="simpleShowMechanic" then
    db.simpleShowMechanic=value and true or false
    applyAlertStyle()
  elseif key=="importantCastMarkerEnabled" then
    db.importantCastMarkerEnabled=value and true or false
    if RDE.ImportantCastRefreshAll then pcall(RDE.ImportantCastRefreshAll) end
  else
    return false
  end
  
  return true
end


SLASH_NINIKICK1="/nk"
SLASH_NINIKICK2="/rd"
SLASH_NINIKICK3="/rdef"
SlashCmdList.NINIKICK=function(input)
  local c,a=tostring(input or ""):match("^%s*(%S*)%s*(.-)%s*$"); c=(c or ""):lower(); a=(a or ""):lower()
  -- 2.0.22: 모든 설정은 니니툴즈 차단 & 쐐기 탭에서 관리한다.
  -- 이전 명령어(advanced/old/window)는 호환을 위해 같은 통합 탭으로 보낸다.
  if c=="config" or c=="" then
    if _G.NiniTools and type(_G.NiniTools.ToggleUI)=="function" then
      _G.NiniTools:ToggleUI("KICK")
    else
      openSettings()
    end
  elseif c=="advanced" or c=="old" or c=="window" then openSettings()
  elseif c=="test" then
    runPreviewCycle()
  elseif c=="unlock" then setUnlockState(true)
  elseif c=="lock" then setUnlockState(false)
  elseif c=="debug" then
    if a=="on" then
      db.debug=true
    elseif a=="off" then
      db.debug=false
    else
      db.debug=not db.debug
    end
    P("디버그 "..(db.debug and "켜짐" or "꺼짐"))
  elseif c=="briefing" then
    if RDE.HandleBriefingCommand then RDE.HandleBriefingCommand(a) else P("브리핑 모듈을 찾지 못했습니다.") end
  elseif c=="hide" then
    if alert._hideTimer and alert._hideTimer.Cancel then alert._hideTimer:Cancel(); alert._hideTimer=nil end
    alert.icon.cd:Clear(); alert._expires=nil; alert:Hide(); P("알림 숨김")
  elseif c=="reset" then resetInterruptState(true); P("차단 순번을 1번으로 초기화")
  elseif c=="version" then P(VERSION)
  elseif c=="overlays" then RDE.EnforceSpellActivationOverlays(); P("주문 경보 켜짐 · 투명도 0.65 적용")
  elseif c=="gfx" then RDE.ApplyNaowhGraphicsPreset()
  elseif c=="gfxcombat" then RDE.ApplyNaowhCombatPreset()
  elseif c=="gfxrestore" then RDE.RestoreGraphicsBackup()
  -- 2.5.5: /nk tracker · trackerreset · trackerdiag 제거 (추적바 모듈은 1.5.0부터 EXBoss가 담당, 함수 없음)
  elseif c=="kickstate" then P(RDE.GetKickStateSummary and RDE.GetKickStateSummary() or "차단 상태를 확인할 수 없습니다.")
  elseif c=="automacro" or c=="autokick" then
    local ok,why=RDE.UpdateAutoInterruptMacro(false)
    if not ok and why=="combat" then P("전투 종료 후 오토를 자동 갱신합니다.") end
    if ok then P("매크로 창의 개인 탭에서 오토를 기존 발차기 단축키에 배치하세요.") end
  elseif c=="focusmacro" or c=="markmacro" then
    local sub=(a or ""):lower():match("^%s*(.-)%s*$")
    local ok
    if sub=="migrate" or sub=="personal" then ok=migrateSharedFocusMacroToCharacter() else ok=ensureFocusMarkerMacro(false) end
    if ok then P("매크로 창의 개인 탭에서 "..tostring(MS.activeFocusMacroName or db.focusMacroName or FOCUS_MACRO_NAME).."를 기존 주시 단축키에 배치하세요.") end
  elseif c=="combattime" or c=="ct" then
    local sub=(a or ""):lower():match("^%s*(.-)%s*$")
    if sub=="on" then setCombatTimerEnabled(true)
    elseif sub=="off" then setCombatTimerEnabled(false)
    elseif sub=="move" then setCombatTimerUnlockState(not db.combatTimerUnlocked)
    elseif sub=="unlock" then setCombatTimerUnlockState(true)
    elseif sub=="lock" then setCombatTimerUnlockState(false)
    elseif sub=="reset" then resetCombatTimerPosition(); P("전투시간 위치 초기화")
    elseif sub=="test" then previewCombatTimer()
    elseif sub:match("^size%s+%d+$") then
      db.combatTimerTextSize=clamp(tonumber(sub:match("(%d+)$")) or 24,12,48)
      refreshCombatTimerStyle()
      P("전투시간 글자 크기 "..db.combatTimerTextSize.." px")
    else setCombatTimerEnabled(db.combatTimerEnabled==false) end
    
  elseif c=="status" then
    local interruptStatus
    if not db.interruptEnabled then interruptStatus="차단 알림 꺼짐"
    elseif db.rotationEnabled then interruptStatus=string.format("%s %d인 %d차단",MARKER_NAMES[db.interruptMarker],(db.interruptSize==3) and 3 or 2,db.interruptOrder)
    elseif db.freeFocusSolo then interruptStatus="자유 주시 단독 차단"
    else interruptStatus=MARKER_NAMES[db.interruptMarker].." 단독 차단" end
    P(string.format("v%s · %s · %s · 주시 직접감지 · 현재순번 %d · 차단음성 %s · 전투시간 %s · 단독=내 차단 준비시에만 · 브리핑 %s",VERSION,"차단 전용",interruptStatus,interruptState.currentOrder or 1,db.voiceMode,(db.combatTimerEnabled~=false and "ON" or "OFF"),(RDE.GetBriefingSummary and RDE.GetBriefingSummary() or "미설정")))
  else P("/nk · status, briefing, kickstate, focusmacro, automacro, combattime, version") end
end

-- 2.0.5: delayed Mythic+ completion greeting.
-- CHALLENGE_MODE_COMPLETED can fire before completion data has fully settled.
-- Follow the conservative retry pattern used by current Mythic+ addons:
-- wait 0.8s, verify completion level, retry every 0.35s (max 12), then send
-- 1.2s after confirmation. This makes the greeting land naturally after the run
-- instead of firing almost on top of the completion event.
-- 2.0.7: automatic hello when joining a fresh non-raid party.
-- Track any group membership so raid<->party conversion does not retrigger.
-- Reloading or zoning while already grouped also does not retrigger.
RDE.IsInAnyGroupSafe=function()
  if type(IsInGroup)=="function" then
    local ok,v=pcall(IsInGroup)
    if ok and v then return true end
  end
  if type(IsInRaid)=="function" then
    local ok,v=pcall(IsInRaid)
    if ok and v then return true end
  end
  return false
end

RDE.IsEligibleGreetingParty=function()
  if not RDE.IsInAnyGroupSafe() then return false end
  if type(IsInRaid)=="function" then
    local ok,v=pcall(IsInRaid)
    if ok and v then return false end
  end
  return true
end

RDE.UpdatePartyGreetingState=function(initializing)
  local inAnyGroup=RDE.IsInAnyGroupSafe()

  if initializing or RDE._partyGreetingInitialized~=true then
    RDE._partyGreetingInitialized=true
    RDE._partyGreetingWasInAnyGroup=inAnyGroup
    RDE._partyGreetingSerial=(tonumber(RDE._partyGreetingSerial) or 0)+1
    return
  end

  local wasInAnyGroup=RDE._partyGreetingWasInAnyGroup==true
  RDE._partyGreetingWasInAnyGroup=inAnyGroup

  if not inAnyGroup then
    RDE._partyGreetingSerial=(tonumber(RDE._partyGreetingSerial) or 0)+1
    return
  end

  -- Only solo -> party qualifies. A raid never gets the greeting.
  if wasInAnyGroup or not RDE.IsEligibleGreetingParty() then return end
  if not db or db.partyGreetingEnabled==false then return end

  RDE._partyGreetingSerial=(tonumber(RDE._partyGreetingSerial) or 0)+1
  local serial=RDE._partyGreetingSerial

  local function sendGreeting()
    if serial~=RDE._partyGreetingSerial then return end
    if not db or db.partyGreetingEnabled==false then return end
    if not RDE.IsEligibleGreetingParty() then return end

    local channel="PARTY"
    if type(IsInGroup)=="function" and LE_PARTY_CATEGORY_INSTANCE then
      local ok,v=pcall(IsInGroup,LE_PARTY_CATEGORY_INSTANCE)
      if ok and v then channel="INSTANCE_CHAT" end
    end
    if type(SendChatMessage)=="function" then
      pcall(SendChatMessage,"안녕하세요.",channel)
    end
  end

  if C_Timer and C_Timer.After then C_Timer.After(1.0,sendGreeting) else sendGreeting() end
end

RDE.GetChallengeCompletionInfoSafe=function()
  if not C_ChallengeMode then return nil end

  if type(C_ChallengeMode.GetChallengeCompletionInfo)=="function" then
    local ok,info=pcall(C_ChallengeMode.GetChallengeCompletionInfo)
    if ok and type(info)=="table" then return info end
  end

  if type(C_ChallengeMode.GetCompletionInfo)=="function" then
    local ok,mapID,level,timeMS,onTime,upgradeLevels,practiceRun=pcall(C_ChallengeMode.GetCompletionInfo)
    if ok then
      return {
        mapChallengeModeID=mapID,
        level=level,
        time=timeMS,
        onTime=onTime,
        keystoneUpgradeLevels=upgradeLevels,
        practiceRun=practiceRun,
      }
    end
  end
  return nil
end

RDE.ScheduleMythicPlusGoodbye=function()
  if not db or db.goodbyeEnabled==false or RDE._goodbyeSentForRun or RDE._goodbyePending then return false end

  RDE._goodbyePending=true
  RDE._goodbyeSerial=(tonumber(RDE._goodbyeSerial) or 0)+1
  local serial=RDE._goodbyeSerial
  local attempts=0

  local function finishSend()
    if serial~=RDE._goodbyeSerial then return end
    RDE._goodbyePending=false
    if not db or db.goodbyeEnabled==false or RDE._goodbyeSentForRun then return end

    local channel
    if type(IsInGroup)=="function" and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
      channel="INSTANCE_CHAT"
    elseif type(IsInGroup)=="function" and IsInGroup() then
      channel="PARTY"
    end

    -- Mark the run handled even if the party has already dissolved, so duplicate
    -- completion events cannot produce a late greeting in another group.
    RDE._goodbyeSentForRun=true
    if channel and type(SendChatMessage)=="function" then
      pcall(SendChatMessage,"수고하셨습니다.",channel)
    end
  end

  local function pollCompletion()
    if serial~=RDE._goodbyeSerial then return end
    if not db or db.goodbyeEnabled==false then
      RDE._goodbyePending=false
      return
    end

    attempts=attempts+1
    local info=RDE.GetChallengeCompletionInfoSafe()
    local level=type(info)=="table" and safeNum(info.level) or nil

    if level and level>0 then
      if C_Timer and C_Timer.After then C_Timer.After(1.2,finishSend) else finishSend() end
    elseif attempts>=12 then
      -- Fallback after roughly five seconds. Some UI/addon combinations can delay
      -- or suppress completion data, but the user still asked for one greeting.
      if C_Timer and C_Timer.After then C_Timer.After(.5,finishSend) else finishSend() end
    elseif C_Timer and C_Timer.After then
      C_Timer.After(.35,pollCompletion)
    else
      finishSend()
    end
  end

  if C_Timer and C_Timer.After then C_Timer.After(.8,pollCompletion) else pollCompletion() end
  return true
end

local ef=_G.NiniTools.EventDispatcher:CreateProxy("Kick.Core")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("CVAR_UPDATE")
ef:RegisterEvent("PLAYER_REGEN_DISABLED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("UPDATE_MACROS")
ef:RegisterEvent("UI_SCALE_CHANGED")
ef:RegisterEvent("CHALLENGE_MODE_START")
ef:RegisterEvent("CHALLENGE_MODE_COMPLETED")
ef:RegisterEvent("CHALLENGE_MODE_RESET")
ef:SetScript("OnEvent",function(_,ev,arg)
  if ev=="ADDON_LOADED" and arg==ADDON_NAME then
    if _G.NiniTools then _G.NiniTools:BindModuleDB() end
    local oldDB=type(RogueDefensivesDB)=="table" and RogueDefensivesDB or nil
    local oldBriefingStateVersion=oldDB and tonumber(oldDB.briefingStateVersion) or 0
    local oldBriefingSender=oldDB and tostring(oldDB.briefingLastSender or "") or ""
    local hadRotationSetting=oldDB and oldDB.rotationEnabled~=nil
    local oldInterruptFlag=oldDB and oldDB.interruptEnabled
    local oldIconSize=oldDB and (oldDB.iconSize or oldDB.simpleIconSize)
    local oldTextSize=oldDB and (oldDB.alertTextSize or oldDB.simpleTextSize)
    local oldTimerSize=oldDB and oldDB.timerTextSize
    local oldTextGap=oldDB and (oldDB.textGap or oldDB.simpleGap)
    RogueDefensivesDB=merge(RogueDefensivesDB,defaults); db=RogueDefensivesDB
    RDE.LoadCombatTimerSharedPosition()
    db.combatTimerUnlocked=false
    if type(db.briefingParticipants)~="table" then db.briefingParticipants={} end
    -- 1.5.0: 파티 차단 추적은 EXBoss를 기본 사용하므로 NiniKick 추적바를 한 번 기본 OFF로 전환한다.
    if db.trackerDefaultOff150~=true then
      db.interruptTracker=type(db.interruptTracker)=="table" and db.interruptTracker or {}
      db.interruptTracker.enabled=false
      db.trackerDefaultOff150=true
      RDE._trackerDisabled150=true
    end
    -- 0.6.6까지는 자동 브리핑이 실제 기본 설정을 덮어쓴 채 다음 쐐기까지 남을 수 있었다.
    -- 이전 버전의 파티원 자동 설정 흔적은 한 번만 안전한 기본값으로 정리한다.
    if oldBriefingStateVersion<1 then
      if oldBriefingSender~="" and oldBriefingSender~="수동" then
        db.interruptEnabled=defaults.interruptEnabled
        db.rotationEnabled=defaults.rotationEnabled
        db.interruptMarker=defaults.interruptMarker
        db.interruptOrder=defaults.interruptOrder
        db.interruptSize=defaults.interruptSize
        db.briefingAssignmentActive=false
        db.briefingOverrideEnabled=false
        db.briefingOverrideMarker=0
        db.briefingUnmarkedSoloEnabled=false
        db.briefingParticipants={}
        db.briefingLastText=""
        db.briefingLastSender=""
        RDE._briefingMigrationReset=true
      end
      db.briefingAutoActive=false
      db.briefingSavedState=nil
      db.briefingStateVersion=2
    end
    -- 0.5.3 이전 표시 설정을 NSRT 아이콘형 설정으로 이전한다.
    db.iconSize=oldIconSize or db.iconSize or 40
    db.alertTextSize=oldTextSize or db.alertTextSize or 18
    db.timerTextSize=oldTimerSize or db.timerTextSize or 18
    db.textGap=oldTextGap or db.textGap or 8
    db.displayStyle="ICON"
    -- 0.4.0h까지의 "차단 로테이션 사용" 체크는 실제로 전체 차단 알림을 껐습니다.
    -- 기존 사용자가 체크를 해제했다면 새 버전에서는 "단독 차단"으로 마이그레이션합니다.
    if not hadRotationSetting then
      db.rotationEnabled=(oldInterruptFlag~=false)
      db.interruptEnabled=true
    end
    if db.ttsText=="내 차단" then db.ttsText="차단" end

    -- 2.0.11: migrate the old Naowh/loose "차단" media selection to the
    -- NiniTools-owned copy. Other deliberately selected SharedMedia sounds
    -- are left untouched.
    if db.builtinKickMediaMigration2011~=true then
      local oldKey=tostring(db.soundKey or "")
      local plain=oldKey:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
      if oldKey=="" or plain=="Kick -Naowh" or plain=="Kick - Naowh" or plain=="차단" then
        db.soundKey=RDE.BUILTIN_KICK_SOUND_KEY
      end
      db.builtinKickMediaMigration2011=true
    end
    -- 2.0.28: 차단은 내장 Naowh Kick 고정. 과거 TTS/SharedMedia 선택값은 보존하되 사용하지 않는다.
    if db.fixedNaowhKick2028~=true then
      db.voiceMode="MEDIA"
      db.soundKey=RDE.BUILTIN_KICK_SOUND_KEY
      db.alertIconEnabled=false
      db.alertTextEnabled=false
      db.fixedNaowhKick2028=true
    end

    buildAlert(); buildCombatTimer(); if RogueDefensivesDB and RogueDefensivesDB.unlocked then C_Timer.After(0, showMoveAnchor) end
  elseif ev=="ADDON_LOADED" and arg=="Blizzard_MacroUI" then
    if C_Timer and C_Timer.After then C_Timer.After(0,hideMacroCharLimitText) else hideMacroCharLimitText() end
  elseif ev=="PLAYER_LOGIN" then
    local _,c=UnitClass("player"); isRogue=c=="ROGUE"
    hideMacroCharLimitText()
    C_Timer.After(1,function()
      registerTargetRules(); ensureFocusMarkerMacro(true); RDE.UpdateAutoInterruptMacro(true); scheduleFocusMacroEnsure(1.5); RDE.ScheduleAutoInterruptMacroEnsure(2.0); C_Timer.After(4,function() if db and db.focusMacroEnabled~=false then ensureFocusMarkerMacro(true) end; if db and db.autoInterruptMacroEnabled~=false then RDE.UpdateAutoInterruptMacro(true) end end); P("v"..VERSION.." 로드 · 차단/브리핑/포커스·오토/전투시간 · NiniTools 통합 메뉴 지원")
      if RDE._briefingMigrationReset then
        P("이전 파티의 자동 브리핑 설정을 정리했습니다.")
        RDE._briefingMigrationReset=nil
      end
    end)
  elseif ev=="CHALLENGE_MODE_START" then
    RDE._goodbyeSentForRun=false
    RDE._goodbyePending=false
    RDE._goodbyeSerial=(tonumber(RDE._goodbyeSerial) or 0)+1
    RDE.UpdateKickSucceededEventRegistration()
  elseif ev=="CHALLENGE_MODE_COMPLETED" then
    RDE.UpdateKickSucceededEventRegistration(true)
    RDE.ScheduleMythicPlusGoodbye()
  elseif ev=="CHALLENGE_MODE_RESET" then
    RDE.UpdateKickSucceededEventRegistration(true)
  elseif ev=="PLAYER_ENTERING_WORLD" then
    if C_Timer and C_Timer.After then
      C_Timer.After(.1,RDE.ApplyCombatTimerPosition)
      C_Timer.After(1.0,RDE.ApplyCombatTimerPosition)
    else
      RDE.ApplyCombatTimerPosition()
    end
    scheduleFocusMacroEnsure(.8)
    RDE.ScheduleAutoInterruptMacroEnsure(1.2)
    C_Timer.After(3,function() if db and db.focusMacroEnabled~=false then ensureFocusMarkerMacro(true) end; if db and db.autoInterruptMacroEnabled~=false then RDE.UpdateAutoInterruptMacro(true) end end)
    local _,c=UnitClass("player"); isRogue=c=="ROGUE"
    C_Timer.After(.2,rebuildRotationRoster)
    if C_Timer and C_Timer.After then C_Timer.After(.8,RDE.UpdateKickSucceededEventRegistration) else RDE.UpdateKickSucceededEventRegistration() end
  elseif ev=="UI_SCALE_CHANGED" then
    if C_Timer and C_Timer.After then C_Timer.After(.1,RDE.ApplyCombatTimerPosition) else RDE.ApplyCombatTimerPosition() end
  elseif ev=="UPDATE_MACROS" then
    hideMacroCharLimitText()
    if not InCombatLockdown or not InCombatLockdown() then scheduleFocusMacroEnsure(.2); RDE.ScheduleAutoInterruptMacroEnsure(.3) end
  elseif ev=="PLAYER_REGEN_DISABLED" then
    startCombatTimer()
  elseif ev=="PLAYER_REGEN_ENABLED" then
    stopCombatTimer()
    if MS.focusMacroUpdatePending then ensureFocusMarkerMacro(true) end
    if RDE._autoInterruptMacroUpdatePending then RDE.UpdateAutoInterruptMacro(true) end
  elseif ev=="ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
    local _,c=UnitClass("player"); isRogue=c=="ROGUE"
    scheduleFocusMacroEnsure(.3)
    RDE.ScheduleAutoInterruptMacroEnsure(.35)
    C_Timer.After(.2,rebuildRotationRoster)
  elseif ev=="PLAYER_SPECIALIZATION_CHANGED" then
    if arg==nil or arg=="player" then
      local _,c=UnitClass("player"); isRogue=c=="ROGUE"
        C_Timer.After(.2,rebuildRotationRoster)
    end
  elseif ev=="CVAR_UPDATE" then
    local cvar=safeText(arg)
    if cvar then
      cvar=cvar:lower()
      if cvar=="displayspellactivationoverlays" or cvar=="spellactivationoverlayopacity" then
        if C_Timer and C_Timer.After then C_Timer.After(0,RDE.EnforceSpellActivationOverlays) else RDE.EnforceSpellActivationOverlays() end
      end
    end
  end
end)
