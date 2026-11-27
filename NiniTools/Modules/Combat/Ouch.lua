-- NiniTools 2.8.22 따끔: 쐐기 · 5인 던전에서 딜러 · 힐러가 어그로를 먹고 적에게 맞으면 「따끔!!」
-- 예전 위크오라 「쐐기: 아프다고 말해주는 위크오라」 아이디어만 가져옴 (코드는 새로 씀).
-- 본섭 12.x 는 애드온이 전투 기록(CLEU)을 못 받으므로:
--   · UNIT_COMBAT("player", "WOUND", …, 학파 1 = 물리) ← 맞았다는 신호 (쐐기에서도 비밀 값 아님 · 시험3 11/27)
--   · UnitThreatSituation("player") 2 이상 ← 내가 어그로 (쐐기에서도 비밀 값 아님) · 쫄 광역 물리기에 안 울림
--   · 적 이름표 대상(UnitIsUnit nameplateNtarget)은 쐐기에서 전부 비밀 값이라 안 씀
-- 알림: 내 채팅창 빨간 줄 + (켜면) 화면 글씨. 소리 없음 (사용자 11/27).
-- 2.8.22: 화면 글씨는 블리자드 공격대 경보 칸이 아니라 니니툴 자체 글씨 (위치 이동 · 위치 편집 모드 · 초기화)
-- 말하기(/s): 쐐기 안에서는 애드온 말하기가 막힘 (ADDON_ACTION_BLOCKED · 시험3 7/7) → 쐐기 밖 5인 던전에서만, 선택.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local O = {}
NT.Ouch = O

local MESSAGE = "따끔!!"
local THROTTLE = 3.0
local IsSecret = issecretvalue or function() return false end
local lastAt, sayBlocked = 0, false
local DEFAULT_X, DEFAULT_Y, FONT_SIZE = 0, 220, 26   -- 2.8.22: 글자 크기 조절 (14~60 · 사용자 「점점 커지네」)
local FONT_MIN, FONT_MAX = 14, 60
local HOLD, FADE = 1.4, 0.6

function O:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.ouch
  if type(db) ~= "table" then db = {}; main.modules.ouch = db end
  if db.enabled == nil then db.enabled = true end
  if db.center == nil then db.center = true end
  if db.say == nil then db.say = false end
  if type(db.message) ~= "string" or db.message == "" then db.message = MESSAGE end
  if type(db.x) ~= "number" then db.x = DEFAULT_X end
  if type(db.y) ~= "number" then db.y = DEFAULT_Y end
  if type(db.fontSize) ~= "number" then db.fontSize = FONT_SIZE end
  return db
end

-- 화면 글씨 (내 것) -----------------------------------------------------------------
local frame, text, moveBG, moveLabel
local shownAt, unlocked = nil, false

local function bodyFont()
  if NT.BodyFont then
    local ok, path = pcall(NT.BodyFont, NT)
    if ok and type(path) == "string" and path ~= "" then return path end
  end
  return STANDARD_TEXT_FONT
end

local function applyPosition()
  if not frame then return end
  local db = O:GetDB()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULT_X, db.y or DEFAULT_Y)
end

local function ensureFrame()
  if frame then return frame end
  frame = CreateFrame("Frame", "NiniToolsOuchFrame", UIParent)
  frame:SetSize(260, 56)
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:Hide()
  text = frame:CreateFontString(nil, "OVERLAY")
  text:SetPoint("CENTER")
  O:ApplyFont()
  text:SetTextColor(1, 0.31, 0.31)
  moveBG = frame:CreateTexture(nil, "BACKGROUND")
  moveBG:SetAllPoints()
  moveBG:SetColorTexture(0.1, 0.12, 0.16, 0.65)
  moveBG:Hide()
  moveLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  moveLabel:SetPoint("TOP", frame, "BOTTOM", 0, -2)
  moveLabel:SetText("따끔 위치 · 끌어서 옮기기")
  moveLabel:Hide()
  frame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
      local db = O:GetDB()
      db.x = math.floor(cx - ux + 0.5)
      db.y = math.floor(cy - uy + 0.5)
    end
    applyPosition()
  end)
  frame:SetScript("OnUpdate", function(self)
    if unlocked then self:SetAlpha(1); return end
    if not shownAt then self:Hide(); return end
    local t = GetTime() - shownAt
    if t >= HOLD + FADE then shownAt = nil; self:Hide()
    elseif t > HOLD then self:SetAlpha(1 - (t - HOLD) / FADE)
    else self:SetAlpha(1) end
  end)
  applyPosition()
  return frame
end

local function flash(msg)
  ensureFrame()
  text:SetText(msg)
  shownAt = GetTime()
  frame:SetAlpha(1)
  frame:Show()
end

function O:SetUnlocked(on)
  ensureFrame()
  unlocked = on and true or false
  frame:EnableMouse(unlocked)
  if unlocked then
    frame:RegisterForDrag("LeftButton")
    text:SetText(self:GetDB().message or MESSAGE)
    moveBG:Show(); moveLabel:Show(); frame:SetAlpha(1); frame:Show()
  else
    frame:RegisterForDrag()
    moveBG:Hide(); moveLabel:Hide()
    if not shownAt then frame:Hide() end
  end
end

function O:IsUnlocked() return unlocked end

function O:GetFontSize() return tonumber(self:GetDB().fontSize) or FONT_SIZE end

function O:ApplyFont()
  if not text then return end
  local size = self:GetFontSize()
  if not text:SetFont(bodyFont(), size, "OUTLINE") then text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
  if frame then frame:SetSize(math.max(120, size * 7), math.max(32, size + 22)) end
end

function O:AdjustFontSize(dir)
  local db = self:GetDB()
  db.fontSize = math.max(FONT_MIN, math.min(FONT_MAX, self:GetFontSize() + (dir > 0 and 2 or -2)))
  ensureFrame()
  self:ApplyFont()
  if not unlocked then flash(db.message or MESSAGE) end   -- 바꾼 크기를 바로 보여 줌
end
function O:Frame() return ensureFrame() end

function O:ResetPosition()
  local db = self:GetDB()
  db.x, db.y = DEFAULT_X, DEFAULT_Y
  applyPosition()
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
  if db.center ~= false then pcall(flash, text) end
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
proxy:RegisterEvent("PLAYER_REGEN_DISABLED")
proxy:SetScript("OnEvent", function(_, event, ...)
  if event == "UNIT_COMBAT" then
    pcall(onUnitCombat, ...)
  elseif event == "PLAYER_REGEN_DISABLED" then
    if unlocked then O:SetUnlocked(false) end   -- 전투가 시작되면 위치 이동 끝
  elseif event == "ADDON_ACTION_BLOCKED" then
    local who = ...
    if who == ADDON_NAME then sayBlocked = true end   -- 이번 접속 동안 말하기 안 함 (나만 보기는 계속)
  end
end)

-- 설정창 · 시험용
function O:Test() lastAt = 0; self:Show() end
function O:IsSayBlocked() return sayBlocked end
