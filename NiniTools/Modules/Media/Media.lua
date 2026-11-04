local ADDON_NAME = ...

local FLOOR_PATH = "Interface\\AddOns\\BigWigs\\Media\\Sounds\\spell_under_you.ogg"
local NINI_KICK_PATH = "Interface\\AddOns\\NiniTools\\Media\\Sounds\\Kick.ogg"
local NINI_OHNO_PATH = "Interface\\AddOns\\NiniTools\\Media\\Sounds\\OhNo.ogg"
local GTFO_HIGH = 1

local bridge = {
  hooked = false,
  applied = false,
  lastRefreshReason = "not-ready",
}

local function GetLSM()
  if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return nil end
  return LibStub("LibSharedMedia-3.0", true)
end

local function RegisterMedia()
  local LSM = GetLSM()
  if not LSM then return false end
  local SOUND = LSM.MediaType and LSM.MediaType.SOUND or "sound"
  LSM:Register(SOUND, "BigWigs: Spell on you",
    "Interface\\AddOns\\BigWigs\\Media\\Sounds\\spell_on_you.ogg")
  LSM:Register(SOUND, "뜌미 승리",
    "Interface\\AddOns\\NiniTools\\Media\\Victory\\Victory.ogg")

  -- 2.0.11: keep the two personal sounds inside NiniTools itself.
  -- The compatibility aliases preserve existing NiniKick/BigWigs profiles.
  LSM:Register(SOUND, "NiniTools: Naowh Kick", NINI_KICK_PATH)
  LSM:Register(SOUND, "Kick -Naowh", NINI_KICK_PATH)
  LSM:Register(SOUND, "|cff0091edKick -Naowh|r", NINI_KICK_PATH)
  LSM:Register(SOUND, "Oh No", NINI_OHNO_PATH)
  LSM:Register(SOUND, "NiniTools: Oh No", NINI_OHNO_PATH)
  return true
end

local function RegisterCountdown()
  if type(BigWigsAPI) ~= "table" or type(BigWigsAPI.RegisterCountdown) ~= "function" then
    return false
  end
  if type(BigWigsAPI.HasCountdown) == "function" and BigWigsAPI:HasCountdown("뜌미") then
    return true
  end

  local path = "Interface\\AddOns\\NiniTools\\Media\\Countdown\\%s.ogg"
  BigWigsAPI:RegisterCountdown("뜌미", {
    path:format("1"), path:format("2"), path:format("3"), path:format("4"), path:format("5"),
  })
  return true
end

local function IsGTFOReady()
  return type(GTFO) == "table"
    and type(GTFO.Settings) == "table"
    and type(GTFO.Settings.Sounds) == "table"
    and type(GTFO.Settings.SoundOverrides) == "table"
end

local function EnsureBridgeDB()
  if _G.NiniTools then _G.NiniTools:BindModuleDB() end
  NiniMediaDB = type(NiniMediaDB) == "table" and NiniMediaDB or {}
  return NiniMediaDB
end

local function SyncGTFOData()
  if type(GTFOData) ~= "table" or not IsGTFOReady() then return end

  GTFOData.SoundOverrides = type(GTFOData.SoundOverrides) == "table"
    and GTFOData.SoundOverrides or {"","","",""}
  GTFOData.Sounds = type(GTFOData.Sounds) == "table"
    and GTFOData.Sounds or {true,true,true,true}

  GTFOData.SoundOverrides[GTFO_HIGH] = FLOOR_PATH
  for i=1,4 do
    GTFOData.Sounds[i] = GTFO.Settings.Sounds[i]
  end
  GTFOData.Volume = GTFO.Settings.Volume
  GTFOData.SoundChannel = GTFO.Settings.SoundChannel
end

