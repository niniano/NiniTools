local ADDON_NAME, NT = ...

-- ============================================================================
-- Lorrgs → NSRT 개인메모 스마트 임포터
--
-- 원칙
--   1) 입력은 Lorrgs에서 복사한 NSRT 메모 1개.
--   2) EncounterID / Name / Difficulty는 입력 헤더에서 자동 판별.
--   3) 잠행(121471) = tag:261, 암살(360194) = tag:259를 우선 감지.
--      기준 스킬이 없으면 모든 직업 공통으로 현재 전문화 ID를 tag로 사용한다.
--      잠행/암살 기준 스킬이 동시에 있으면 중단한다.
--   4) 기존 tag만 제거/교체하고 ph:를 포함한 나머지 필드는 원문 그대로 보존.
--   5) EncounterID + 정규화 난이도ID(14/15/16)로 병합.
--   6) NiniTools가 자기 매핑으로 만든 [Nini] 메모만 수정. 다른 NSRT 메모는 미접촉.
--   7) 표시/타이머/TTS/페이즈 전환은 전부 NSRT 담당.
--
-- NSRT 저장은 NSRTAutoReminders와 같은 직접 쓰기 경로를 사용한다.
--   NSRT.PersonalReminders[noteName] = mergedNote
-- 활성 포인터는 임포트 시 억지로 바꾸지 않고, 레이드 컨텍스트에서 실제 난이도를
-- 알 수 있을 때 NiniTools가 잠시 바꾼다. 레이드 이탈/로그아웃 시 원래 포인터 복원.
-- ============================================================================

local M = {}
NT.NSRTImport = M

local NOTE_PREFIX = "[Nini] "

local SPEC_SIGNATURE = {
  [121471] = { tag = "261", label = "잠행" }, -- 어둠의 칼날
  [360194] = { tag = "259", label = "암살" }, -- 죽음표식
}

local SPEC_BY_TAG = {
  ["261"] = "잠행",
  ["259"] = "암살",
}

local function safeValue(v)
  if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
  return v
end

local function currentSpecInfo()
  if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
    return nil, nil
  end
  local okIndex, specIndex = pcall(GetSpecialization)
  specIndex = okIndex and safeValue(specIndex) or nil
  if not specIndex then return nil, nil end

  local ok, specID, specName = pcall(GetSpecializationInfo, specIndex)
  specID = ok and safeValue(specID) or nil
  specName = ok and safeValue(specName) or nil
  specID = tonumber(specID)
  if not specID then return nil, nil end
  return specID, type(specName) == "string" and specName or nil
end

local function specLabelByTag(tag)
  tag = tostring(tag or "")
  if SPEC_BY_TAG[tag] then return SPEC_BY_TAG[tag] end

  local specID = tonumber(tag)
  if specID and type(GetSpecializationInfoByID) == "function" then
    local ok, _, specName = pcall(GetSpecializationInfoByID, specID)
    specName = ok and safeValue(specName) or nil
    if type(specName) == "string" and specName ~= "" then return specName end
  end
  return tag
end

local DIFF_LABEL = {
  [14] = "일반",
  [15] = "영웅",
  [16] = "신화",
}

local DIFF_CANONICAL = {
  [14] = "Normal",
  [15] = "Heroic",
  [16] = "Mythic",
}

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- RC2 Timeline.lua에서 검증했던 난이도 정규화 규칙을 그대로 이식.
local function normalizeDifficulty(v)
  local n = tonumber(v)
  if n == 14 or n == 15 or n == 16 then return n end
  local s = trim(v):lower()
  if s == "" then return nil end
  if s:find("신화", 1, true) or s:find("mythic", 1, true) then return 16 end
  if s:find("영웅", 1, true) or s:find("heroic", 1, true) then return 15 end
  if s:find("일반", 1, true) or s:find("normal", 1, true) then return 14 end
  return nil
end
M.NormalizeDifficulty = normalizeDifficulty

