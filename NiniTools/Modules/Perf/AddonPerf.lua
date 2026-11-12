local ADDON_NAME, NT = ...

-- ============================================================================
-- 보스 풀 애드온 부하 기록 (NiniTools 2.8.8)
--
-- 목적
--   보스 풀마다 「어떤 애드온이 얼마나 무거웠나」를 SavedVariables에 남긴다.
--   화면이 뚝뚝 끊긴 판이 어떤 애드온 때문인지, 다음 레이드 WTF만 보면 알 수 있게 한다.
--   (11/12 울라텍 6·7트 암살: 내 디버프 동시 90개 · 잠행 판의 3배 → 이름표 애드온 의심)
--
-- 재는 것 (게임 기본 애드온 측정 C_AddOnProfiler · 11.1+ · 따로 켤 필요 없음)
--   · 보스 전투 평균 시간(EncounterAverageTime, ms/프레임) 상위 애드온
--   · 그 풀 동안 한 프레임에 50ms · 100ms 넘게 쓴 횟수(화면 끊김의 직접 원인) — 풀 전/후 누적값 차이
--   · 전체 애드온 합계 · 게임 전체 평균 · 그 풀의 내 전문화
--
-- 원칙
--   1) 읽기만 한다. 다른 애드온을 끄거나 바꾸지 않는다.
--   2) 전투 중에는 아무것도 안 읽는다 (보스 전투 중 측정 함수가 막힐 수 있음).
--      풀 전 기준값은 전투 밖에서(레디체크 · 풀 카운트 · 전투 끝) 잡고, 결과는 전투가 끝난 뒤 읽는다.
--   3) 측정값이 비밀 값(secret)이거나 함수가 없으면 그 풀은 「측정 못 함」으로 적고 넘어간다.
--   4) 기록은 최근 MAX_PULLS 개만. 이 PC 안에만 저장한다.
-- ============================================================================

local M = {}
NT.AddonPerf = M

M.SCHEMA = 1
M.MAX_PULLS = 300      -- 주 2회 레이드 × 수십 풀 기준 몇 주 분량
M.TOP_AVG = 8          -- 보스 전투 평균 상위 몇 개를 적을지
M.TOP_SPIKE = 8        -- 50ms 넘은 횟수 상위 몇 개를 적을지
M.ANNOUNCE_N50 = 5     -- 한 애드온이 한 풀에 50ms 넘은 프레임이 이만큼이면 채팅에 한 줄

local METRIC = (type(Enum) == "table" and type(Enum.AddOnProfilerMetric) == "table") and Enum.AddOnProfilerMetric or {
  SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, LastTime = 3, PeakTime = 4,
  CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7, CountTimeOver50Ms = 8,
  CountTimeOver100Ms = 9, CountTimeOver500Ms = 10, CountTimeOver1000Ms = 11,
}
local COUNT_KEYS = { n5 = "CountTimeOver5Ms", n50 = "CountTimeOver50Ms", n100 = "CountTimeOver100Ms" }

local function safeValue(v)
  if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
  return v
end

local function stamp()
  return type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or ""
end

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function round(v, n)
  if type(v) ~= "number" then return nil end
  local m = 10 ^ (n or 2)
  return math.floor(v * m + 0.5) / m
end

local function db()
  if type(NT.BindModuleDB) == "function" then NT:BindModuleDB() end
  NiniToolsDB = type(NiniToolsDB) == "table" and NiniToolsDB or {}
  NiniToolsDB.modules = type(NiniToolsDB.modules) == "table" and NiniToolsDB.modules or {}
  local d = NiniToolsDB.modules.addonPerf
  if type(d) ~= "table" then
    d = {}
    NiniToolsDB.modules.addonPerf = d
  end
  if d.enabled == nil then d.enabled = true end      -- 이 PC 안 기록 · 가벼움 → 기본 켜짐
  if d.announce == nil then d.announce = true end
  d.schema = M.SCHEMA
  d.pulls = type(d.pulls) == "table" and d.pulls or {}
  return d
end
M.GetDB = db

local function charKey()
  if type(UnitFullName) ~= "function" then return nil end
  local ok, name, realm = pcall(UnitFullName, "player")
  if not ok or not name or name == "" then return nil end
  if not realm or realm == "" then
    realm = (type(GetNormalizedRealmName) == "function" and GetNormalizedRealmName()) or nil
  end
  return realm and (name .. "-" .. realm) or name
end

local function specID()
  local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if type(getSpec) ~= "function" or type(getInfo) ~= "function" then return nil end
  local ok, idx = pcall(getSpec)
  if not ok or not idx then return nil end
  local ok2, id = pcall(getInfo, idx)
  return ok2 and tonumber(safeValue(id)) or nil
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() or false
end

