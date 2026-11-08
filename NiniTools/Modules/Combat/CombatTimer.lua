-- NiniTools 2.8.2: WoW 포에버용 전투 시간.
-- 본섭은 차단 모듈(Modules/Kick/Core.lua)의 전투시간을 그대로 쓰고, 이 파일은 NiniTools_Camelot.toc 에만 들어간다.
-- 보이는 모습(숫자 글꼴 · EUI 강조색 · 기본 위치 0,105 · 크기 24 · 전투 끝 2.5초 유지)은 본섭 전투시간과 같게 맞췄다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local CT = {}
NT.CombatTimer = CT

local DEFAULTS = { enabled = true, size = 24, x = 0, y = 105, hold = 2.5 }
local MIN_SIZE, MAX_SIZE = 12, 48

local frame
local state = { active = false, startTime = 0, lastSecond = -1, serial = 0 }
local unlocked = false

local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function CT:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.combatTimer
  if type(db) ~= "table" then db = {}; main.modules.combatTimer = db end
  for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
  return db
end

local function accent()
  local EUI = _G.EllesmereUI
  if EUI and type(EUI.GetAccentColor) == "function" then
    local ok, r, g, b = pcall(EUI.GetAccentColor)
    if ok and tonumber(r) and tonumber(g) and tonumber(b) then return r, g, b end
  end
  return 0, 207 / 255, 1
end

local function fontPath()
  if type(NT.NumberFont) == "function" then
    local ok, p = pcall(NT.NumberFont, NT)
    if ok and type(p) == "string" and p ~= "" then return p end
  end
  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function format(seconds)
  local total = math.max(0, math.floor((tonumber(seconds) or 0) + 0.0001))
  local h, m, s = math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function applyStyle()
  if not frame then return end
  local db = CT:GetDB()
  local size = clamp(db.size, MIN_SIZE, MAX_SIZE)
  frame.text:SetFont(fontPath(), size, "OUTLINE")
  frame.text:SetTextColor(accent())
  frame.text:SetShadowColor(0, 0, 0, .85)
  frame.text:SetShadowOffset(1, -1)
  frame:SetSize(math.max(60, size * 4), size + 8)
end

local function applyPosition()
  if not frame then return end
  local db = CT:GetDB()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", math.floor((tonumber(db.x) or 0) + .5), math.floor((tonumber(db.y) or 105) + .5))
end

local function build()
  if frame then return frame end
  frame = CreateFrame("Frame", "NiniToolsForeverCombatTimer", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:RegisterForDrag("LeftButton")
  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")
  frame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local db = CT:GetDB()
    db.x = math.floor(cx * scale - ux + .5)
    db.y = math.floor(cy * scale - uy + .5)
    applyPosition()
  end)
  local elapsedAcc = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    if not state.active or unlocked then return end
    elapsedAcc = elapsedAcc + (elapsed or 0)
    if elapsedAcc < 0.1 then return end
    elapsedAcc = 0
    local sec = math.floor(GetTime() - state.startTime)
    if sec ~= state.lastSecond then
      state.lastSecond = sec
      frame.text:SetText(format(sec))
    end
  end)
  frame:Hide()
  applyStyle()
  applyPosition()
  return frame
end

local function startCombat()
  local db = CT:GetDB()
  if db.enabled == false then return end
  build()
  state.serial = state.serial + 1
  state.active = true
  state.startTime = GetTime()
  state.lastSecond = -1
  if unlocked then return end
  applyStyle()
  frame.text:SetText("0:00")
  frame:Show()
end

local function endCombat()
  if not state.active then return end
  local elapsed = GetTime() - state.startTime
  state.active = false
  state.lastSecond = -1
  state.serial = state.serial + 1
  local serial = state.serial
  local db = CT:GetDB()
  if db.enabled == false or not frame or unlocked then return end
  frame.text:SetText(format(elapsed))
  frame:Show()
  C_Timer.After(clamp(db.hold, 1, 8), function()
    if state.serial ~= serial or state.active or unlocked or not frame then return end
    frame:Hide()
  end)
end

function CT:IsEnabled() return self:GetDB().enabled ~= false end

function CT:SetEnabled(flag)
  local db = self:GetDB()
  db.enabled = flag and true or false
  state.serial = state.serial + 1
  if not db.enabled then
    state.active = false
    if frame and not unlocked then frame:Hide() end
  elseif InCombatLockdown() or UnitAffectingCombat("player") then
    startCombat()
  end
end

function CT:GetSize() return clamp(self:GetDB().size, MIN_SIZE, MAX_SIZE) end

function CT:AdjustSize(dir)
  local db = self:GetDB()
  db.size = clamp((tonumber(db.size) or DEFAULTS.size) + ((tonumber(dir) or 0) >= 0 and 2 or -2), MIN_SIZE, MAX_SIZE)
  applyStyle()
end

function CT:IsUnlocked() return unlocked end

function CT:SetUnlocked(flag)
  build()
  unlocked = flag and true or false
  frame:EnableMouse(unlocked)
  applyStyle()
  if unlocked then
    frame.text:SetText("0:00")
    frame:Show()
  elseif state.active and self:IsEnabled() then
    frame.text:SetText(format(GetTime() - state.startTime))
    frame:Show()
  else
    frame:Hide()
  end
end

function CT:ResetPosition()
  local db = self:GetDB()
  db.x, db.y = DEFAULTS.x, DEFAULTS.y
  applyPosition()
end

function CT:Test()
  build()
  if unlocked then return end
  applyStyle()
  state.serial = state.serial + 1
  local serial = state.serial
  frame.text:SetText("1:23")
  frame:Show()
  C_Timer.After(3, function()
    if state.serial ~= serial or state.active or unlocked or not frame then return end
    frame:Hide()
  end)
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("ForeverCombatTimer")
  or CreateFrame("Frame")
proxy:RegisterEvent("PLAYER_LOGIN")
proxy:RegisterEvent("PLAYER_REGEN_DISABLED")
proxy:RegisterEvent("PLAYER_REGEN_ENABLED")
proxy:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    startCombat()
  elseif event == "PLAYER_REGEN_ENABLED" then
    endCombat()
  elseif event == "PLAYER_LOGIN" then
    build(); applyStyle(); applyPosition()
  end
end)