local function charKey()
  if not UnitFullName then return nil end
  local name, realm = UnitFullName("player")
  if not name or name == "" then return nil end
  if not realm or realm == "" then
    realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or nil
  end
  return realm and (name .. "-" .. realm) or nil
end

local function cleanBossName(name)
  name = trim(name)
  if name == "" then return name end
  local suffixes = {
    "%s*%-%s*[Mm]ythic%s*$",
    "%s*%-%s*[Hh]eroic%s*$",
    "%s*%-%s*[Nn]ormal%s*$",
    "%s*%-%s*신화%s*$",
    "%s*%-%s*영웅%s*$",
    "%s*%-%s*일반%s*$",
  }
  for _, pattern in ipairs(suffixes) do
    name = name:gsub(pattern, "")
  end
  return trim(name)
end

local function lineHasTag(line, wanted)
  local tagText = line and line:match("tag:%s*([^;]+)")
  if not tagText then return false end
  wanted = tostring(wanted)
  for token in tagText:gmatch("(%S+)") do
    if trim(token) == wanted then return true end
  end
  return false
end

local function findLineTag(line)
  local tagText = line and line:match("tag:%s*([^;]+)")
  if not tagText then return nil end
  tagText = trim(tagText)
  if tagText == "" then return nil end
  -- NiniTools 생성 메모는 단일 태그를 쓰지만, 사람이 손댄 경우도 고려해서
  -- 첫 번째 알려진 태그를 상태 메시지용으로만 골라낸다.
  for token in tagText:gmatch("(%S+)") do
    token = trim(token)
    if SPEC_BY_TAG[token] then return token end
  end
  return tagText
end

