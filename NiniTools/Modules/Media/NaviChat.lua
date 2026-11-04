local _, NT = ...
if not NT then return end

-- NiniTools NaviChat
-- Reimplementation of the sparse "Chat Messages 3" feed.
-- AFK state is intentionally never queried because WoW 12.x can expose it
-- as a restricted/secret value. Resting / combat / alive checks are guarded
-- with pcall so a rejected state check simply suppresses the ordinary line.

local chatDriver = CreateFrame("Frame")
local IsSecret = issecretvalue or function() return false end
local chatUpdate
local chatEvents
local chatEventsRegistered=false
local function StartChatDriver()
  if chatUpdate then chatDriver:SetScript("OnUpdate",chatUpdate) end
end
local function StopChatDriver()
  chatDriver:SetScript("OnUpdate",nil)
end

local CHANNELS = {
  CHAT_MSG_SAY                  = { format="Say: %s: %s",          color={1,1,1,1},                                  duration=10 },
  CHAT_MSG_WHISPER              = { format="PM: %s: %s",           color={0.92549026,0.57647061,1,1},                duration=10 },
  CHAT_MSG_BN_WHISPER           = { format="Bnet: %s: %s",         color={0.44705886,0.99215692,0.92549026,1},       duration=10 },
  CHAT_MSG_GUILD                = { format="Guild: %s: %s",        color={0.40392160,0.84705889,0.47058827,1},       duration=10 },
  CHAT_MSG_OFFICER              = { format="Officer: %s: %s",      color={0.24313727,0.53333336,0.28627452,1},       duration=10 },
  CHAT_MSG_PARTY                = { format="Party: %s: %s",        color={0.50196081,0.71372551,1,1},                duration=10 },
  CHAT_MSG_INSTANCE_CHAT        = { format="Instance: %s: %s",     color={1,0.63921571,0,1},                         duration=10 },
  CHAT_MSG_RAID                 = { format="Raid: %s: %s",         color={1,0.58039218,0.29411766,1},                duration=10 },
  CHAT_MSG_RAID_WARNING         = { format="Raid Warning: %s: %s", color={1,0.36470589,0.26666668,1},                duration=10 },
  CHAT_MSG_YELL                 = { format="Yell: %s: %s",         color={1,0.25,0.25,1},                            duration=10 },
}

local ALIASES = {
  CHAT_MSG_PARTY_LEADER         = "CHAT_MSG_PARTY",
  CHAT_MSG_RAID_LEADER          = "CHAT_MSG_RAID",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "CHAT_MSG_INSTANCE_CHAT",
}

local SCREENSAVER_EVENTS = {
  CHAT_MSG_SAY=true,
  CHAT_MSG_WHISPER=true,
  CHAT_MSG_BN_WHISPER=true,
  CHAT_MSG_GUILD=true,
  CHAT_MSG_OFFICER=true,
  CHAT_MSG_PARTY=true,
  CHAT_MSG_PARTY_LEADER=true,
  CHAT_MSG_INSTANCE_CHAT=true,
  CHAT_MSG_INSTANCE_CHAT_LEADER=true,
  CHAT_MSG_RAID=true,
  CHAT_MSG_RAID_LEADER=true,
  CHAT_MSG_RAID_WARNING=true,
}

local SPECIAL = {
  BOSS    = { color={1,0.48235297,0.36862746,1}, duration=2 },
  LOOT    = { color={0,1,0.81960791,1},          duration=4 },
  SYSTEM  = { color={1,0.83137262,0,1},          duration=4 },
  ENCHANT = { color={0.32549021,0.40392160,1,1}, duration=4 },
}


local function getDB()
  if NT.BindModuleDB then NT:BindModuleDB() end
  local db=NiniToolsDB and NiniToolsDB.modules and NiniToolsDB.modules.media
  if type(db)~="table" then return nil end

  if db.naviChatEnabled==nil then db.naviChatEnabled=true end
  if db.naviChatX==nil then db.naviChatX=-488 end
  if db.naviChatY==nil then db.naviChatY=202 end
  if db.naviChatFontSize==nil then db.naviChatFontSize=14 end
  if db.naviChatUnlocked==nil then db.naviChatUnlocked=false end
  if db.naviChatNormX~=nil then db.naviChatNormX=tonumber(db.naviChatNormX) end
  if db.naviChatNormY~=nil then db.naviChatNormY=tonumber(db.naviChatNormY) end
  return db
