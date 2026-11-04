local ADDON_NAME, NT = ...

-- ============================================================================
-- 공대 메모 캡처 (NiniTools 2.5.3)
--
-- 목적
--   공대장이 NSRT로 보낸 공유 메모(차단 순번 intstart~intend, 단두대 조 등)와
--   MRT 메모를, 받은 시각과 보스 풀 시각에 맞춰 SavedVariables에 남긴다.
--   분석기(GOLD)가 「그 트라이 때 실제로 켜져 있던 메모」로 차단·조 판정을 하게 하려는 것.
--
-- 원칙
--   1) 기본값은 꺼짐. /nini memo on 으로 켠 사람만 저장한다 (길드 배포판이라 다른 사람 메모를 모으지 않음).
--   2) 읽기만 한다. NSRT·MRT 메모를 바꾸거나 다시 보내지 않는다.
--   3) 같은 메모는 한 번만 저장(해시)하고, 기록에는 해시만 남긴다. 개수 제한으로 오래된 것부터 지운다.
--   4) 풀(ENCOUNTER_START)마다 「지금 켜져 있는 메모」를 같이 적는다. 메모를 언제 받았든 풀 기준으로 맞출 수 있다.
--   5) 전투 중 무거운 일은 하지 않는다 (해시 계산 한 번, 표 추가 한 번).
-- ============================================================================

local M = {}
NT.NoteCapture = M

M.SCHEMA = 1
M.MAX_NOTES = 80      -- 서로 다른 메모 텍스트 최대 개수
M.MAX_EVENTS = 600    -- 받은/풀/종료 기록 최대 개수 (주 2회 레이드 × 수십 풀 기준 몇 주 분량)

local function safeValue(v)
  if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
  return v
end

local function nowEpoch()
  return type(time) == "function" and time() or 0
end

local function stamp()
  -- 전투 로그와 같은 「이 PC 시계」 기준. 분석기는 이 값으로 트라이 시작 시각과 맞춘다.
  return type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or ""
end

local function db()
  if type(NT.BindModuleDB) == "function" then NT:BindModuleDB() end
  NiniToolsDB = type(NiniToolsDB) == "table" and NiniToolsDB or {}
  NiniToolsDB.modules = type(NiniToolsDB.modules) == "table" and NiniToolsDB.modules or {}
  local d = NiniToolsDB.modules.noteCapture
  if type(d) ~= "table" then
    d = {}
    NiniToolsDB.modules.noteCapture = d
  end
  if d.enabled == nil then d.enabled = false end
  d.schema = M.SCHEMA
  d.notes = type(d.notes) == "table" and d.notes or {}
  d.events = type(d.events) == "table" and d.events or {}
  return d
end
M.GetDB = db

