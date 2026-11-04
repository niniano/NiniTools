local _, NT = ...
if not NT then return end

-- NiniCallMe integrated into NiniTools.
-- Plays one Navi "Hey" when another player's chat contains:
--   * built-in alias "니니"
--   * the currently logged-in character name
--   * user-defined aliases saved in NiniToolsDB.modules.media.callMeAliases
-- This module is the single name detector/sound source; matched messages are forwarded to NiniTools NaviChat.
local SOUND_ROOT = "Interface\\AddOns\\NiniTools\\Media\\Sounds\\"
local SOUND_100 = SOUND_ROOT.."Navi_Hey.mp3"
local MIN_VOLUME,MAX_VOLUME,VOLUME_STEP = 50,250,10
local frame = _G.NiniTools.EventDispatcher:CreateProxy("Media.CallMe")
local IsSecret = issecretvalue or function() return false end
local playerName, playerGUID
local aliasCacheText=nil
local aliasCache={}

local CHAT_EVENTS = {
  "CHAT_MSG_SAY",
  "CHAT_MSG_YELL",
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_GUILD",
  "CHAT_MSG_OFFICER",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function getDB()
  if NT.BindModuleDB then NT:BindModuleDB() end
  local root = type(NiniToolsDB)=="table" and NiniToolsDB or nil
  local modules = root and root.modules
  local media = modules and modules.media
  if type(media)~="table" then return nil end
  if media.callMeEnabled==nil then media.callMeEnabled=true end
  if type(media.callMeAliases)~="string" then media.callMeAliases="" end
  if media.callMeVolume==nil then media.callMeVolume=160 end
  media.callMeVolume=math.max(MIN_VOLUME,math.min(MAX_VOLUME,tonumber(media.callMeVolume) or 160))
  return media
end

local chatEventsRegistered=false
local function syncChatEvents()
  local db=getDB()
  local want=db and db.callMeEnabled~=false or false
  if want==chatEventsRegistered then return end
  chatEventsRegistered=want
  for _,event in ipairs(CHAT_EVENTS) do
    if want then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
  end
end

local function refreshPlayer()
  local okName, name = pcall(UnitName,"player")
  if okName and type(name)=="string" and not IsSecret(name) and name~="" then playerName=name end
  local okGUID, guid = pcall(UnitGUID,"player")
  if okGUID and type(guid)=="string" and not IsSecret(guid) and guid~="" then playerGUID=guid end
  aliasCacheText=nil
end

local function safeContains(message, needle)
  if IsSecret(message) or IsSecret(needle) then return false end
  if type(message)~="string" or type(needle)~="string" or needle=="" then return false end
  local ok, first = pcall(string.find,message,needle,1,true)
  return ok and type(first)=="number"
end

local function isSelf(author, guid)
  if IsSecret(author) or IsSecret(guid) then return false end
  -- Prefer GUID when available. Convert the comparison to a normal number
  -- inside pcall so a restricted/secret comparison never escapes as a boolean.
  if playerGUID then
    local ok, result = pcall(function()
      if guid==playerGUID then return 1 end
      return 0
    end)
    if ok and result==1 then return true end
  end

  if playerName then
    local ok, result = pcall(function()
      local short = type(Ambiguate)=="function" and Ambiguate(author,"short") or author
      if short==playerName then return 1 end
      return 0
    end)
    if ok and result==1 then return true end
  end
  return false
end

local function trim(text)
  if type(text)~="string" then return "" end
  return (text:gsub("^%s+",""):gsub("%s+$",""))
end

local function rebuildAliasCache()
  local db=getDB()
  local text=(db and db.callMeAliases) or ""
  if text==aliasCacheText then return aliasCache end

  aliasCacheText=text
  wipe(aliasCache)
  local seen={}

  -- Comma / semicolon / newline separated. Spaces inside an alias are preserved.
  for token in text:gmatch("[^,;\r\n]+") do
    local alias=trim(token)
    if alias~="" and alias~="니니" and alias~=playerName and not seen[alias] then
      seen[alias]=true
      aliasCache[#aliasCache+1]=alias
      if #aliasCache>=32 then break end
    end
  end

  return aliasCache
end

local function normalizeAliasText(text)
  if type(text)~="string" then return "" end

  local list={}
  local seen={}
  for token in text:gmatch("[^,;\r\n]+") do
    local alias=trim(token)
    -- Preserve exactly what the user chose to save in the UI.
    -- Built-in names are still de-duplicated internally during detection.
    if alias~="" and not seen[alias] then
      seen[alias]=true
      list[#list+1]=alias
      if #list>=32 then break end
    end
  end
  return table.concat(list,", ")
end

local function callsMe(message)
  if safeContains(message,"니니") then return true end
  if playerName and safeContains(message,playerName) then return true end

  for _,alias in ipairs(rebuildAliasCache()) do
    if safeContains(message,alias) then return true end
  end

  return false
end

local function normalizeVolume(value)
  local v=tonumber(value) or 160
  v=math.max(MIN_VOLUME,math.min(MAX_VOLUME,v))
  v=math.floor((v/VOLUME_STEP)+0.5)*VOLUME_STEP
  return math.max(MIN_VOLUME,math.min(MAX_VOLUME,v))
end

local function soundForVolume(volume)
  local v=normalizeVolume(volume)
  if v==100 then return SOUND_100,v end
  return SOUND_ROOT.."Navi_Hey_"..v..".mp3",v
end

local function playAlert()
  if type(PlaySoundFile)~="function" then return false end
  local db=getDB()
  local path=soundForVolume(db and db.callMeVolume or 160)
  local ok, played = pcall(PlaySoundFile,path,"Master")
  return ok and played and true or false
end

function NT:IsCallMeEnabled()
  local db=getDB()
  return db and db.callMeEnabled~=false or false
end

function NT:SetCallMeEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.callMeEnabled=enabled and true or false
  syncChatEvents()
  return true
end

function NT:GetCallMeVolume()
  local db=getDB()
  return db and normalizeVolume(db.callMeVolume) or 160
end

function NT:SetCallMeVolume(value)
  local db=getDB()
  if not db then return false end
  db.callMeVolume=normalizeVolume(value)
  return true,db.callMeVolume
end

function NT:GetCallMeAliasesText()
  local db=getDB()
  return db and (db.callMeAliases or "") or ""
end

function NT:SetCallMeAliasesText(text)
  local db=getDB()
  if not db then return false end

  db.callMeAliases=normalizeAliasText(text)
  aliasCacheText=nil
  rebuildAliasCache()
  return true,db.callMeAliases
end

function NT:ClearCallMeAliases()
  return self:SetCallMeAliasesText("")
end

function NT:TestCallMeSound()
  local ok=playAlert()
  self:Print(ok and ("채팅 호출 알림 · Hey "..self:GetCallMeVolume().."% 테스트") or "채팅 호출 알림 음원 재생 실패")
  return ok
end


SLASH_NINICALLME1="/ncall"
SLASH_NINICALLME2="/callme"
SlashCmdList.NINICALLME=function(msg)
  local raw=trim(msg or "")
  local cmd,arg=raw:match("^(%S+)%s*(.-)$")
  cmd=(cmd or ""):lower()

  if cmd=="alias" or cmd=="aliases" or cmd=="별명" then
    if arg and arg~="" then
      local ok,text=NT:SetCallMeAliasesText(arg)
      if ok then NT:Print("CallMe 별명: "..(text~="" and text or "없음")) end
    else
      local text=NT:GetCallMeAliasesText()
      NT:Print("CallMe 별명: "..(text~="" and text or "없음"))
    end
  elseif cmd=="clear" or cmd=="초기화" then
    NT:ClearCallMeAliases()
    NT:Print("CallMe 별명을 모두 지웠습니다.")
  elseif cmd=="on" then
    NT:SetCallMeEnabled(true)
    NT:Print("CallMe ON")
  elseif cmd=="off" then
    NT:SetCallMeEnabled(false)
    NT:Print("CallMe OFF")
  elseif cmd=="test" then
    NT:TestCallMeSound()
  else
    NT:Print("/ncall alias 니노, 니아노 | aliases | clear | on | off | test")
  end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent",function(_,event,...)
  if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
    refreshPlayer()
    getDB()
    syncChatEvents()
    return
  end

  local db=getDB()
  if not db or db.callMeEnabled==false then return end

  local message, author = ...
  if IsSecret(message) or IsSecret(author) then return end

  -- CHAT_MSG_* arg12 is sender GUID on Retail. Keep the positional extraction
  -- local to this handler so the module does not inspect unrelated payloads.
  local guid = select(12,...)

  if isSelf(author,guid) then return end
  if callsMe(message) then
    playAlert()

    -- Forward every matched call, including Raid Warning.
    -- NaviChat removes a matching ordinary row before adding the highlighted row.
    if type(NT.NaviChatPushCall)=="function" then
      pcall(NT.NaviChatPushCall,NT,event,message,author)
    end
  end
end)
