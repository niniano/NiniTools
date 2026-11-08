-- NiniTools 2.8.4: WoW 포에버용 주시 · 차단 매크로 자동 생성.
-- 본섭은 차단 모듈(Modules/Kick/Core.lua)이 같은 이름의 매크로를 관리하고, 이 파일은 NiniTools_Camelot.toc 에만 들어간다.
--   NiniKickFocus : 마우스오버(없으면 대상)를 주시 + 담당 징표. 아이콘 = 그 징표 모양 (단축바에서 안 바뀜)
--   NiniKickAuto  : 주시가 있으면 주시 차단, 없으면 가까운 적 차단 후 원래 대상으로 복귀
-- 항상 「캐릭터 전용」 매크로만 만들고 고친다. 계정 공용 매크로는 건드리지 않는다.
-- 포에버는 본섭 12.0.7 의 /tm ~N(무징표일 때만) 문법이 없을 수 있어 /tm N 을 쓴다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local FM = {}
NT.ForeverMacros = FM

local FOCUS_NAME, AUTO_NAME = "NiniKickFocus", "NiniKickAuto"
FM.FOCUS_NAME, FM.AUTO_NAME = FOCUS_NAME, AUTO_NAME
FM.MARKER_NAMES = { "별", "동그라미", "다이아", "세모", "달", "네모", "가위표", "해골" }

-- 포에버(오리지널 기반) 직업별 차단 기술. 없는 직업은 차단 매크로를 만들지 않는다.
local INTERRUPTS = {
  ROGUE = { 1766, "발차기" },
  WARRIOR = { 6552, "자루 공격" },
  MAGE = { 2139, "마법 차단" },
  SHAMAN = { 8042, "대지 충격" },
}

local pending, warned = false, false

function FM:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.foreverMacros
  if type(db) ~= "table" then db = {}; main.modules.foreverMacros = db end
  if db.enabled == nil then db.enabled = true end
  db.marker = math.max(1, math.min(8, math.floor(tonumber(db.marker) or 1)))
  return db
end

local function safeText(v)
  if type(v) ~= "string" then return nil end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return nil end
  end
  return v
end

local function playerClass()
  local ok, _, file = pcall(UnitClass, "player")
  return ok and file or nil
end

local function spellNameAndIcon(id, fallbackName)
  local name, icon
  if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    if ok and type(info) == "table" then name, icon = info.name, info.iconID end
  end
  if (not name or name == "") and type(GetSpellInfo) == "function" then
    local ok, n, _, ic = pcall(GetSpellInfo, id)
    if ok then name, icon = n, icon or ic end
  end
  name = safeText(name)
  if not name or name == "" then name = fallbackName end
  return name, icon or 134400
end

function FM:InterruptSpell()
  local def = INTERRUPTS[playerClass() or ""]
  if not def then return nil end
  return spellNameAndIcon(def[1], def[2])
end

local function markerIcon(marker)
  if type(GetFileIDFromPath) == "function" then
    local ok, id = pcall(GetFileIDFromPath, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. marker)
    if ok and tonumber(id) and id > 0 then return id end
  end
  return 137000 + marker
end

function FM:FocusBody(marker)
  -- #showtooltip 을 빼야 아이콘이 상황 따라 바뀌지 않고 징표 모양으로 고정된다
  return string.format("/focus [@mouseover,harm,nodead][harm,nodead]\n/tm [@mouseover,harm,nodead][harm,nodead] %d", marker)
end

function FM:AutoBody(spell)
  return table.concat({
    "#showtooltip " .. spell,
    "/cast [@focus,exists,nodead,harm] " .. spell,
    "/stopmacro [@focus,exists,nodead,harm]",
    "/focus target",
    "/cleartarget",
    "/targetenemy",
    "/cast " .. spell,
    "/target focus",
    "/clearfocus",
    "/startattack",
  }, "\n")
end

local function counts()
  if type(GetNumMacros) ~= "function" then return 0, 0 end
  local ok, a, c = pcall(GetNumMacros)
  if not ok then return 0, 0 end
  return tonumber(a) or 0, tonumber(c) or 0
end

local function findCharacterMacro(name)
  if type(GetMacroInfo) ~= "function" then return 0 end
  local accountMax = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  local _, charCount = counts()
  for i = accountMax + 1, accountMax + charCount do
    local ok, n = pcall(GetMacroInfo, i)
    if ok and safeText(n) == name then return i end
  end
  return 0