-- 32비트 해시 (Lua 5.1, 비트 연산 없이). 같은 텍스트면 같은 값.
local function hashText(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return string.format("%08x", h)
end
M.HashText = hashText

local function charKey()
  if type(UnitFullName) ~= "function" then return nil end
  local ok, name, realm = pcall(UnitFullName, "player")
  if not ok or not name or name == "" then return nil end
  if not realm or realm == "" then
    realm = (type(GetNormalizedRealmName) == "function" and GetNormalizedRealmName()) or nil
  end
  return realm and (name .. "-" .. realm) or name
end

local function leaderName()
  if type(IsInRaid) ~= "function" or not IsInRaid() or type(GetRaidRosterInfo) ~= "function" then return nil end
  for i = 1, 40 do
    local ok, name, rank = pcall(GetRaidRosterInfo, i)
    if ok and name and rank == 2 then return safeValue(name) end
  end
  return nil
end

-- 지금 켜져 있는 메모 텍스트 (없으면 nil)
local function nsrtShared(encID)
  local api = _G.NSAPI
  if type(api) ~= "table" or type(api.GetReminderString) ~= "function" then return nil end
  local ok, _, shared = pcall(api.GetReminderString, api, encID)
  if ok and type(shared) == "string" and shared ~= "" then return shared end
  return nil
end

local function mrtNote()
  local v = _G.VMRT
  local text = type(v) == "table" and type(v.Note) == "table" and v.Note.Text1 or nil
  if type(text) == "string" and text ~= "" then return text end
  return nil
end
M.CurrentTexts = function(encID) return nsrtShared(encID), mrtNote() end

local function referencedKeys(d)
  local used = {}
  for _, e in ipairs(d.events) do
    if e.nsrt then used[e.nsrt] = true end
    if e.mrt then used[e.mrt] = true end
  end
  return used
end

local function prune(d)
  while #d.events > M.MAX_EVENTS do table.remove(d.events, 1) end
  local count = 0
  for _ in pairs(d.notes) do count = count + 1 end
  if count <= M.MAX_NOTES then return end
  local used = referencedKeys(d)
  local candidates = {}
  for k, n in pairs(d.notes) do
    if not used[k] then candidates[#candidates + 1] = { k = k, t = tonumber(n.lastSeen) or 0 } end
  end
  table.sort(candidates, function(a, b) return a.t < b.t end)
  for _, c in ipairs(candidates) do
    if count <= M.MAX_NOTES then break end
    d.notes[c.k] = nil
    count = count - 1
  end
end

local function storeNote(d, kind, text)
  if type(text) ~= "string" or text == "" then return nil end
  local key = kind .. ":" .. hashText(text) .. ":" .. #text
  local n = d.notes[key]
  local t = nowEpoch()
  if n then
    n.lastSeen = t
  else
    d.notes[key] = { kind = kind, text = text, firstSeen = t, firstSeenAt = stamp(), lastSeen = t, len = #text }
  end
  return key
end

local function lastEventOfKind(d, kind)
  for i = #d.events, 1, -1 do
    if d.events[i].kind == kind then return d.events[i] end
  end
  return nil
end

local function addEvent(d, e)
  e.t = nowEpoch()
  e.at = stamp()
  d.events[#d.events + 1] = e
  prune(d)
  return e
end

-- 공대장이 NSRT 공유 메모를 보냈을 때 (NSRT_REMINDER_CHANGED)
function M:OnSharedChanged(shared)
  local d = db()
  if not d.enabled then return end
  local key = storeNote(d, "nsrt", shared)
  if not key then return end
  local last = lastEventOfKind(d, "received")
  if last and last.nsrt == key then return end   -- 같은 메모를 다시 받은 것은 한 번만
  addEvent(d, { kind = "received", nsrt = key, leader = leaderName(), char = charKey() })
end

-- 보스 풀 시작: 이 풀에 켜져 있던 메모를 같이 적는다.
function M:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
  local d = db()
  if not d.enabled then return end
  encounterID = tonumber(safeValue(encounterID))
  local shared = nsrtShared(encounterID)
  local mrt = mrtNote()
  addEvent(d, {
    kind = "pull",
    enc = encounterID,
    name = safeValue(encounterName),
    diff = tonumber(safeValue(difficultyID)),
    size = tonumber(safeValue(groupSize)),
    nsrt = storeNote(d, "nsrt", shared),
    mrt = storeNote(d, "mrt", mrt),
    char = charKey(),
  })
end

function M:OnEncounterEnd(encounterID, _, difficultyID, _, success)
  local d = db()
  if not d.enabled then return end
  addEvent(d, {
    kind = "end",
    enc = tonumber(safeValue(encounterID)),
    diff = tonumber(safeValue(difficultyID)),
    success = (safeValue(success) == 1 or safeValue(success) == true) and true or false,
  })
end

local registered = false
function M:RegisterNSRT()
  if registered then return true end
  local api = _G.NSAPI
  if type(api) ~= "table" or type(api.RegisterCallback) ~= "function" then return false end
  local ok = pcall(api.RegisterCallback, "NiniTools_NoteCapture", "NSRT_REMINDER_CHANGED", function(_, _, shared)
    local okCall, err = pcall(M.OnSharedChanged, M, shared)
    if not okCall and NT.Print then NT:Print("메모 캡처 오류: " .. tostring(err)) end
  end)
  registered = ok and true or false
  return registered
end

function M:Status()
  local d = db()
  local notes, pulls, recv = 0, 0, 0
  for _ in pairs(d.notes) do notes = notes + 1 end
  local lastPull
  for _, e in ipairs(d.events) do
    if e.kind == "pull" then pulls = pulls + 1; lastPull = e end
    if e.kind == "received" then recv = recv + 1 end
  end
  local api = registered and "NSRT 연결됨" or ((type(_G.NSAPI) == "table") and "NSRT 있음(연결 대기)" or "NSRT 없음")
  NT:Print(string.format("메모 캡처 %s · %s · 메모 %d개 · 받은 기록 %d · 풀 기록 %d",
    d.enabled and "|cff59e58c켜짐|r" or "|cff999999꺼짐|r", api, notes, recv, pulls))
  if lastPull then
    local n = lastPull.nsrt and d.notes[lastPull.nsrt]
    NT:Print(string.format("마지막 풀 %s · %s(%s) · NSRT 메모 %s",
      tostring(lastPull.at), tostring(lastPull.name or lastPull.enc), tostring(lastPull.diff),
      n and (tostring(n.len) .. "자") or "없음"))
  end
  local shared = nsrtShared()
  NT:Print("지금 켜진 NSRT 공유 메모: " .. (shared and (#shared .. "자") or "없음") ..
    " · MRT 메모: " .. (mrtNote() and "있음" or "없음"))
end

function M:Slash(arg)
  arg = tostring(arg or ""):lower():match("^%s*(.-)%s*$")
  local d = db()
  if arg == "on" or arg == "켜기" then
    d.enabled = true
    self:RegisterNSRT()
    -- 켜는 순간 지금 메모도 한 번 남긴다 (이미 받은 메모를 놓치지 않게).
    self:OnSharedChanged(nsrtShared())
    NT:Print("공대 메모 캡처를 켰습니다. 풀마다 켜져 있던 메모가 저장됩니다. (/nini memo status)")
  elseif arg == "off" or arg == "끄기" then
    d.enabled = false
    NT:Print("공대 메모 캡처를 껐습니다. 저장된 기록은 그대로입니다. (지우기: /nini memo clear)")
  elseif arg == "clear" or arg == "지우기" then
    d.notes = {}
    d.events = {}
    NT:Print("저장된 공대 메모 기록을 모두 지웠습니다.")
  else
    self:Status()
    NT:Print("명령: /nini memo on · off · status · clear")
  end
end

local runner = NT.EventDispatcher and NT.EventDispatcher:CreateProxy("NoteCapture")
if runner then
  runner:RegisterEvent("PLAYER_LOGIN")
  runner:RegisterEvent("ENCOUNTER_START")
  runner:RegisterEvent("ENCOUNTER_END")
  runner:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
      M:RegisterNSRT()
      return
    end
    if not db().enabled then return end
    if not registered then M:RegisterNSRT() end
    local ok, err
    if event == "ENCOUNTER_START" then
      ok, err = pcall(M.OnEncounterStart, M, ...)
    elseif event == "ENCOUNTER_END" then
      ok, err = pcall(M.OnEncounterEnd, M, ...)
    end
    if ok == false and NT.Print then NT:Print("메모 캡처 오류: " .. tostring(err)) end
  end)
end