end

local function GetFont()
  -- 2.5.4: NiniTools 공통 본문 글꼴 (NaowhKR) 우선
  local NTA=_G.NiniTools
  if NTA and type(NTA.BodyFont)=="function" then
    local ok,p=pcall(NTA.BodyFont,NTA)
    if ok and type(p)=="string" and p~="" then return p end
  end
  if LibStub then
    local lsm=LibStub("LibSharedMedia-3.0",true)
    if lsm then
      local p=lsm:Fetch("font","Expressway",true)
      if p then return p end
    end
  end
  return select(1,GameFontNormal:GetFont())
end

local FONT=GetFont()
local SPACE=2
local FADE=0.25
local CALL_DURATION=3

local root=CreateFrame("Frame",nil,UIParent)
root:SetSize(1,1)
root:SetFrameStrata("MEDIUM")
root:SetMovable(true)
root:SetClampedToScreen(true)
root:Show()

local mover=CreateFrame("Frame",nil,root,"BackdropTemplate")
mover:SetSize(130,24)
mover:SetPoint("CENTER",root,"CENTER",0,0)
mover:SetFrameStrata("DIALOG")
mover:SetBackdrop({
  bgFile="Interface\\Buttons\\WHITE8X8",
  edgeFile="Interface\\Buttons\\WHITE8X8",
  edgeSize=1,
})
mover:SetBackdropColor(0,0,0,0.65)
mover:SetBackdropBorderColor(0.3,0.8,1,1)

local moverText=mover:CreateFontString(nil,"OVERLAY","GameFontNormal")
moverText:SetPoint("CENTER")
moverText:SetText("Navi Chat")
moverText:SetTextColor(0.5,0.9,1,1)

local function UIReady()
  local w,h=UIParent:GetWidth(),UIParent:GetHeight()
  return type(w)=="number" and type(h)=="number" and w>10 and h>10
end

local function MigrateLegacyPosition(db)
  if not db or not UIReady() then return false end
  if db.naviChatNormX~=nil and db.naviChatNormY~=nil then return true end

  local w,h=UIParent:GetWidth(),UIParent:GetHeight()
  local x=tonumber(db.naviChatX) or -488
  local y=tonumber(db.naviChatY) or 202
  db.naviChatNormX=(w*0.5+x)/w
  db.naviChatNormY=(h*0.5+y)/h
  return true
end

local function ApplyPosition()
  local db=getDB()
  if not db or not UIReady() then return false end
  if not MigrateLegacyPosition(db) then return false end

  local w,h=UIParent:GetWidth(),UIParent:GetHeight()
  local nx=math.max(0,math.min(1,tonumber(db.naviChatNormX) or 0.5))
  local ny=math.max(0,math.min(1,tonumber(db.naviChatNormY) or 0.5))

  root:ClearAllPoints()
  root:SetPoint("CENTER",UIParent,"BOTTOMLEFT",nx*w,ny*h)
  return true
end

local function SaveCurrentPosition()
  local db=getDB()
  if not db or not UIReady() then return false end

  local cx,cy=root:GetCenter()
  local w,h=UIParent:GetWidth(),UIParent:GetHeight()
  if not cx or not cy or w<=0 or h<=0 then return false end

  db.naviChatNormX=math.max(0,math.min(1,cx/w))
  db.naviChatNormY=math.max(0,math.min(1,cy/h))
  db.naviChatX=cx-(w*0.5)
  db.naviChatY=cy-(h*0.5)
  return true
end

local function ApplyMover()
  local db=getDB()
  local unlocked=db and db.naviChatUnlocked==true
  mover:EnableMouse(unlocked)
  mover:SetShown(unlocked)
end

mover:RegisterForDrag("LeftButton")
mover:SetScript("OnDragStart",function()
  root:StartMoving()
end)

mover:SetScript("OnDragStop",function()
  root:StopMovingOrSizing()
  local db=getDB()
  if db and SaveCurrentPosition() then
    ApplyPosition()
    NT:Print(string.format(
      "Navi 채팅 위치 저장 %.1f%% / %.1f%%",
      (db.naviChatNormX or 0.5)*100,
      (db.naviChatNormY or 0.5)*100
    ))
  end
end)

local pool={}
local used={}
local messages={}
local serial=0