local function ApplyGTFOBridge(fromSaveHook)
  if not IsGTFOReady() then
    bridge.applied = false
    bridge.lastRefreshReason = "GTFO-not-ready"
    return false, false
  end

  local db = EnsureBridgeDB()
  local changed = false

  if db.gtfoPreset120Applied ~= true then
    -- Preserve existing categories, including explicit false values.
    db.gtfoPreset120Applied = true
    changed = true
  end

  if GTFO.Settings.SoundOverrides[GTFO_HIGH] ~= FLOOR_PATH then
    GTFO.Settings.SoundOverrides[GTFO_HIGH] = FLOOR_PATH
    changed = true
  end

  -- GTFO 4/5 volume repeats the same override two/three times.
  if (tonumber(GTFO.Settings.Volume) or 3) >= 4 then
    GTFO.Settings.Volume = 3
    changed = true
  end

  if GTFO.Settings.SoundChannel ~= "Master" then
    GTFO.Settings.SoundChannel = "Master"
    changed = true
  end

  SyncGTFOData()
  bridge.applied = true

  if changed and not fromSaveHook and type(GTFO_SaveSettings) == "function" then
    pcall(GTFO_SaveSettings)
  end

  return true, changed
end

local function GTFORegistrationRestricted()
  if type(GTFO) == "table" and type(GTFO.IsAuraSoundRegistrationRestricted) == "function" then
    local ok, restricted = pcall(GTFO.IsAuraSoundRegistrationRestricted)
    if ok then return restricted and true or false end
  end
  return false
end

local function RefreshGTFO(reason)
  local ok = ApplyGTFOBridge(false)
  if not ok then return false end

  if type(GTFO_ActivateMod) ~= "function" then
    bridge.lastRefreshReason = "activate-missing"
    return false
  end

  local success = pcall(GTFO_ActivateMod)
  bridge.lastRefreshReason = success and (reason or "refresh") or "activate-error"
  return success
end

local function InstallSaveHook()
  if bridge.hooked or type(hooksecurefunc) ~= "function" or type(GTFO_SaveSettings) ~= "function" then
    return
  end

  bridge.hooked = true
  hooksecurefunc("GTFO_SaveSettings", function()
    local ok, changed = ApplyGTFOBridge(true)
    if not ok then return end

    if changed and C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if type(GTFO_ActivateMod) == "function" then
          pcall(GTFO_ActivateMod)
        end
      end)
    end
  end)
end

local function GetGTFOStatus()
  local loaded = type(GTFO) == "table"
  local ready = IsGTFOReady()
  local sounds = ready and GTFO.Settings.Sounds or nil
  local override = ready and GTFO.Settings.SoundOverrides[GTFO_HIGH] or nil

  return {
    loaded = loaded,
    ready = ready,
    version = loaded and tostring(GTFO.Version or "?") or "-",
    high = sounds and sounds[1] ~= false or false,
    low = sounds and sounds[2] ~= false or false,
    fail = sounds and sounds[3] ~= false or false,
    friendly = sounds and sounds[4] ~= false or false,
    override = override == FLOOR_PATH,
    overridePath = override or "",
    volume = ready and tonumber(GTFO.Settings.Volume) or 0,
    channel = ready and tostring(GTFO.Settings.SoundChannel or "?") or "?",
    restricted = ready and GTFORegistrationRestricted() or false,
    lastRefreshReason = bridge.lastRefreshReason,
  }
end

_G.NiniMedia_GetGTFOStatus = GetGTFOStatus

_G.NiniMedia_SetGTFOCategory = function(level, enabled)
  level = tonumber(level)
  if not level or level < 1 or level > 4 or not IsGTFOReady() then return false end

  GTFO.Settings.Sounds[level] = enabled and true or false
  SyncGTFOData()

  if type(GTFO_SaveSettings) == "function" then
    pcall(GTFO_SaveSettings)
  end
  RefreshGTFO("category")
  return true
end

_G.NiniMedia_ReapplyGTFO = function()
  return RefreshGTFO("manual")
end

_G.NiniMedia_TestFloorSound = function()
  ApplyGTFOBridge(false)
  if type(PlaySoundFile) ~= "function" then return false end
  local ok, played = pcall(PlaySoundFile, FLOOR_PATH, "Master")
  return ok and played and true or false
end

RegisterMedia()
RegisterCountdown()
InstallSaveHook()

