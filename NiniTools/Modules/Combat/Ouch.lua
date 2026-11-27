-- NiniTools 2.8.22 따끔: 쐐기 · 5인 던전에서 딜러 · 힐러가 어그로를 먹고 적에게 맞으면 「따끔!!」
-- 예전 위크오라 「쐐기: 아프다고 말해주는 위크오라」 아이디어만 가져옴 (코드는 새로 씀).
-- 본섭 12.x 는 애드온이 전투 기록(CLEU)을 못 받으므로:
--   · UNIT_COMBAT("player", "WOUND", …, 학파 1 = 물리) ← 맞았다는 신호 (쐐기에서도 비밀 값 아님 · 시험3 11/27)
--   · UnitThreatSituation("player") 2 이상 ← 내가 어그로 (쐐기에서도 비밀 값 아님) · 쫄 광역 물리기에 안 울림
--   · 적 이름표 대상(UnitIsUnit nameplateNtarget)은 쐐기에서 전부 비밀 값이라 안 씀
-- 알림: 내 채팅창 빨간 줄 + (켜면) 화면 가운데 글씨. 소리 없음 (사용자 11/27).
-- 말하기(/s): 쐐기 안에서는 애드온 말하기가 막힘 (ADDON_ACTION_BLOCKED · 시험3 7/7) → 쐐기 밖 5인 던전에서만, 선택.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local O = {}
NT.Ouch = O

local MESSAGE = "따끔!!"
local THROTTLE = 3.0
local IsSecret = issecretvalue or function() return false end
local lastAt, sayBlocked = 0, false

function O:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.ouch
  if type(db) ~= "table" then db = {}; main.modules.ouch = db end
  if db.enabled == nil then db.enabled = true end
  if db.center == nil then db.center = true end
  if db.say == nil then db.say = false end
  if type(db.message) ~= "string" or db.message == "" then db.message = MESSAGE end
  return db
end

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok then return v end
  return nil
end

local function isTank()
  local spec = call(GetSpecialization)
  if not spec then return false end
  return call(GetSpecializationRole, spec) == "TANK"
end

local function inChallenge()
  return C_ChallengeMode and call(C_ChallengeMode.IsChallengeModeActive) and true or false
end

local function inPartyInstance()
  local ok, inInst, kind = pcall(IsInInstance)
  return ok and inInst and kind == "party" or false
end

-- 내가 어그로를 먹었나: 비밀 값이면 모름 = false (안 울림)
local function haveAggro()
  local st = call(UnitThreatSituation, "player")
  if st == nil or IsSecret(st) then return false end
  return st >= 2
end

function O:Show(text)
  local db = self:GetDB()
  text = text or db.message or MESSAGE
  local line = "|cffff5050" .. text .. "|r"
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line) end
  if db.center ~= false then
    local ok = RaidWarningFrame and RaidNotice_AddMessage and pcall(RaidNotice_AddMessage, RaidWarningFrame, text, {r = 1, g = 0.31, b = 0.31})
    if not ok and UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.31, 0.31) end
  end
end

local function shout()
  local now = GetTime()
  if now - lastAt < THROTTLE then return end
  lastAt = now
  local db = O:GetDB()
  O:Show(db.message)
  if db.say and not sayBlocked and not inChallenge() then
    pcall(SendChatMessage, db.message or MESSAGE, "SAY")
  end
end

local function onUnitCombat(unit, action, _descriptor, _amount, school)
  if unit ~= "player" then return end
  if IsSecret(action) or action ~= "WOUND" then return end
  if IsSecret(school) or school ~= 1 then return end
  local db = O:GetDB()
  if db.enabled == false or not inPartyInstance() or isTank() then return end
  if not haveAggro() then return end
  shout()
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("Ouch")
  or CreateFrame("Frame")
if not pcall(proxy.RegisterUnitEvent, proxy, "UNIT_COMBAT", "player") then pcall(proxy.RegisterEvent, proxy, "UNIT_COMBAT") end
proxy:RegisterEvent("ADDON_ACTION_BLOCKED")
proxy:SetScript("OnEvent", function(_, event, ...)
  if event == "UNIT_COMBAT" then
    pcall(onUnitCombat, ...)
  elseif event == "ADDON_ACTION_BLOCKED" then
    local who = ...
    if who == ADDON_NAME then sayBlocked = true end   -- 이번 접속 동안 말하기 안 함 (나만 보기는 계속)
  end
end)

-- 설정창 · 시험용
function O:Test() lastAt = 0; self:Show() end
function O:IsSayBlocked() return sayBlocked end