end
FM.FindCharacterMacro = findCharacterMacro

-- 반환: "same" | "edited" | "created" | nil, 실패 이유
local function ensure(name, icon, body)
  local index = findCharacterMacro(name)
  if index > 0 then
    local ok, oldName, oldIcon, oldBody = pcall(GetMacroInfo, index)
    if ok and oldName == name and oldBody == body and tostring(oldIcon) == tostring(icon) then return "same" end
    local edited, err = pcall(EditMacro, index, name, icon, body)
    if edited then return "edited" end
    return nil, tostring(err)
  end
  local _, charCount = counts()
  local charMax = tonumber(_G.MAX_CHARACTER_MACROS) or 18
  if charCount >= charMax then return nil, string.format("캐릭터 전용 매크로 칸이 가득 참 (%d/%d)", charCount, charMax) end
  local created, result = pcall(CreateMacro, name, icon, body, true)
  if created and tonumber(result) and result > 0 then return "created" end
  return nil, tostring(result)
end

-- 반환: 성공 여부, 안내 문구
function FM:Ensure(silent)
  local db = self:GetDB()
  if db.enabled == false then return false, "꺼짐" end
  if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" or type(GetMacroInfo) ~= "function" then
    return false, "매크로 API 없음"
  end
  if InCombatLockdown() then pending = true; return false, "전투 중 · 전투 끝나면 만듦" end
  pending = false

  local made, problems = {}, {}
  local r, err = ensure(FOCUS_NAME, markerIcon(db.marker), self:FocusBody(db.marker))
  if r == "created" or r == "edited" then made[#made + 1] = FOCUS_NAME elseif not r then problems[#problems + 1] = FOCUS_NAME .. ": " .. err end

  local spell, icon = self:InterruptSpell()
  if spell then
    r, err = ensure(AUTO_NAME, icon, self:AutoBody(spell))
    if r == "created" or r == "edited" then made[#made + 1] = AUTO_NAME elseif not r then problems[#problems + 1] = AUTO_NAME .. ": " .. err end
  end

  if #problems > 0 then
    if not silent or not warned then
      warned = true
      NT:Print("주시 · 차단 매크로 만들기 실패 · " .. table.concat(problems, " · "))
    end
    return false, table.concat(problems, " · ")
  end
  warned = false
  if #made > 0 then
    NT:Print(string.format("%s 매크로를 만들었어요 · /m → 캐릭터 전용 탭에서 단축바로 끌어 놓으세요.", table.concat(made, " · ")))
  elseif not silent then
    NT:Print("주시 · 차단 매크로가 이미 최신이에요.")
  end
  return true, (#made > 0) and "만듦" or "최신"
end

function FM:SetEnabled(flag)
  self:GetDB().enabled = flag and true or false
  if flag then self:Ensure(false) end
end

function FM:SetMarker(marker)
  self:GetDB().marker = math.max(1, math.min(8, math.floor(tonumber(marker) or 1)))
  self:Ensure(true)
end

function FM:CycleMarker()
  local db = self:GetDB()
  self:SetMarker(db.marker % 8 + 1)
end

function FM:Status()
  local db = self:GetDB()
  if db.enabled == false then return "OFF" end
  local parts = { (findCharacterMacro(FOCUS_NAME) > 0) and (FOCUS_NAME .. " 있음") or (FOCUS_NAME .. " 없음") }
  if self:InterruptSpell() then
    parts[#parts + 1] = (findCharacterMacro(AUTO_NAME) > 0) and (AUTO_NAME .. " 있음") or (AUTO_NAME .. " 없음")
  else
    parts[#parts + 1] = "차단 기술 없는 직업 · 주시만"
  end
  return table.concat(parts, " · ")
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("ForeverMacros")
  or CreateFrame("Frame")
proxy:RegisterEvent("PLAYER_LOGIN")
proxy:RegisterEvent("PLAYER_REGEN_ENABLED")
proxy:RegisterEvent("LEARNED_SPELL_IN_TAB")
proxy:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if pending then C_Timer.After(0.5, function() FM:Ensure(true) end) end
  else
    -- 접속: 매크로 목록이 준비될 시간을 두고 / 새 기술 배움: 이름 · 아이콘이 바뀔 수 있어 다시 맞춤
    C_Timer.After(event == "PLAYER_LOGIN" and 3 or 1, function() FM:Ensure(true) end)
  end
end)
