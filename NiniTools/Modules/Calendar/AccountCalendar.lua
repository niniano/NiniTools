local ADDON_NAME, NT = ...
if not NT then return end

-- 2.5.8: 계정 달력 (데이터)
-- 캐릭이 접속할 때 와우 달력에서 이번 달·다음 달 초대를 읽어 계정 공용 DB에 모은다.
--   NiniToolsDB.modules.calendar = {
--     chars   = { ["이름-서버"] = { name, realm, class, level, guild, synced, events = { … } } },
--     details = { [이벤트키] = { updated, by, creator, title, invites = { {name,class,level,status,mod}, … } } },
--     notes   = { ["2026-11-04"] = "메모" },
--     settings= { enabled, autoDetails, showAnnouncements, monthsAhead },
--   }
-- 달력 초대는 캐릭별이라 접속하지 않은 캐릭은 마지막으로 읽은 내용이 남는다.
-- 와우 기본 달력 창이 열려 있거나 전투 중이면 건드리지 않는다.

local M = NT.AccountCalendar or {}
NT.AccountCalendar = M

M.KEEP_DAYS = 120          -- 지난 초대는 이만큼만 남긴다
M.NOTE_KEEP_DAYS = 400     -- 날짜 메모
M.AUTO_SCAN_GAP = 15       -- 달력 이벤트로 다시 읽을 때 최소 간격(초)
M.DETAIL_FRESH = 6 * 3600  -- 참가자 목록을 다시 읽는 기준
M.AUTO_DETAIL_DAYS = 14
M.AUTO_DETAIL_MAX = 6

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function S(v) if v == nil or isSecret(v) then return nil end return v end
local function str(v) v = S(v); if v == nil then return nil end; v = tostring(v); if v == "" then return nil end; return v end
local function num(v) v = S(v); return tonumber(v) end
local function now() return (type(time) == "function" and time()) or 0 end
local function gtime() return (type(GetTime) == "function" and GetTime()) or 0 end
local function after(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) end
end

local ST = (Enum and Enum.CalendarStatus) or {}
M.STATUS = {
  INVITED = ST.Invited or 0, AVAILABLE = ST.Available or 1, DECLINED = ST.Declined or 2,
  CONFIRMED = ST.Confirmed or 3, OUT = ST.Out or 4, STANDBY = ST.Standby or 5,
  SIGNEDUP = ST.Signedup or 6, NOTSIGNEDUP = ST.NotSignedup or 7, TENTATIVE = ST.Tentative or 8,
}
local IT = (Enum and Enum.CalendarInviteType) or {}
M.INVITE_SIGNUP = IT.Signup or 1

-- 초대가 오는 종류만 모은다 (기념일·초기화 일정 제외)
M.TYPES = { PLAYER = true, GUILD_EVENT = true, COMMUNITY_EVENT = true }

do
  local s = M.STATUS
  M.STATUS_INFO = {
    [s.INVITED]     = { "응답 전", "wait" },
    [s.NOTSIGNEDUP] = { "미신청", "wait" },
    [s.AVAILABLE]   = { "수락", "yes" },
    [s.CONFIRMED]   = { "확정", "yes" },
    [s.SIGNEDUP]    = { "신청", "yes" },
    [s.STANDBY]     = { "대기", "maybe" },
    [s.TENTATIVE]   = { "미정", "maybe" },
    [s.DECLINED]    = { "거절", "no" },
    [s.OUT]         = { "불참", "no" },
  }
end

function M:StatusInfo(status, ctype)
  if ctype == "GUILD_ANNOUNCEMENT" then return "길드 공지", "info" end
  local i = self.STATUS_INFO[tonumber(status) or -1]
  if i then return i[1], i[2] end
  return "?", "wait"
end

-- ── 날짜 ───────────────────────────────────────────────
function M.DaysIn(y, m)
  local dm = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then return 29 end
  return dm[m] or 30
end

function M.AddMonths(y, m, k)
  local idx = (y * 12 + (m - 1)) + (k or 0)
  return math.floor(idx / 12), (idx % 12) + 1
end

function M.DayKey(y, m, d) return string.format("%04d-%02d-%02d", y, m, d) end
function M.MonthKey(y, m) return string.format("%04d-%02d", y, m) end

-- 1 = 일요일
function M.Weekday(y, m, d)
  -- Sakamoto
  local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  if m < 3 then y = y - 1 end
  return ((y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + t[m] + d) % 7) + 1
end