function M:Available()
  return type(C_AddOnProfiler) == "table" and type(C_AddOnProfiler.GetAddOnMetric) == "function"
end

-- 지금 켜져 있는 애드온 이름 (측정은 사용자 애드온만 된다)
local loaded
local function loadedAddons()
  if loaded then return loaded end
  local list = {}
  local num = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if type(num) == "function" and type(info) == "function" and type(isLoaded) == "function" then
    for i = 1, (num() or 0) do
      local name = info(i)
      if type(name) == "string" and name ~= "" and isLoaded(name) then list[#list + 1] = name end
    end
  end
  loaded = list
  return list
end

local function metric(name, key)
  local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, name, METRIC[key])
  v = ok and safeValue(v) or nil
  return type(v) == "number" and v or nil
end

-- 풀 전 기준값: 애드온별 누적 「n ms 넘은 프레임 수」 (리로드 후부터 셈)
local base       -- { [addon] = { n5=, n50=, n100= } }
local baseAt
function M:Snapshot(reason)
  if not self:Available() or inCombat() then return false end
  local snap = {}
  for _, name in ipairs(loadedAddons()) do
    local row = {}
    for k, key in pairs(COUNT_KEYS) do row[k] = metric(name, key) end
    snap[name] = row
  end
  base, baseAt = snap, now()
  M.baseReason = reason
  return true
end

local pending    -- 보스 풀 정보 (ENCOUNTER_START ~ 전투 끝까지)

function M:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
  if not db().enabled then return end
  pending = {
    at = stamp(),
    enc = tonumber(safeValue(encounterID)),
    name = safeValue(encounterName),
    diff = tonumber(safeValue(difficultyID)),
    size = tonumber(safeValue(groupSize)),
    spec = specID(),
    char = charKey(),
    t0 = now(),
    baseAge = baseAt and round(now() - baseAt, 0) or nil,   -- 기준값을 잡은 지 몇 초 (쓰레기 몹 구간이 섞였는지)
  }
end

function M:OnEncounterEnd(encounterID, _, _, _, success)
  if not pending then return end
  pending.success = (safeValue(success) == 1 or safeValue(success) == true) and true or false
  pending.dur = round(now() - (pending.t0 or now()), 1)
  pending.ended = true
  if not inCombat() then self:Finish() end   -- 이미 전투 밖이면 바로 (아니면 PLAYER_REGEN_ENABLED 때)
end