local boot = _G.NiniTools.EventDispatcher:CreateProxy("Media.Core")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("VARIABLES_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("ZONE_CHANGED_NEW_AREA")
boot:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
boot:SetScript("OnEvent", function(_, event, arg)
  RegisterMedia()
  RegisterCountdown()

  if event == "ADDON_LOADED" and arg == "GTFO" then
    InstallSaveHook()
  end

  if event == "VARIABLES_LOADED" then
    InstallSaveHook()
    local ok, changed = ApplyGTFOBridge(false)
    if ok and changed and C_Timer and C_Timer.After then
      C_Timer.After(0, function() RefreshGTFO("variables") end)
    end
    return
  end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.After then
      C_Timer.After(0, RegisterMedia)
      C_Timer.After(1, RegisterMedia)
      C_Timer.After(3, RegisterMedia)
    end
    local ok, changed = ApplyGTFOBridge(false)
    if ok and changed then
      RefreshGTFO("world")
    end
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    ApplyGTFOBridge(false)
  end
end)

SLASH_NINIMEDIA1 = "/nm"
SlashCmdList.NINIMEDIA = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")

  if msg == "test" or msg == "floor" then
    local played = _G.NiniMedia_TestFloorSound()
    local st = GetGTFOStatus()
    print(("|cff33ff99NiniMedia|r GTFO→BigWigs 발밑 · GTFO=%s v%s · High=%s · 오버라이드=%s · Volume=%s · Channel=%s · 제한=%s · 음원=%s")
      :format(st.loaded and "로드됨" or "미설치", st.version,
        st.high and "ON" or "OFF", st.override and "OK" or "X",
        tostring(st.volume), st.channel, st.restricted and "ON" or "OFF",
        played and "OK" or "실패"))

  elseif msg == "fix" then
    local ok = RefreshGTFO("slash-fix")
    local st = GetGTFOStatus()
    print(("|cff33ff99NiniMedia|r GTFO 소리 바꿔치기 · %s · High=%s · 오버라이드=%s · Volume=%s")
      :format(ok and "적용됨" or "실패", st.high and "ON" or "OFF",
        st.override and "OK" or "X", tostring(st.volume)))
  else
    print("|cff33ff99NiniMedia|r /nm test = BigWigs 발밑음 테스트 · /nm fix = GTFO High Damage 소리 재적용")
  end
end


-- ---------------------------------------------------------------------------
-- Chat bubble font size
-- 던전/레이드의 말풍선은 forbidden frame이라 개별 프레임 수정이 막힐 수 있다.
-- 대신 Blizzard 전역 FontObject인 ChatBubbleFont 자체의 크기를 바꾼다.
-- ---------------------------------------------------------------------------
local function BubbleFontSize()
  NiniMediaDB = type(NiniMediaDB)=="table" and NiniMediaDB or {}
  local size=tonumber(NiniMediaDB.bubbleFontSize) or 10
  if size<8 then size=8 elseif size>20 then size=20 end
  NiniMediaDB.bubbleFontSize=size
  return size
end

local function ApplyChatBubbleFontSize()
  if not ChatBubbleFont or type(ChatBubbleFont.GetFont) ~= "function" or type(ChatBubbleFont.SetFont) ~= "function" then
    return false
  end

  local ok, fontPath, _, flags = pcall(ChatBubbleFont.GetFont, ChatBubbleFont)
  if not ok then return false end

  fontPath = fontPath or STANDARD_TEXT_FONT
  return pcall(ChatBubbleFont.SetFont, ChatBubbleFont, fontPath, BubbleFontSize(), flags or "")
end

_G.NiniMedia_SetBubbleFontSize=function(size)
  size=math.floor((tonumber(size) or 10)+0.5)
  if size<8 then size=8 elseif size>20 then size=20 end
  NiniMediaDB = type(NiniMediaDB)=="table" and NiniMediaDB or {}
  NiniMediaDB.bubbleFontSize=size
  ApplyChatBubbleFontSize()
  return size
end

_G.NiniMedia_GetBubbleFontSize=function()
  return BubbleFontSize()
end

local bubbleFontFrame = _G.NiniTools.EventDispatcher:CreateProxy("Media.BubbleFont")
bubbleFontFrame:RegisterEvent("PLAYER_LOGIN")
bubbleFontFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bubbleFontFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
bubbleFontFrame:SetScript("OnEvent", function()
  ApplyChatBubbleFontSize()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, ApplyChatBubbleFontSize)
    C_Timer.After(2.0, ApplyChatBubbleFontSize)
  end
end)