-- 날짜 비교용 정수 (분 단위)
function M.Stamp(y, m, d, h, mi)
  return ((((y * 12 + m) * 31 + d) * 24 + (h or 0)) * 60) + (mi or 0)
end

function M:Today()
  local t = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
  if type(t) == "table" and t.year then
    return { year = t.year, month = t.month, day = t.monthDay, hour = t.hour or 0, minute = t.minute or 0 }
  end
  local d = date("*t")
  return { year = d.year, month = d.month, day = d.day, hour = d.hour, minute = d.min }
end

function M:TodayStamp()
  local t = self:Today()
  return self.Stamp(t.year, t.month, t.day, t.hour, t.minute)
end

-- ── DB ────────────────────────────────────────────────
function M:DB()
  local root = NT:GetDB()
  root.modules = type(root.modules) == "table" and root.modules or {}
  local db = root.modules.calendar
  if type(db) ~= "table" then db = {}; root.modules.calendar = db end
  db.chars = type(db.chars) == "table" and db.chars or {}
  db.details = type(db.details) == "table" and db.details or {}
  db.notes = type(db.notes) == "table" and db.notes or {}
  db.settings = type(db.settings) == "table" and db.settings or {}
  local s = db.settings
  if s.enabled == nil then s.enabled = true end
  if s.autoDetails == nil then s.autoDetails = true end
  if s.showAnnouncements == nil then s.showAnnouncements = false end
  s.monthsAhead = math.max(0, math.min(2, tonumber(s.monthsAhead) or 1))
  return db
end

function M:CurrentChar()
  local name, realm
  if type(UnitFullName) == "function" then name, realm = UnitFullName("player") end
  name = str(name) or str(UnitName and UnitName("player"))
  realm = str(realm) or str(GetNormalizedRealmName and GetNormalizedRealmName()) or str(GetRealmName and GetRealmName())
  if not name or name == UNKNOWNOBJECT then return nil end
  realm = realm or "?"
  return name .. "-" .. realm, name, realm
end

function M:CurrentCharKey()
  local k = self:CurrentChar()
  return k
end

function M.DetailKey(e)
  if e.id and e.id ~= "0" then return "id:" .. e.id end
  return string.format("t:%04d%02d%02d%02d%02d:%s:%s", e.y, e.m, e.d, e.h or 0, e.mi or 0, e.title or "", e.by or "")
end

function M:MakeRecord(ev, settings)
  if type(ev) ~= "table" then return nil end
  local ctype = str(ev.calendarType)
  if not ctype then return nil end
  if not (self.TYPES[ctype] or (ctype == "GUILD_ANNOUNCEMENT" and settings and settings.showAnnouncements)) then return nil end
  local seq = str(ev.sequenceType)
  if seq and seq ~= "START" then return nil end
  local st = S(ev.startTime)
  if type(st) ~= "table" then return nil end
  local y, m, d = num(st.year), num(st.month), num(st.monthDay)
  if not (y and m and d) then return nil end
  return {
    id = str(ev.eventID),
    y = y, m = m, d = d, h = num(st.hour) or 0, mi = num(st.minute) or 0,
    title = str(ev.title) or "(제목 없음)",
    ctype = ctype,
    status = num(ev.inviteStatus),
    by = str(ev.invitedBy),
    diff = str(ev.difficultyName),
    itype = num(ev.inviteType),
    mod = str(ev.modStatus),
    locked = S(ev.isLocked) and true or nil,
    etype = num(ev.eventType),
  }
end

-- ── 달력 접근 ─────────────────────────────────────────
function M:BlizzardCalendarOpen()
  -- 2.6.5: IsShown은 부모(UIParent 등)가 숨겨져 있어도 참일 수 있다. 실제로 화면에 보일 때만 「열림」.
  local f = _G.CalendarFrame
  if not (f and f.IsVisible) then return false end
  local ok, vis = pcall(f.IsVisible, f)
  return ok and vis == true
end

-- 2.6.5: 니니툴 달력에서 응답을 누르면 와우 달력 창은 니니툴이 닫는다 (같은 달력 API를 같이 쓰면 꼬임).
function M:CloseBlizzardCalendar()
  local f = _G.CalendarFrame
  if not f then return end
  if type(HideUIPanel) == "function" then pcall(HideUIPanel, f) end
  if f.IsShown and f:IsShown() then pcall(f.Hide, f) end
end

function M:CanTouchCalendar()
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.SetAbsMonth) then return false, "api" end
  if InCombatLockdown and InCombatLockdown() then return false, "combat" end
  if self:BlizzardCalendarOpen() then return false, "blizzard" end
  if C_Calendar.IsActionPending and C_Calendar.IsActionPending() then return false, "pending" end
  return true