local function topBy(rows, field, k)
  local list = {}
  for _, r in ipairs(rows) do
    if (r[field] or 0) > 0 then list[#list + 1] = r end
  end
  table.sort(list, function(a, b) return (a[field] or 0) > (b[field] or 0) end)
  for i = #list, k + 1, -1 do list[i] = nil end
  return list
end

function M:Finish()
  local p = pending
  if not p or not p.ended then return end
  pending = nil
  local d = db()
  p.t0, p.ended = nil, nil
  if not self:Available() then
    p.error = "측정 함수 없음"
  else
    local rows = {}
    for _, name in ipairs(loadedAddons()) do
      local r = { a = name, avg = round(metric(name, "EncounterAverageTime"), 3), peak = round(metric(name, "PeakTime"), 1) }
      local b = base and base[name] or {}
      for k, key in pairs(COUNT_KEYS) do
        local v = metric(name, key)
        if v then
          local was = b[k] or 0
          r[k] = (v >= was) and (v - was) or v   -- 리로드로 누적이 처음부터면 지금 값
        end
      end
      if r.avg or (r.n50 or 0) > 0 or (r.n5 or 0) > 0 then rows[#rows + 1] = r end
    end
    if #rows == 0 then
      p.error = "측정값 없음 (비밀 값이거나 막힘)"
    end
    local keep, seen = {}, {}
    for _, list in ipairs({ topBy(rows, "avg", M.TOP_AVG), topBy(rows, "n50", M.TOP_SPIKE), topBy(rows, "n5", 3) }) do
      for _, r in ipairs(list) do
        if not seen[r.a] then
          seen[r.a] = true
          keep[#keep + 1] = r
        end
      end
    end
    table.sort(keep, function(a, b) return (a.avg or 0) > (b.avg or 0) end)
    p.addons = keep
    p.hadBase = base ~= nil
    local okA, all = pcall(C_AddOnProfiler.GetOverallMetric, METRIC.EncounterAverageTime)
    p.allAvg = okA and round(safeValue(all), 3) or nil
    if type(C_AddOnProfiler.GetApplicationMetric) == "function" then
      local okB, app = pcall(C_AddOnProfiler.GetApplicationMetric, METRIC.EncounterAverageTime)
      p.appAvg = okB and round(safeValue(app), 3) or nil
    end
  end
  table.insert(d.pulls, p)
  while #d.pulls > M.MAX_PULLS do table.remove(d.pulls, 1) end
  if d.announce and p.addons then
    local worst
    for _, r in ipairs(p.addons) do
      if (r.n50 or 0) >= M.ANNOUNCE_N50 and (not worst or r.n50 > worst.n50) then worst = r end
    end
    if worst and NT.Print then
      NT:Print(string.format("애드온 부하: %s 50ms 넘은 프레임 %d번 (보스 전투 평균 %.1fms) · /nini perf",
        worst.a, worst.n50, worst.avg or 0))
    end
  end
  self:Snapshot("end")   -- 다음 풀 기준값 (전투 밖)
end

local function fmtPull(p)
  local parts = {}
  for i, r in ipairs(p.addons or {}) do
    if i > 3 then break end
    parts[#parts + 1] = string.format("%s %.1fms%s", r.a, r.avg or 0, (r.n50 or 0) > 0 and (" · 50ms+ " .. r.n50) or "")
  end
  return string.format("%s %s(%s) %s %ss · 애드온 합계 %.1fms · %s", tostring(p.at), tostring(p.name or p.enc),
    tostring(p.diff), p.success and "킬" or "전멸", tostring(p.dur or "?"), p.allAvg or 0,
    p.error or (#parts > 0 and table.concat(parts, " · ") or "부하 없음"))
end

function M:Status()
  local d = db()
  NT:Print(string.format("애드온 부하 기록 %s · 측정 %s · 풀 %d개 · 채팅 알림 %s",
    d.enabled and "|cff59e58c켜짐|r" or "|cff999999꺼짐|r", self:Available() and "가능" or "|cffff6060불가|r",
    #d.pulls, d.announce and "켜짐" or "꺼짐"))
  for i = math.max(1, #d.pulls - 2), #d.pulls do
    NT:Print(fmtPull(d.pulls[i]))
  end
end

function M:Slash(arg)
  arg = tostring(arg or ""):lower():match("^%s*(.-)%s*$")
  local d = db()
  if arg == "on" or arg == "켜기" then
    d.enabled = true
    self:Snapshot("on")
    NT:Print("보스 풀 애드온 부하 기록을 켰습니다. (/nini perf)")
  elseif arg == "off" or arg == "끄기" then
    d.enabled = false
    pending = nil
    NT:Print("보스 풀 애드온 부하 기록을 껐습니다. 저장된 기록은 그대로입니다. (지우기: /nini perf clear)")
  elseif arg == "quiet" or arg == "조용히" then
    d.announce = not d.announce
    NT:Print("풀이 끝날 때 부하 알림: " .. (d.announce and "켜짐" or "꺼짐"))
  elseif arg == "clear" or arg == "지우기" then
    d.pulls = {}
    NT:Print("저장된 애드온 부하 기록을 모두 지웠습니다.")
  else
    self:Status()
    NT:Print("명령: /nini perf on · off · quiet(알림 켜기/끄기) · clear")
  end
end

local runner = NT.EventDispatcher and NT.EventDispatcher:CreateProxy("AddonPerf")
if runner then
  for _, ev in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "ENCOUNTER_START", "ENCOUNTER_END",
                        "PLAYER_REGEN_ENABLED", "READY_CHECK", "START_PLAYER_COUNTDOWN" }) do
    runner:RegisterEvent(ev)
  end
  runner:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
      loaded = nil   -- 나중에 켜진 애드온도 목록에 넣는다
      return
    end
    if not db().enabled then return end
    local ok, err = true, nil
    if event == "ENCOUNTER_START" then
      ok, err = pcall(M.OnEncounterStart, M, ...)
    elseif event == "ENCOUNTER_END" then
      ok, err = pcall(M.OnEncounterEnd, M, ...)
    elseif event == "PLAYER_REGEN_ENABLED" then
      if pending and pending.ended then
        ok, err = pcall(M.Finish, M)
      elseif not pending then
        ok, err = pcall(M.Snapshot, M, "regen")
      end
    elseif not pending then   -- PLAYER_LOGIN · READY_CHECK · START_PLAYER_COUNTDOWN: 풀 전 기준값
      ok, err = pcall(M.Snapshot, M, event)
    end
    if ok == false and NT.Print then NT:Print("애드온 부하 기록 오류: " .. tostring(err)) end
  end)
end