local function ReleaseRows()
  for i=#used,1,-1 do
    local row=used[i]
    row:Hide()
    row:ClearAllPoints()
    row.text:SetText("")
    pool[#pool+1]=row
    used[i]=nil
  end
end

local function AcquireRow()
  local row=table.remove(pool)
  if not row then
    row=CreateFrame("Frame",nil,root)
    local fs=row:CreateFontString(nil,"OVERLAY")
    fs:SetPoint("LEFT",row,"LEFT",0,0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)
    fs:SetShadowOffset(1,-1)
    fs:SetShadowColor(0,0,0,0)
    row.text=fs
  end
  row:Show()
  used[#used+1]=row
  return row
end

local function SafeFormat(fmt,...)
  local ok,value=pcall(string.format,fmt,...)
  if ok and type(value)=="string" then return value end
  return nil
end

local function SafePlain(value)
  -- WoW 12.x may deliver restricted/secret chat strings.
  -- Never concatenate/compare them; just skip those lines.
  if type(value)~="string" then return nil end
  if IsSecret(value) then return nil end
  return value
end

local function SafeScreensaverCondition()
  local ok,result=pcall(function()
    if type(IsResting)=="function" then
      local resting=IsResting()
      if IsSecret(resting) then return 0 end
      if not resting then return 0 end
    end

    if type(UnitAffectingCombat)=="function" then
      local combat=UnitAffectingCombat("player")
      if IsSecret(combat) then return 0 end
      if combat then return 0 end
    end

    if type(UnitIsDeadOrGhost)=="function" then
      local dead=UnitIsDeadOrGhost("player")
      if IsSecret(dead) then return 0 end
      if dead then return 0 end
    end

    return 1
  end)
  return ok and result==1
end

local function PushText(sourceEvent,text,color,duration,isCallMe,dedupeKey)
  local db=getDB()
  if not db or db.naviChatEnabled==false then return false end
  if type(text)~="string" then return false end
  if IsSecret(text) then return false end
  if text=="" then return false end

  serial=serial+1
  local now=GetTime()
  messages[#messages+1]={
    event=sourceEvent,
    text=text,
    color=color or {1,1,1,1},
    isCallMe=isCallMe and true or false,
    born=now,
    expires=now+(duration or CALL_DURATION),
    serial=serial,
    dedupeKey=dedupeKey,
  }
  StartChatDriver()
  return true
end

local function BuildChatKey(event,message,author)
  if IsSecret(message) or IsSecret(author) then return nil end
  event=ALIASES[event] or event
  return SafeFormat("%s\031%s\031%s",event,author or "",message or "")
end

local function PushChat(sourceEvent,message,author,isCallMe,duration)
  if IsSecret(message) or IsSecret(author) then return false end
  sourceEvent=ALIASES[sourceEvent] or sourceEvent
  local info=CHANNELS[sourceEvent] or CHANNELS.CHAT_MSG_SAY
  local text=SafeFormat(info.format,author or "",message or "")
  if not text then return false end

  local key=BuildChatKey(sourceEvent,message,author)

  if isCallMe and key then
    for i=#messages,1,-1 do
      local m=messages[i]
      if m.dedupeKey==key and not m.isCallMe then
        table.remove(messages,i)
        break
      end
    end
  end

  return PushText(
    sourceEvent,
    isCallMe and ("★ "..text) or text,
    isCallMe and {1,0.82,0.18,1} or info.color,
    duration or (isCallMe and CALL_DURATION or info.duration),
    isCallMe,
    key
  )
end

local function RemoveExpired(now)
  local write=1
  for read=1,#messages do
    local m=messages[read]
    if m.expires>now then
      if write~=read then messages[write]=m end
      write=write+1
    end
  end
  for i=#messages,write,-1 do messages[i]=nil end
end

local function AlphaFor(m,now)
  local age=now-m.born
  if age<FADE then return math.max(0,math.min(1,age/FADE)) end
  local left=m.expires-now
  if left<FADE then return math.max(0,math.min(1,left/FADE)) end
  return 1
end

local function Layout(now)
  ReleaseRows()
  local db=getDB()
  if not db or db.naviChatEnabled==false then return end

  local y=0
  local baseSize=math.max(8,math.min(32,tonumber(db.naviChatFontSize) or 14))

  for _,m in ipairs(messages) do
    local row=AcquireRow()
    local fontSize=m.isCallMe and math.min(36,baseSize+4) or baseSize
    local outline=m.isCallMe and "THICKOUTLINE" or "OUTLINE"
    local rowHeight=fontSize+3
    local c=m.color or {1,1,1,1}

    row:SetSize(1407,rowHeight)
    FONT=GetFont()
    row.text:SetFont(FONT,fontSize,outline)
    row.text:SetTextColor(c[1],c[2],c[3],c[4])
    row:SetAlpha(AlphaFor(m,now))

    local ok=pcall(row.text.SetText,row.text,m.text)
    if not ok then row.text:SetText("") end

    -- Original dynamic group: LEFT aligned, grows DOWN, 2 px spacing.
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",root,"CENTER",0,-y)
    y=y+rowHeight+SPACE
  end
end

local lootPatterns=nil

local function EscapeLuaPatternChar(ch)
  if ch=="^" or ch=="$" or ch=="(" or ch==")" or ch=="%" or ch=="." or
     ch=="[" or ch=="]" or ch=="*" or ch=="+" or ch=="-" or ch=="?" then
    return "%"..ch
  end
  return ch
end

local function FormatStringToPattern(fmt)
  if type(fmt)~="string" or fmt=="" then return nil end
  local marker="\001"
  local s=fmt
  s=s:gsub("%%%d+%$[sdif]",marker)
  s=s:gsub("%%[sdif]",marker)

  local out={}
  for i=1,#s do
    local ch=s:sub(i,i)
    if ch==marker then
      out[#out+1]=".+"
    else
      out[#out+1]=EscapeLuaPatternChar(ch)
    end
  end
  return "^"..table.concat(out).."$"
end

local function BuildLootPatterns()
  if lootPatterns then return lootPatterns end
  lootPatterns={}

  local names={
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "LOOT_ITEM_REFUND",
    "LOOT_ITEM_REFUND_MULTIPLE",
  }

  for _,name in ipairs(names) do
    local fmt=_G[name]
    local pat=FormatStringToPattern(fmt)
    if pat then lootPatterns[#lootPatterns+1]=pat end
  end
  return lootPatterns
end

local function IsOwnLootMessage(message)
  local text=SafePlain(message)
  if not text then return false end
  for _,pat in ipairs(BuildLootPatterns()) do
    local ok,found=pcall(string.match,text,pat)
    if ok and found then return true end
  end
  return false
end

local function SyncChatEvents()
  if not chatEvents then return end
  local db=getDB()
  local want=db and db.naviChatEnabled~=false or false
  if want==chatEventsRegistered then return end
  chatEventsRegistered=want
  for event in pairs(SCREENSAVER_EVENTS) do
    if want then chatEvents:RegisterEvent(event) else chatEvents:UnregisterEvent(event) end
  end
  for _,event in ipairs({"CHAT_MSG_RAID_BOSS_EMOTE","CHAT_MSG_MONSTER_EMOTE","CHAT_MSG_LOOT","CHAT_MSG_SYSTEM"}) do
    if want then chatEvents:RegisterEvent(event) else chatEvents:UnregisterEvent(event) end
  end
end

function NT:IsNaviChatEnabled()
  local db=getDB()
  return db and db.naviChatEnabled~=false or false
end

function NT:SetNaviChatEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviChatEnabled=enabled and true or false
  SyncChatEvents()
  if not db.naviChatEnabled then
    wipe(messages)
    ReleaseRows()
    StopChatDriver()
  elseif #messages>0 then
    StartChatDriver()
  end
  return true
end

function NT:GetNaviChatFontSize()
  local db=getDB()
  return db and (tonumber(db.naviChatFontSize) or 14) or 14
end

function NT:SetNaviChatFontSize(size)
  local db=getDB()
  if not db then return false end
  db.naviChatFontSize=math.max(8,math.min(32,math.floor((tonumber(size) or 14)+0.5)))
  return true
end

function NT:SetNaviChatUnlocked(unlocked)
  local db=getDB()
  if not db then return false end
  db.naviChatUnlocked=unlocked and true or false
  ApplyMover()
  return true
end

function NT:IsNaviChatUnlocked()
  local db=getDB()
  return db and db.naviChatUnlocked==true or false
end

function NT:ResetNaviChatPosition()
  local db=getDB()
  if not db then return false end
  db.naviChatX=-488
  db.naviChatY=202
  db.naviChatNormX=nil
  db.naviChatNormY=nil
  MigrateLegacyPosition(db)
  ApplyPosition()
  return true
end

function NT:NaviChatPushCall(event,message,author)
  return PushChat(event,message,author,true,CALL_DURATION)
end

function NT:TestNaviChat()
  PushText("TEST_SYSTEM","시스템 메시지 테스트",SPECIAL.SYSTEM.color,4,false,nil)
  PushText("TEST_LOOT","내 전리품 메시지 테스트",SPECIAL.LOOT.color,4,false,nil)
  PushText("TEST_BOSS","보스 감정표현 테스트",SPECIAL.BOSS.color,2,false,nil)
  PushChat("CHAT_MSG_WHISPER","니니 여기 봐줘","WhisperTester",true,CALL_DURATION)
  return true
end

function NT:ClearNaviChat()
  wipe(messages)
  ReleaseRows()
  StopChatDriver()
end

root:ClearAllPoints()
root:SetPoint("CENTER",UIParent,"CENTER",-488,202)
ApplyMover()

chatEvents = _G.NiniTools.EventDispatcher:CreateProxy("Media.NaviChat")

chatEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
chatEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
chatEvents:RegisterEvent("UI_SCALE_CHANGED")

local positionApplyToken=0
local function SchedulePositionApply()
  positionApplyToken=positionApplyToken+1
  local token=positionApplyToken

  C_Timer.After(0,function()
    if token==positionApplyToken then ApplyPosition() end
  end)
  C_Timer.After(0.25,function()
    if token==positionApplyToken then ApplyPosition() end
  end)
  C_Timer.After(1.0,function()
    if token==positionApplyToken then ApplyPosition() end
  end)
end

chatEvents:SetScript("OnEvent",function(_,event,...)
  if event=="PLAYER_ENTERING_WORLD" or event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" then
    if event=="PLAYER_ENTERING_WORLD" then SyncChatEvents() end
    SchedulePositionApply()
    return
  end

  local message,author=...

  if SCREENSAVER_EVENTS[event] then
    if SafeScreensaverCondition() then
      PushChat(event,message,author,false,nil)
    end
    return
  end

  if event=="CHAT_MSG_RAID_BOSS_EMOTE" or event=="CHAT_MSG_MONSTER_EMOTE" then
    local text=SafePlain(message)
    if text then
      PushText(event,text,SPECIAL.BOSS.color,SPECIAL.BOSS.duration,false,nil)
    end
    return
  end

  if event=="CHAT_MSG_LOOT" then
    if IsOwnLootMessage(message) then
      local text=SafePlain(message)
      if text then
        PushText(event,text,SPECIAL.LOOT.color,SPECIAL.LOOT.duration,false,nil)
      end
    end
    return
  end

  if event=="CHAT_MSG_SYSTEM" then
    local text=SafePlain(message)
    if text then
      PushText(event,text,SPECIAL.SYSTEM.color,SPECIAL.SYSTEM.duration,false,nil)
    end
  end
end)

SchedulePositionApply()

local accum=0
chatUpdate=function(_,dt)
  accum=accum+(dt or 0)
  if accum<0.03 then return end
  accum=0
  local now=GetTime()
  RemoveExpired(now)
  if #messages==0 then
    ReleaseRows()
    StopChatDriver()
    return
  end
  Layout(now)
end

SLASH_NININAVICHAT1="/navichat"
SlashCmdList.NININAVICHAT=function(msg)
  msg=(msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")

  if msg=="test" or msg=="demo" then
    NT:TestNaviChat()
  elseif msg=="clear" then
    NT:ClearNaviChat()
  elseif msg=="on" then
    NT:SetNaviChatEnabled(true)
  elseif msg=="off" then
    NT:SetNaviChatEnabled(false)
  elseif msg=="unlock" or msg=="move" then
    NT:SetNaviChatUnlocked(true)
  elseif msg=="lock" then
    NT:SetNaviChatUnlocked(false)
  elseif msg=="resetpos" then
    NT:ResetNaviChatPosition()
  else
    local font=msg:match("^font%s+(%d+)$")
    if font then
      NT:SetNaviChatFontSize(tonumber(font))
    else
      NT:Print("/navichat test | clear | on | off | unlock | lock | resetpos | font 14")
      return
    end
  end

  local db=getDB()
  NT:Print(string.format("Navi 채팅 %s · %d px",db.naviChatEnabled~=false and "ON" or "OFF",db.naviChatFontSize or 14))
end