end

function M:RestoreMonth()
  local t = self:Today()
  pcall(C_Calendar.SetAbsMonth, t.month, t.year)
  self.lastTouch = gtime()
end

function M:Scan(reason)
  local db = self:DB()
  if not db.settings.enabled then return false, "off" end
  if self.scanning then return false, "busy" end
  local ok, why = self:CanTouchCalendar()
  if not ok then self.pendingScan = true; self.lastBlock = why; return false, why end
  local key, name, realm = self:CurrentChar()
  if not key then return false, "char" end

  local today = self:Today()
  local collected, months = {}, {}
  self.scanning = true
  local okRun, err = pcall(function()
    for k = 0, db.settings.monthsAhead do
      local y, m = self.AddMonths(today.year, today.month, k)
      C_Calendar.SetAbsMonth(m, y)
      months[self.MonthKey(y, m)] = true
      for d = 1, self.DaysIn(y, m) do
        local n = num(C_Calendar.GetNumDayEvents(0, d)) or 0
        for i = 1, n do
          local rec = self:MakeRecord(C_Calendar.GetDayEvent(0, d, i), db.settings)
          if rec then collected[#collected + 1] = rec end
        end
      end
    end
  end)
  self:RestoreMonth()
  self.scanning = false
  self.lastScanAt = gtime()
  if not okRun then self.lastError = tostring(err); return false, "error" end

  -- 달 이동(SetAbsMonth)이 다시 CALENDAR_UPDATE_EVENT_LIST를 부르면 15초마다 계속 읽을 수 있다.
  -- 달력 갱신 이벤트로 읽었는데 내용이 그대로면 5분 동안 그 이벤트는 쉰다 (새 초대 알림·직접 동기화는 바로).
  local sigParts = { key }
  for _, e in ipairs(collected) do sigParts[#sigParts + 1] = (e.id or e.title) .. ":" .. tostring(e.status) end
  local sig = table.concat(sigParts, "|")
  if reason == "update" and sig == self.lastSig then self.quietUntil = gtime() + 300 else self.quietUntil = nil end
  self.lastSig = sig

  local ch = type(db.chars[key]) == "table" and db.chars[key] or {}
  ch.name, ch.realm = name, realm
  if UnitClass then local _, cls = UnitClass("player"); ch.class = str(cls) or ch.class end
  if UnitLevel then ch.level = num(UnitLevel("player")) or ch.level end
  if GetGuildInfo then ch.guild = str((GetGuildInfo("player"))) end
  ch.synced = now()
  local kept = {}
  for _, e in ipairs(type(ch.events) == "table" and ch.events or {}) do
    if not months[self.MonthKey(e.y, e.m)] then kept[#kept + 1] = e end
  end
  for _, e in ipairs(collected) do kept[#kept + 1] = e end
  table.sort(kept, function(a, b) return self.Stamp(a.y, a.m, a.d, a.h, a.mi) < self.Stamp(b.y, b.m, b.d, b.h, b.mi) end)
  ch.events = kept
  db.chars[key] = ch
  self:Prune(db)
  self.pendingScan = false
  self.lastScanCount = #collected
  self:NotifyUI()
  if db.settings.autoDetails and reason ~= "detail" then self:QueueAutoDetails() end
  return true, #collected
end

function M:Prune(db)
  db = db or self:DB()
  local t = self:Today()
  local cy, cm = t.year, t.month
  local cutoff = self.Stamp(cy, cm, t.day, 0, 0) - self.KEEP_DAYS * 24 * 60
  local used = {}
  for _, ch in pairs(db.chars) do
    if type(ch) == "table" and type(ch.events) == "table" then
      local keep = {}
      for _, e in ipairs(ch.events) do
        if self.Stamp(e.y, e.m, e.d, e.h, e.mi) >= cutoff then
          keep[#keep + 1] = e
          used[self.DetailKey(e)] = true
        end
      end
      ch.events = keep
    end
  end
  for k in pairs(db.details) do if not used[k] then db.details[k] = nil end end
  local noteCut = self.Stamp(cy, cm, t.day, 0, 0) - self.NOTE_KEEP_DAYS * 24 * 60
  for k, v in pairs(db.notes) do
    local y, m, d = tostring(k):match("^(%d+)%-(%d+)%-(%d+)$")
    if not y or type(v) ~= "string" or v == "" or self.Stamp(tonumber(y), tonumber(m), tonumber(d), 0, 0) < noteCut then
      db.notes[k] = nil
    end
  end
end

-- ── 조회 (화면용) ─────────────────────────────────────
function M:Chars()
  local db = self:DB()
  local out = {}
  for key, ch in pairs(db.chars) do
    if type(ch) == "table" then out[#out + 1] = { key = key, name = ch.name or key, realm = ch.realm, class = ch.class, synced = ch.synced, count = #(ch.events or {}) } end
  end
  table.sort(out, function(a, b) return (a.synced or 0) > (b.synced or 0) end)
  return out
end

-- day → { {char=, ch=, e=}, … }
function M:MonthIndex(y, m, filter)
  local db = self:DB()
  local idx = {}
  for key, ch in pairs(db.chars) do
    if type(ch) == "table" and (not filter or filter == key) then
      for _, e in ipairs(ch.events or {}) do
        if e.y == y and e.m == m then
          idx[e.d] = idx[e.d] or {}
          table.insert(idx[e.d], { char = key, ch = ch, e = e })
        end
      end
    end
  end
  for _, list in pairs(idx) do
    table.sort(list, function(a, b)
      local sa, sb = self.Stamp(a.e.y, a.e.m, a.e.d, a.e.h, a.e.mi), self.Stamp(b.e.y, b.e.m, b.e.d, b.e.h, b.e.mi)
      if sa ~= sb then return sa < sb end
      return tostring(a.ch.name) < tostring(b.ch.name)
    end)
  end
  return idx
end

function M:Detail(e) return self:DB().details[self.DetailKey(e)] end

function M:GetNote(dayKey) return self:DB().notes[dayKey] end
function M:SetNote(dayKey, text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  self:DB().notes[dayKey] = (text ~= "") and text:sub(1, 300) or nil
end

-- ── 이벤트 열기 · 참가자 · 응답 ────────────────────────
function M:FindIndex(e)
  C_Calendar.SetAbsMonth(e.m, e.y)
  local n = num(C_Calendar.GetNumDayEvents(0, e.d)) or 0
  for i = 1, n do
    local ev = C_Calendar.GetDayEvent(0, e.d, i)
    if type(ev) == "table" then
      local st = S(ev.startTime) or {}
      if (e.id and str(ev.eventID) == e.id)
        or (not e.id and str(ev.title) == e.title and num(st.hour) == e.h and num(st.minute) == e.mi) then
        return i
      end
    end
  end
end

function M:CanRespond(charKey, e)
  if not e or e.ctype == "GUILD_ANNOUNCEMENT" then return false, "공지는 응답이 없습니다" end
  if charKey ~= self:CurrentCharKey() then return false, "이 캐릭으로 접속해야 응답할 수 있습니다" end
  if e.locked then return false, "잠긴 일정입니다" end
  if e.mod == "CREATOR" then return false, "내가 만든 일정입니다" end
  if self.Stamp(e.y, e.m, e.d, e.h, e.mi) < self:TodayStamp() then return false, "지난 일정입니다" end
  return true
end

function M:IsSignup(e) return e and e.itype == self.INVITE_SIGNUP end

-- action: nil(참가자만 읽기) · "yes" · "maybe" · "no"
function M:Open(charKey, e, action, quiet)
  if not e or e.ctype == "GUILD_ANNOUNCEMENT" then return false, "announce" end
  if charKey ~= self:CurrentCharKey() then return false, "other" end
  if action then
    local ok, why = self:CanRespond(charKey, e)
    if not ok then if not quiet then NT:Print(why) end; return false, "deny" end
  end
  local ok, why = self:CanTouchCalendar()
  if not ok then
    if not quiet then
      NT:Print(why == "blizzard" and "와우 달력 창을 닫은 뒤 다시 눌러 주세요." or (why == "combat" and "전투가 끝난 뒤 다시 눌러 주세요." or "달력이 바쁩니다. 잠시 뒤 다시 눌러 주세요."))
    end
    return false, why
  end
  local okFind, i = pcall(self.FindIndex, self, e)
  if not okFind or not i then
    self:RestoreMonth()
    if not quiet then NT:Print("이 일정을 달력에서 찾지 못했습니다. 지금 동기화 후 다시 눌러 주세요.") end
    return false, "missing"
  end
  self.pending = { key = self.DetailKey(e), e = e, char = charKey, action = action, at = gtime(), day = e.d, index = i }
  local okOpen = pcall(C_Calendar.OpenEvent, 0, e.d, i)
  if not okOpen then self.pending = nil; self:RestoreMonth(); return false, "open" end
  local token = self.pending
  after(5, function()
    if self.pending == token then
      self.pending = nil
      self:RestoreMonth()
      self:NextAutoDetail()
    end
  end)
  return true
end

-- 2.6.5: 수락 · 미정 · 거절
-- 예전에는 달력이 잠깐이라도 바쁘면(참가자 목록을 읽는 중 · 서버 응답 대기 · 와우 달력 창 열림) 바로 거절했다.
-- 이제는 같은 일정을 읽는 중이면 그 흐름에 응답을 얹고, 아니면 최대 6초 동안 0.25초마다 다시 시도한다.
local RESPOND_TRIES = 24
local ACTION_LABEL = { yes = "수락", maybe = "미정", no = "거절" }

-- 2.6.8: 응답을 보낸 뒤 실제로 와우 달력에 반영됐는지 다시 읽어서 확인한다.
-- (2.6.5~2.6.7은 「수락 보냄」만 찍고 끝 → 실제로는 반영 안 된 경우가 있었음)
local EXPECT = { yes = "yes", maybe = "maybe", no = "no" }
-- 지금 와우 달력이 이 일정에 대해 들고 있는 내 응답 상태 (못 읽으면 nil)
function M:LiveStatus(e)
  if not (C_Calendar and C_Calendar.GetDayEvent) then return nil end
  local okT = self:CanTouchCalendar()
  if not okT or self.pending or self.scanning then return nil end
  local okF, i = pcall(self.FindIndex, self, e)
  local st
  if okF and i then
    local okE, ev = pcall(C_Calendar.GetDayEvent, 0, e.d, i)
    if okE and type(ev) == "table" then st = num(ev.inviteStatus) end
  end
  self:RestoreMonth()
  return st
end

function M:VerifyResponse(charKey, e, action)
  self.verifyToken = (self.verifyToken or 0) + 1
  local token = self.verifyToken
  local label = ACTION_LABEL[action] or "응답"
  local function check(n)
    if self.verifyToken ~= token then return end
    local st = self:LiveStatus(e)
    if st == nil then
      -- 달력을 지금 못 읽음(다른 작업 중): DB에 저장된 값으로 (다시 읽은 뒤라면)
      local key = self.DetailKey(e)
      local ch = self:DB().chars[charKey]
      for _, x in ipairs((ch and ch.events) or {}) do
        if self.DetailKey(x) == key then st = tonumber(x.status); break end
      end
    end
    local info = st and self.STATUS_INFO[st]
    if info and info[2] == EXPECT[action] then
      NT:Print(label .. " 완료 · 와우 달력에 반영됨 (" .. info[1] .. ")")
      self.forceScan = true; self:RequestScan("action", true)
      return
    end
    if n < 2 then after(4, function() check(n + 1) end); return end   -- 서버가 늦을 수 있어 한 번 더
    if info then
      NT:Print("|cffff7755" .. label .. "이 와우 달력에 반영되지 않았어요 (지금: " .. info[1] .. ") · 한 번 더 누르거나 와우 달력에서 직접 눌러 주세요.|r")
    else
      NT:Print(label .. " 반영 여부를 확인 못 했어요 · 와우 달력에서 확인해 주세요.")
    end
    self.forceScan = true; self:RequestScan("action", true)
  end
  after(2.5, function() check(1) end)
end

-- 2.6.8: 와우 기본 달력의 우클릭 메뉴와 같은 방식(ContextMenu)으로, 버튼을 누른 그 순간에 바로 응답한다.
-- 일정을 열고(OpenEvent) 서버 응답(CALENDAR_OPEN_EVENT)을 기다렸다가 응답하던 방식은 클릭과 떨어져서 반영이 안 될 수 있었다.
function M:RespondDirect(e, action)
  local C = C_Calendar
  if not (C and C.ContextMenuSelectEvent) then return false end
  local fn
  if action == "yes" then
    fn = self:IsSignup(e) and C.ContextMenuEventSignUp or C.ContextMenuInviteAvailable
  elseif action == "maybe" then
    fn = C.ContextMenuInviteTentative
  elseif action == "no" then
    fn = C.ContextMenuInviteDecline
  end
  if type(fn) ~= "function" then return false end
  local okFind, i = pcall(self.FindIndex, self, e)
  if not okFind or not i then self:RestoreMonth(); return false, "missing" end
  local okSel = pcall(C.ContextMenuSelectEvent, 0, e.d, i)
  if not okSel then self:RestoreMonth(); return false end
  local okAct, err = pcall(fn)
  self:RestoreMonth()
  if not okAct then NT:Print("응답 실패: " .. tostring(err)); return false, "error" end
  return true
end

function M:Respond(charKey, e, action)
  local okR, whyR = self:CanRespond(charKey, e)
  if not okR then NT:Print(whyR); return false, "deny" end
  local key = self.DetailKey(e)
  local p = self.pending
  if p and p.key == key then
    if p.opened then
      -- 이미 열려 있는 같은 일정: 바로 응답
      local ok, err = pcall(self.DoAction, self, e, action)
      if not ok then NT:Print("응답 실패: " .. tostring(err)); return false, "error" end
      NT:Print((ACTION_LABEL[action] or "응답") .. " 요청 보냄 · 와우 달력 반영 확인 중…")
      self:VerifyResponse(charKey, e, action)
      return true
    end
    -- 아직 여는 중: 여는 걸 기다리지 않고 지금 바로(클릭한 순간) 응답한다
    if self:RespondDirect(e, action) then
      NT:Print((ACTION_LABEL[action] or "응답") .. " 요청 보냄 · 와우 달력 반영 확인 중…")
      self:VerifyResponse(charKey, e, action)
      return true
    end
    p.action = action   -- 바로 못 하면: 열리면 OnOpenEvent가 응답한다
    p.char = charKey
    return true
  end
  self.respondToken = (self.respondToken or 0) + 1
  local token = self.respondToken
  self.respondHoldUntil = gtime() + RESPOND_TRIES * 0.25 + 3
  local announced = false
  local function try(n)
    if self.respondToken ~= token then return end   -- 그 사이 다른 버튼을 눌렀으면 이전 시도는 버림
    if InCombatLockdown and InCombatLockdown() then NT:Print("전투가 끝난 뒤 다시 눌러 주세요."); return end
    if self:BlizzardCalendarOpen() then self:CloseBlizzardCalendar() end
    local ok, why = self:CanTouchCalendar()
    local busy = (not ok and (why == "pending" or why == "blizzard")) or self.pending ~= nil or self.scanning
    if busy then
      if n >= RESPOND_TRIES then
        NT:Print("달력이 계속 바쁩니다. 잠시 뒤 다시 눌러 주세요." .. (why and (" (" .. tostring(why) .. ")") or ""))
        return
      end
      if not announced then announced = true; NT:Print((ACTION_LABEL[action] or "응답") .. " 보내는 중… (달력 대기)") end
      after(0.25, function() try(n + 1) end)
      return
    end
    -- 2.6.8: 우클릭 메뉴 방식으로 바로 응답 (안 되면 예전 방식 = 일정 열고 응답)
    if self:RespondDirect(e, action) then
      NT:Print((ACTION_LABEL[action] or "응답") .. " 요청 보냄 · 와우 달력 반영 확인 중…")
      self:VerifyResponse(charKey, e, action)
      return
    end
    self:Open(charKey, e, action)
  end
  try(0)
  return true
end

function M:CaptureOpenEvent()
  local p = self.pending
  if not p then return false end
  local info = C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
  local db = self:DB()
  local det = type(db.details[p.key]) == "table" and db.details[p.key] or {}
  if type(info) == "table" then
    det.creator = str(info.creator) or det.creator
    det.title = str(info.title) or det.title
    det.desc = str(info.description) or det.desc
  end
  local list = {}
  local n = num(C_Calendar.GetNumInvites and C_Calendar.GetNumInvites()) or 0
  for i = 1, n do
    local inv = C_Calendar.EventGetInvite(i)
    if type(inv) == "table" then
      local nm = str(inv.name)
      if nm then
        list[#list + 1] = {
          name = nm, class = str(inv.classFilename), level = num(inv.level),
          status = num(inv.inviteStatus), mod = str(inv.modStatus),
        }
      end
    end
  end
  if n > 0 or not det.invites then det.invites = list end
  det.updated = now()
  det.by = p.char
  db.details[p.key] = det
  return true
end

function M:DoAction(e, action)
  if action == "yes" then
    if self:IsSignup(e) then C_Calendar.EventSignUp() else C_Calendar.EventAvailable() end
  elseif action == "maybe" then
    C_Calendar.EventTentative()
  elseif action == "no" then
    C_Calendar.EventDecline()
  end
end

function M:OnOpenEvent()
  local p = self.pending
  if not p then return end
  p.opened = true
  pcall(self.CaptureOpenEvent, self)
  if p.action then
    local ok, err = pcall(self.DoAction, self, p.e, p.action)
    if ok then
      NT:Print((ACTION_LABEL[p.action] or "응답") .. " 요청 보냄 · 와우 달력 반영 확인 중…")
      self:VerifyResponse(p.char or self:CurrentCharKey(), p.e, p.action)
    else
      NT:Print("응답 실패: " .. tostring(err))
    end
    p.action = nil
  end
  -- 참가자 목록은 CALENDAR_UPDATE_INVITE_LIST로 조금 늦게 올 수 있다: 1.5초 더 받는다.
  after(1.5, function()
    if self.pending == p then
      pcall(self.CaptureOpenEvent, self)
      self.pending = nil
      self:RestoreMonth()
      self:NotifyUI()
      self:NextAutoDetail()
    end
  end)
  self:NotifyUI()
end

function M:OnInviteList()
  if self.pending then pcall(self.CaptureOpenEvent, self); self:NotifyUI() end
end

-- 접속한 캐릭의 다가오는 일정 참가자를 몇 개만 미리 읽는다.
function M:QueueAutoDetails()
  local db = self:DB()
  local key = self:CurrentCharKey()
  local ch = key and db.chars[key]
  if not ch then return end
  local nowS = self:TodayStamp()
  local limit = nowS + self.AUTO_DETAIL_DAYS * 24 * 60
  local q = {}
  for _, e in ipairs(ch.events or {}) do
    local s = self.Stamp(e.y, e.m, e.d, e.h, e.mi)
    if s >= nowS - 6 * 60 and s <= limit and self.TYPES[e.ctype] then
      local det = db.details[self.DetailKey(e)]
      if not det or (now() - (det.updated or 0)) > self.DETAIL_FRESH then q[#q + 1] = e end
    end
    if #q >= self.AUTO_DETAIL_MAX then break end
  end
  self.autoQueue = q
  self.autoChar = key
  after(1, function() self:NextAutoDetail() end)
end

function M:NextAutoDetail()
  if self.pending then return end
  -- 2.6.5: 수락/미정/거절을 기다리는 동안에는 자동 참가자 읽기를 쉰다 (응답이 먼저)
  if self.respondHoldUntil and gtime() < self.respondHoldUntil then
    after(1, function() self:NextAutoDetail() end)
    return
  end
  local q = self.autoQueue
  if not q or #q == 0 then self.autoQueue = nil; return end
  if self.autoChar ~= self:CurrentCharKey() then self.autoQueue = nil; return end
  local ok, why = self:CanTouchCalendar()
  if not ok then
    if why ~= "api" then after(5, function() self:NextAutoDetail() end) end
    return
  end
  local e = table.remove(q, 1)
  local started = self:Open(self.autoChar, e, nil, true)
  if not started then after(1.2, function() self:NextAutoDetail() end) end
end

-- ── 다시 읽기 예약 ────────────────────────────────────
function M:RequestScan(reason, force)
  if self.scanning then return end
  local wait = 1
  if not force then
    local gap = self.AUTO_SCAN_GAP - (gtime() - (self.lastScanAt or -999))
    if gap > wait then wait = gap end
  end
  if self.scanQueued then return end
  self.scanQueued = true
  after(wait, function()
    self.scanQueued = false
    if self.pending then self.pendingScan = true; return end
    self:Scan(reason)
  end)
end

function M:NotifyUI()
  local UI = NT.UI
  if UI and UI.frame and UI.frame:IsShown() and UI.currentPage == "CAL" then UI:RefreshVisiblePage() end
end

function M:StatusLine()
  local db = self:DB()
  local chars = self:Chars()
  local cur = self:CurrentCharKey()
  local curRec = cur and db.chars[cur]
  local when = curRec and curRec.synced and (now() - curRec.synced) or nil
  return string.format("계정 달력 %s · 캐릭 %d · 이 캐릭 초대 %d · 마지막 동기화 %s%s",
    db.settings.enabled and "ON" or "OFF", #chars, curRec and #(curRec.events or {}) or 0,
    when and (math.floor(when / 60) .. "분 전") or "없음",
    self.lastBlock and (" · 대기 사유 " .. tostring(self.lastBlock)) or "")
end

-- ── 웹 로그 주소 ──────────────────────────────────────
-- 한국 서버 이름 → 영문 주소 (공백 없는 이름 기준). 없는 서버는 소문자·하이픈으로 만든다.
M.REALM_SLUGS = {
  ["가로나"] = "garona", ["굴단"] = "guldan", ["노르간논"] = "norgannon", ["달라란"] = "dalaran",
  ["데스윙"] = "deathwing", ["듀로탄"] = "durotan", ["렉사르"] = "rexxar", ["말리고스"] = "malygos",
  ["말퓨리온"] = "malfurion", ["메디브"] = "medivh", ["불타는군단"] = "burning-legion", ["블랙무어"] = "blackmoore",
  ["세나리우스"] = "cenarius", ["스톰레이지"] = "stormrage", ["아즈샤라"] = "azshara", ["알렉스트라자"] = "alexstrasza",
  ["와일드해머"] = "wildhammer", ["윈드러너"] = "windrunner", ["줄진"] = "zuljin", ["하이잘"] = "hyjal",
  ["헬스크림"] = "hellscream",
}

function M:RegionSlug()
  local r = type(GetCurrentRegion) == "function" and GetCurrentRegion() or 3
  return ({ [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" })[r] or "kr"
end

function M:RealmSlug(realm)
  realm = tostring(realm or ""):gsub("%s+", "")
  if realm == "" or realm == "?" then
    realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
  end
  if self.REALM_SLUGS[realm] then return self.REALM_SLUGS[realm] end
  local s = realm:gsub("(%l)(%u)", "%1-%2"):gsub("'", ""):lower()
  return s
end

function M.URLEncode(s)
  return (tostring(s or ""):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

-- "이름" 또는 "이름-서버"
function M:SplitName(full, defaultRealm)
  full = tostring(full or "")
  local n, r = full:match("^([^%-]+)%-(.+)$")
  if n then return n, r end
  return full, defaultRealm
end

function M:CharacterURL(full, defaultRealm)
  local n, r = self:SplitName(full, defaultRealm)
  return string.format("https://www.warcraftlogs.com/character/%s/%s/%s", self:RegionSlug(), self:RealmSlug(r), self.URLEncode(n))
end

function M:GuildURL(guild, realm)
  return string.format("https://www.warcraftlogs.com/guild/%s/%s/%s", self:RegionSlug(), self:RealmSlug(realm), self.URLEncode(guild))
end

-- 일정의 로그 주소: 길드 일정이면 길드 로그, 아니면 초대한 사람(만든 사람) 캐릭 로그.
function M:EventURL(charKey, e)
  local db = self:DB()
  local ch = db.chars[charKey] or {}
  if e.ctype == "GUILD_EVENT" and ch.guild then return self:GuildURL(ch.guild, ch.realm), "길드 로그" end
  local det = db.details[self.DetailKey(e)]
  local who = (det and det.creator) or e.by
  if who then return self:CharacterURL(who, ch.realm), who .. " 로그" end
  return nil
end

-- ── 이벤트 연결 ───────────────────────────────────────
local events = NT.EventDispatcher and NT.EventDispatcher:CreateProxy("AccountCalendar")
M.events = events
if events then
  for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_INVITE_LIST",
    "CALENDAR_OPEN_EVENT", "CALENDAR_ACTION_PENDING", "CALENDAR_UPDATE_PENDING_INVITES", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do
    pcall(events.RegisterEvent, events, ev)
  end
  events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
      if M.enteredOnce then return end
      M.enteredOnce = true
      if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
      after(4, function() M:RequestScan("login", true) end)
    elseif event == "CALENDAR_OPEN_EVENT" then
      M:OnOpenEvent()
    elseif event == "CALENDAR_UPDATE_INVITE_LIST" then
      M:OnInviteList()
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" or event == "CALENDAR_UPDATE_PENDING_INVITES" then
      if M.scanning or M.pending or not M.enteredOnce then return end
      local t = gtime()
      if event == "CALENDAR_UPDATE_EVENT_LIST" and not M.forceScan then
        if M.lastTouch and t - M.lastTouch < 3 then return end      -- 내가 달을 옮겨서 생긴 갱신
        if M.quietUntil and t < M.quietUntil then return end
      end
      M:RequestScan(event == "CALENDAR_UPDATE_PENDING_INVITES" and "invite" or "update", M.forceScan)
      M.forceScan = nil
    elseif event == "CALENDAR_ACTION_PENDING" or event == "PLAYER_REGEN_ENABLED" then
      if M.pendingScan and M.enteredOnce then M:RequestScan("retry", true) end
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_Calendar" then
      local f = _G.CalendarFrame
      if f and f.HookScript and not M.hookedFrame then
        M.hookedFrame = true
        f:HookScript("OnHide", function() M:RequestScan("blizzard", true) end)
      end
    end
  end)
end