-- 원문 라인의 기존 tag를 모두 빼고 새 tag 하나만 맨 앞에 붙인다.
-- ph:2.5, TTSTimer, dur, DisplayType, sound 등 나머지 필드는 손대지 않는다.
local function retagReminderLine(line, tag)
  local fields = {}
  for field in tostring(line or ""):gmatch("([^;]+)") do
    field = trim(field)
    if field ~= "" and not field:lower():match("^tag%s*:") then
      fields[#fields + 1] = field
    end
  end
  table.insert(fields, 1, "tag:" .. tostring(tag))
  return table.concat(fields, ";") .. ";"
end

local function isReminderLine(line)
  line = tostring(line or "")
  if not line:find("time:", 1, true) then return false end
  return line:find("spellid:", 1, true) ~= nil or line:find("text:", 1, true) ~= nil
end

-- ---------------------------------------------------------------------------
-- DB / 소유권
-- ---------------------------------------------------------------------------

local function migrateOldMap(db)
  if db.schemaVersion == 2 then return end

  local old = type(db.map) == "table" and db.map or {}
  local newMap = {}

  local function put(encounterID, diff, noteName)
    encounterID = tonumber(encounterID)
    diff = normalizeDifficulty(diff)
    if not encounterID or not diff or type(noteName) ~= "string" or noteName == "" then return end
    newMap[encounterID] = newMap[encounterID] or {}
    if not newMap[encounterID][diff] then
      newMap[encounterID][diff] = noteName
    end
  end

  for k, v in pairs(old) do
    local enc = tonumber(k)
    if enc and type(v) == "table" then
      -- 새 형식에 가까운 map[encounterID][difficulty] = noteName
      for diff, noteName in pairs(v) do put(enc, diff, noteName) end
    elseif type(v) == "table" then
      -- 이전 실험판 map[charKey][encounterID][difficulty] = noteName
      for oldEnc, diffs in pairs(v) do
        if type(diffs) == "table" then
          for diff, noteName in pairs(diffs) do put(oldEnc, diff, noteName) end
        end
      end
    end
  end

  db.map = newMap
  db.schemaVersion = 2
end

function M:GetDB()
  NT:BindModuleDB()
  NiniToolsDB.modules.nsrt = type(NiniToolsDB.modules.nsrt) == "table" and NiniToolsDB.modules.nsrt or {}
  local db = NiniToolsDB.modules.nsrt
  db.map = type(db.map) == "table" and db.map or {}
  db.overrides = type(db.overrides) == "table" and db.overrides or {}
  migrateOldMap(db)
  return db
end

local function isMappedName(db, noteName)
  if type(noteName) ~= "string" then return false end
  for _, byDiff in pairs(db.map or {}) do
    if type(byDiff) == "table" then
      for _, mapped in pairs(byDiff) do
        if mapped == noteName then return true end
      end
    end
  end
  return false
end

local function buildBaseNoteName(bossName, difficultyID)
  return NOTE_PREFIX .. bossName .. " - " .. (DIFF_LABEL[difficultyID] or tostring(difficultyID))
end

local function chooseOwnedNoteName(db, parsed)
  db.map[parsed.encounterID] = type(db.map[parsed.encounterID]) == "table" and db.map[parsed.encounterID] or {}
  local mapped = db.map[parsed.encounterID][parsed.difficultyID]
  if type(mapped) == "string" and mapped ~= "" then return mapped end

  local base = buildBaseNoteName(parsed.name, parsed.difficultyID)
  local candidate = base

  -- 매핑에 없는 기존 메모는 접두어가 [Nini]여도 사용자가 만든 것으로 간주하고
  -- 절대 덮어쓰지 않는다. 충돌 시 별도 이름을 만든다.
  if type(_G.NSRT) == "table" and type(NSRT.PersonalReminders) == "table" then
    if NSRT.PersonalReminders[candidate] and not isMappedName(db, candidate) then
      candidate = base .. " (" .. tostring(parsed.encounterID) .. ")"
      local i = 2
      while NSRT.PersonalReminders[candidate] and not isMappedName(db, candidate) do
        candidate = base .. " (" .. tostring(parsed.encounterID) .. "-" .. tostring(i) .. ")"
        i = i + 1
      end
    end
  end

  db.map[parsed.encounterID][parsed.difficultyID] = candidate
  return candidate
end

-- ---------------------------------------------------------------------------
-- 파싱
-- ---------------------------------------------------------------------------

function M:ParsePaste(text)
  text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  if trim(text) == "" then
    return nil, "붙여넣은 내용이 없습니다."
  end

  local headerCount = 0
  for _ in text:gmatch("EncounterID:%s*%d+") do headerCount = headerCount + 1 end
  if headerCount == 0 then
    return nil, "EncounterID를 찾지 못했습니다. Lorrgs의 NSRT 형식인지 확인해 주세요."
  end
  if headerCount > 1 then
    return nil, "메모가 여러 개 감지됐습니다. 하나씩 붙여넣어 주세요."
  end

  local encounterID = tonumber(text:match("EncounterID:%s*(%d+)"))
  local name = cleanBossName(text:match("Name:%s*([^;\n]+)") or ("Encounter " .. tostring(encounterID)))
  local difficultyRaw = text:match("Difficulty:%s*([^;\n]+)")
  local difficultyID = normalizeDifficulty(difficultyRaw)

  if not encounterID then
    return nil, "EncounterID를 숫자로 읽지 못했습니다."
  end
  if not difficultyID then
    return nil, "난이도를 인식하지 못했습니다 (Difficulty:" .. tostring(difficultyRaw or "?") .. ")"
  end
  if name == "" then name = "Encounter " .. tostring(encounterID) end

  local rawLines = {}
  local specHits = {}

  for line in text:gmatch("[^\n]+") do
    line = trim(line)
    if line ~= "" and not line:find("EncounterID:", 1, true) and isReminderLine(line) then
      rawLines[#rawLines + 1] = line
      for sid in line:gmatch("spellid:%s*(%d+)") do
        local sig = SPEC_SIGNATURE[tonumber(sid)]
        if sig then specHits[sig.tag] = sig end
      end
    end
  end

  if #rawLines == 0 then
    return nil, "인식할 수 있는 리마인더 줄이 없습니다."
  end

  local specCount, spec = 0, nil
  for _, hit in pairs(specHits) do
    specCount = specCount + 1
    spec = hit
  end
  if specCount > 1 then
    return nil, "잠행/암살 기준 스킬이 동시에 감지됐습니다. 한 전문화 메모씩 붙여넣어 주세요."
  end

  return {
    encounterID = encounterID,
    name = name,
    difficultyID = difficultyID,
    difficultyRaw = trim(difficultyRaw),
    spec = spec, -- nil이면 Apply 단계에서 현재 전문화 ID 태그를 사용
    rawLines = rawLines,
  }
end

-- ---------------------------------------------------------------------------
-- 병합 / 저장
-- ---------------------------------------------------------------------------

function M:Merge(existingText, parsed, tag, legacyTag)
  local header = string.format(
    "EncounterID:%d;Name:%s;Difficulty:%s;",
    parsed.encounterID,
    parsed.name,
    DIFF_CANONICAL[parsed.difficultyID] or tostring(parsed.difficultyID)
  )

  local body = {}
  local hadSameTag = false
  local otherTags = {}

  if type(existingText) == "string" and existingText ~= "" then
    local normalized = existingText:gsub("\r\n", "\n"):gsub("\r", "\n")
    local firstNL = normalized:find("\n", 1, true)
    local rest = firstNL and normalized:sub(firstNL + 1) or ""

    for line in rest:gmatch("[^\n]+") do
      line = trim(line)
      if line ~= "" then
        if isReminderLine(line) and (lineHasTag(line, tag) or (legacyTag and lineHasTag(line, legacyTag))) then
          -- 구버전은 다른 직업에서 캐릭터명 태그를 사용했다. 같은 캐릭터의
          -- 기존 캐릭터명 태그도 현재 전문화 ID 태그로 교체 대상으로 취급한다.
          hadSameTag = true
        else
          body[#body + 1] = line
          if isReminderLine(line) then
            local otherTag = findLineTag(line)
            if otherTag and otherTag ~= tag then otherTags[otherTag] = true end
          end
        end
      end
    end
  end

  -- 원문의 ph 및 모든 부가 필드는 그대로 보존하고 tag만 새로 붙인다.
  for _, line in ipairs(parsed.rawLines) do
    body[#body + 1] = retagReminderLine(line, tag)
  end

  local out = { header }
  for _, line in ipairs(body) do out[#out + 1] = line end
  return table.concat(out, "\n") .. "\n", hadSameTag, otherTags
end

local function refreshNSRTPersonalReminderUI(noteName)
  local NSI=_G.NorthernSkyRaidTools
  local ui=NSI and NSI.UI and NSI.UI.Core and NSI.UI.Core.NSUI
  local f=ui and ui.personal_reminders_frame
  if not f then return end
  if f.scrollbox and type(f.scrollbox.MasterRefresh)=="function" then
    pcall(f.scrollbox.MasterRefresh,f.scrollbox)
  end
  if noteName and type(f.SelectReminder)=="function" then
    pcall(f.SelectReminder,noteName)
  end
end

function M:Apply(text)
  local parsed, err = self:ParsePaste(text)
  if not parsed then return false, err end

  if type(_G.NSRT) ~= "table" then
    return false, "NSRT가 로드되어 있지 않습니다. NSRT를 설치·활성화해 주세요."
  end

  NSRT.PersonalReminders = type(NSRT.PersonalReminders) == "table" and NSRT.PersonalReminders or {}

  local fallbackName=(UnitName and UnitName("player")) or nil
  fallbackName=trim(fallbackName)

  local currentSpecID, currentSpecName = currentSpecInfo()
  local tag, specLabel
  if parsed.spec then
    -- 도적 잠행/암살은 붙여넣은 메모 안의 기준 스킬로 전문화를 판별한다.
    tag = parsed.spec.tag
    specLabel = parsed.spec.label
  elseif currentSpecID then
    -- 그 외 모든 직업/전문화는 캐릭터명이 아니라 현재 전문화 ID를 사용한다.
    tag = tostring(currentSpecID)
    specLabel = currentSpecName or ("특성 " .. tag)
  else
    return false, "현재 전문화 ID를 확인하지 못했습니다. 전문화를 선택한 뒤 다시 시도해 주세요."
  end

  local db = self:GetDB()
  local noteName = chooseOwnedNoteName(db, parsed)
  local existing = NSRT.PersonalReminders[noteName]
  local legacyTag = fallbackName ~= "" and fallbackName or nil
  local merged, hadSameTag, otherTags = self:Merge(existing, parsed, tag, legacyTag)

  local ok, writeErr = pcall(function()
    NSRT.PersonalReminders[noteName] = merged
  end)
  if not ok then
    return false, "NSRT 개인메모 쓰기 실패: " .. tostring(writeErr)
  end

  -- 임포트 시점에는 ActivePersonalReminder를 건드리지 않는다.
  -- 저장 성공은 PersonalReminders를 다시 읽어 실제 값이 들어갔는지만 검증.
  if NSRT.PersonalReminders[noteName] ~= merged then
    return false, "저장 검증 실패 · NSRT 개인메모에 반영되지 않았습니다."
  end
  refreshNSRTPersonalReminderUI(noteName)

  local kept = {}
  for otherTag in pairs(otherTags) do
    kept[#kept + 1] = specLabelByTag(otherTag)
  end
  table.sort(kept)

  local diffLabel = DIFF_LABEL[parsed.difficultyID] or tostring(parsed.difficultyID)
  local verb = hadSameTag and "교체" or "추가"
  local msg = string.format("%s · %s · %s %s", parsed.name, diffLabel, specLabel, verb)
  if #kept > 0 then msg = msg .. " · 기존 " .. table.concat(kept, ", ") .. " 유지" end
  return true, msg, noteName
end

function M:IsNSRTLoaded()
  return type(_G.NSRT) == "table"
end

function M:GetStatus()
  return self:IsNSRTLoaded() and "NSRT 연결됨" or "NSRT 미발견 · 설치·활성화 필요"
end

-- ---------------------------------------------------------------------------
-- 활성 개인메모 포인터: 난이도 자동 전환
-- ---------------------------------------------------------------------------

local function getCurrentRaidDifficulty()
  if not GetInstanceInfo then return nil end
  local _, instanceType, difficultyID = GetInstanceInfo()
  if instanceType ~= "raid" then return nil end
  return normalizeDifficulty(difficultyID)
end

local function getCharOverrides(db, ck)
  db.overrides[ck] = type(db.overrides[ck]) == "table" and db.overrides[ck] or {}
  return db.overrides[ck]
end

local specPointerMap
-- 2.7.1: NSRT 12.1.33 부터 개인 메모를 전문화별로도 고른다 (NSRT.ActivePersonalReminderSpecs[캐릭][전문화][보스]).
-- NSRT는 「전문화 칸 → (전문화에 안 묶인 메모만) 예전 칸」 순서로 읽으므로, 전문화 칸에 다른 메모가 있으면 우리 메모가 묻힌다.
local function mySpecID()
  local api = _G.C_SpecializationInfo
  if type(api) == "table" and type(api.GetSpecialization) == "function" and type(api.GetSpecializationInfo) == "function" then
    local ok, idx = pcall(api.GetSpecialization)
    if ok and idx then
      local ok2, id = pcall(api.GetSpecializationInfo, idx)
      if ok2 and type(id) == "number" and id > 0 then return id end
    end
  end
  return nil
end

specPointerMap = function(ck, specID, create)
  if type(_G.NSRT) ~= "table" or type(NSRT.ActivePersonalReminderSpecs) ~= "table" or not specID then return nil end
  local byChar = NSRT.ActivePersonalReminderSpecs[ck]
  if type(byChar) ~= "table" then
    if not create then return nil end
    byChar = {}; NSRT.ActivePersonalReminderSpecs[ck] = byChar
  end
  local map = byChar[specID]
  if type(map) ~= "table" then
    if not create then return nil end
    map = {}; byChar[specID] = map
  end
  return map
end

local function restoreOverride(db, ck, encounterID)
  if type(_G.NSRT) ~= "table" then return end
  local charOverrides = db.overrides and db.overrides[ck]
  local state = charOverrides and charOverrides[encounterID]
  if type(state) ~= "table" then return end

  NSRT.ActivePersonalReminder = type(NSRT.ActivePersonalReminder) == "table" and NSRT.ActivePersonalReminder or {}
  NSRT.ActivePersonalReminder[ck] = type(NSRT.ActivePersonalReminder[ck]) == "table" and NSRT.ActivePersonalReminder[ck] or {}

  -- 사용자가 중간에 NSRT에서 직접 다른 메모를 선택했다면 그 선택을 존중한다.
  if NSRT.ActivePersonalReminder[ck][encounterID] == state.applied then
    if state.previous == false then
      NSRT.ActivePersonalReminder[ck][encounterID] = nil
    else
      NSRT.ActivePersonalReminder[ck][encounterID] = state.previous
    end
  end
  -- 2.7.1: NSRT 12.1.33+ 전문화 칸도 우리가 바꾼 그대로일 때만 되돌린다.
  local sp = state.spec
  if type(sp) == "table" and sp.id then
    local map = specPointerMap(ck, sp.id, false)
    if map and map[encounterID] == (sp.applied or nil) then
      if sp.previous == false then map[encounterID] = nil else map[encounterID] = sp.previous end
    end
  end
  charOverrides[encounterID] = nil
end

local function restoreAllOverrides()
  local ck = charKey()
  if not ck then return end
  local db = M:GetDB()
  local charOverrides = db.overrides and db.overrides[ck]
  if type(charOverrides) ~= "table" then return end

  local ids = {}
  for encounterID in pairs(charOverrides) do ids[#ids + 1] = encounterID end
  for _, encounterID in ipairs(ids) do restoreOverride(db, ck, encounterID) end
end
M.RestoreAllOverrides = restoreAllOverrides

local function applyOverride(db, ck, encounterID, noteName)
  if type(_G.NSRT) ~= "table" then return false end
  if type(NSRT.PersonalReminders) ~= "table" or not NSRT.PersonalReminders[noteName] then return false end

  NSRT.ActivePersonalReminder = type(NSRT.ActivePersonalReminder) == "table" and NSRT.ActivePersonalReminder or {}
  NSRT.ActivePersonalReminder[ck] = type(NSRT.ActivePersonalReminder[ck]) == "table" and NSRT.ActivePersonalReminder[ck] or {}

  local charOverrides = getCharOverrides(db, ck)
  local state = charOverrides[encounterID]
  local current = NSRT.ActivePersonalReminder[ck][encounterID]

  if type(state) ~= "table" then
    state = {
      previous = current ~= nil and current or false,
      applied = noteName,
    }
    charOverrides[encounterID] = state
  else
    -- 이미 우리가 임시로 덮은 상태라면 최초의 previous는 보존하고 applied만 교체.
    state.applied = noteName
  end

  NSRT.ActivePersonalReminder[ck][encounterID] = noteName

  -- 2.7.1: 전문화 칸 (NSRT 12.1.33+). 우리 메모가 이 전문화에 묶여 있으면 전문화 칸에 넣고,
  -- 안 묶여 있으면 전문화 칸을 비워서 NSRT가 예전 칸(= 우리 메모)을 읽게 한다. 처음 값은 기억해 두고 끝나면 되돌린다.
  local specID = mySpecID()
  local bound = type(NSRT.PersonalReminderSpecs) == "table" and NSRT.PersonalReminderSpecs[noteName] or nil
  local map = specPointerMap(ck, specID, bound == specID)
  if map then
    if type(state.spec) ~= "table" or state.spec.id ~= specID then
      local prev = map[encounterID]
      state.spec = { id = specID, previous = prev ~= nil and prev or false }
    end
    local want = (bound == specID) and noteName or nil
    map[encounterID] = want
    state.spec.applied = want or false
  end

  if bound ~= nil and bound ~= specID then return false end   -- 다른 전문화에 묶인 메모는 NSRT가 이 전문화에서 안 읽음
  if bound == specID then return map ~= nil and map[encounterID] == noteName end
  return NSRT.ActivePersonalReminder[ck][encounterID] == noteName
end

-- 현재 레이드 난이도에 맞는 NiniTools 소유 메모를 미리 활성 포인터에 준비한다.
-- NSRT가 NiniTools보다 먼저 ENCOUNTER_START를 처리할 수 있으므로, 레이드 입장/
-- 난이도 변경/레디체크/풀카운트에서 선행 동기화하고 ENCOUNTER_START는 보강용이다.
local function syncActivePointersForCurrentDifficulty()
  if type(_G.NSRT) ~= "table" then return end
  local ck = charKey()
  if not ck then return end

  local db = M:GetDB()
  local difficultyID = getCurrentRaidDifficulty()
  if not difficultyID then
    restoreAllOverrides()
    return
  end

  -- 이미 걸린 override가 현재 난이도와 맞지 않으면 먼저 원래 포인터로 복원.
  local charOverrides = db.overrides and db.overrides[ck]
  if type(charOverrides) == "table" then
    local ids = {}
    for encounterID in pairs(charOverrides) do ids[#ids + 1] = encounterID end
    for _, encounterID in ipairs(ids) do
      local desired = db.map[tonumber(encounterID)] and db.map[tonumber(encounterID)][difficultyID]
      local state = charOverrides[encounterID]
      if not desired or not state or state.applied ~= desired then
        restoreOverride(db, ck, encounterID)
      end
    end
  end

  for encounterID, byDiff in pairs(db.map or {}) do
    encounterID = tonumber(encounterID)
    if encounterID and type(byDiff) == "table" then
      local noteName = byDiff[difficultyID]
      if type(noteName) == "string" and noteName ~= "" then
        applyOverride(db, ck, encounterID, noteName)
      end
    end
  end
end
M.SyncActivePointers = syncActivePointersForCurrentDifficulty

-- ENCOUNTER_START에서 해당 보스 하나도 최종 확인한다. 선행 동기화가 정상이라면
-- 이미 같은 값이고, 선행 이벤트를 건너뛴 특수 상황에서는 다음 풀을 위해라도 보정된다.
local function applyActiveForEncounter(encounterID, difficultyID)
  local ck = charKey()
  if not ck then return false end
  difficultyID = normalizeDifficulty(difficultyID)
  encounterID = tonumber(encounterID)
  if not difficultyID or not encounterID then return false end

  local db = M:GetDB()
  local noteName = db.map[encounterID] and db.map[encounterID][difficultyID]
  if not noteName then return false end
  return applyOverride(db, ck, encounterID, noteName)
end
M.ApplyActiveForEncounter = applyActiveForEncounter

local runner = _G.NiniTools.EventDispatcher:CreateProxy("NSRT.Import")
runner:RegisterEvent("ADDON_LOADED")
runner:RegisterEvent("PLAYER_ENTERING_WORLD")
runner:RegisterEvent("PLAYER_LEAVING_WORLD")
runner:RegisterEvent("ZONE_CHANGED_NEW_AREA")
runner:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
runner:RegisterEvent("READY_CHECK")
runner:RegisterEvent("START_PLAYER_COUNTDOWN")
runner:RegisterEvent("ENCOUNTER_START")
runner:RegisterEvent("PLAYER_LOGOUT")
runner:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addon = ...
    if addon == "NorthernSkyRaidTools" or addon == ADDON_NAME then
      C_Timer.After(0, syncActivePointersForCurrentDifficulty)
    end
  elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
    restoreAllOverrides()
  elseif event == "ENCOUNTER_START" then
    local encounterID, _, difficultyID = ...
    applyActiveForEncounter(encounterID, difficultyID)
  else
    C_Timer.After(0, syncActivePointersForCurrentDifficulty)
  end
end)
M.runner = runner
