-- NiniTools 2.8.5: 위치 편집 모드.
-- 움직일 수 있는 니니툴 표시를 한꺼번에 잠금 해제하고, 화면에 격자 · 가운데 선을 띄워 줄 맞추기 쉽게 한다.
-- 저장은 각 기능이 원래 하던 대로(드래그를 놓을 때) 한다. 이 파일은 켜고 끄기와 격자만 맡는다.
-- 전투가 시작되면 자동으로 끝내고 모두 잠근다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local EM = { active = false }
NT.EditMode = EM

local GRID = 32

-- 움직일 수 있는 표시들. available() 이 false 면 이 클라이언트 · 설정에서는 건너뛴다.
local function kickDB() return (NT.GetKickDB and NT:GetKickDB()) or {} end
EM.items = {
  { name = "차단 알림",
    available = function() return not NT.FOREVER and SlashCmdList and SlashCmdList.NINIKICK ~= nil end,
    set = function(on) NT:CallSlash("NINIKICK", on and "unlock" or "lock") end,
    get = function() return kickDB().unlocked and true or false end },
  { name = "전투 시간",
    available = function() return not NT.FOREVER and SlashCmdList and SlashCmdList.NINIKICK ~= nil and kickDB().combatTimerEnabled ~= false end,
    set = function(on) NT:CallSlash("NINIKICK", on and "combattime unlock" or "combattime lock") end,
    get = function() return kickDB().combatTimerUnlocked and true or false end },
  { name = "주변 적 숫자",
    available = function()
      local api = _G.NiniEnemyCount
      return not NT.FOREVER and api and api.SetUnlocked and (not api.IsEnabled or api.IsEnabled())
    end,
    set = function(on) _G.NiniEnemyCount.SetUnlocked(on) end,
    get = function() return _G.NiniEnemyCount.IsUnlocked() and true or false end },
  { name = "전투 시간",
    available = function() return NT.FOREVER and NT.CombatTimer and NT.CombatTimer:IsEnabled() end,
    set = function(on) NT.CombatTimer:SetUnlocked(on) end,
    get = function() return NT.CombatTimer:IsUnlocked() end },
  { name = "Navi 채팅",
    available = function() return NT.SetNaviChatUnlocked and NT.IsNaviChatEnabled and NT:IsNaviChatEnabled() end,
    set = function(on) NT:SetNaviChatUnlocked(on) end,
    get = function() return NT:IsNaviChatUnlocked() and true or false end },
}

function EM:Available()
  local out = {}
  for _, item in ipairs(self.items) do
    local ok, yes = pcall(item.available)
    if ok and yes then out[#out + 1] = item end
  end
  return out
end

local overlay, bar

local function line(parent, vertical, offset, alpha, r, g, b)
  local t = parent:CreateTexture(nil, "BACKGROUND")
  t:SetColorTexture(r or 1, g or 1, b or 1, alpha)
  if vertical then
    t:SetWidth(1); t:SetPoint("TOP", parent, "TOP", offset, 0); t:SetPoint("BOTTOM", parent, "BOTTOM", offset, 0)
  else
    t:SetHeight(1); t:SetPoint("LEFT", parent, "LEFT", 0, offset); t:SetPoint("RIGHT", parent, "RIGHT", 0, offset)
  end
  return t
end

local function buildOverlay()
  if overlay then return end
  local C = NT.UI and NT.UI.C
  local ar, ag, ab = 0, .81, 1
  if C then ar, ag, ab = C.accent[1], C.accent[2], C.accent[3] end

  overlay = CreateFrame("Frame", "NiniToolsEditGrid", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("BACKGROUND")
  overlay:EnableMouse(false)
  overlay.lines = {}
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  for x = GRID, w / 2, GRID do
    overlay.lines[#overlay.lines + 1] = line(overlay, true, x, .07)
    overlay.lines[#overlay.lines + 1] = line(overlay, true, -x, .07)
  end
  for y = GRID, h / 2, GRID do
    overlay.lines[#overlay.lines + 1] = line(overlay, false, y, .07)
    overlay.lines[#overlay.lines + 1] = line(overlay, false, -y, .07)
  end
  overlay.centerV = line(overlay, true, 0, .55, ar, ag, ab)
  overlay.centerH = line(overlay, false, 0, .55, ar, ag, ab)
  overlay:Hide()

  -- 위쪽 가운데 작은 도구 막대
  local UI = NT.UI
  bar = CreateFrame("Frame", "NiniToolsEditBar", UIParent, "BackdropTemplate")
  bar:SetSize(520, 64)
  bar:SetPoint("TOP", 0, -90)
  bar:SetFrameStrata("DIALOG")
  bar:SetClampedToScreen(true)
  bar:SetMovable(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", bar.StartMoving)
  bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
  if UI then
    UI:Backdrop(bar, C.bg, C.border)
    bar:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], .95)
    bar.title = UI:Font(bar, 11, "NiniTools 위치 편집", C.text)
    bar.title:SetPoint("TOPLEFT", 14, -10)
    bar.list = UI:Font(bar, 8, "", C.muted)
    bar.list:SetPoint("TOPLEFT", 14, -32); bar.list:SetPoint("RIGHT", -230, 0); bar.list:SetJustifyH("LEFT")
    bar.done = UI:Button(bar, "완료", 76, 28, function() EM:Stop() end)
    bar.done:SetPoint("RIGHT", -12, 0)
    bar.grid = UI:Button(bar, "격자 끄기", 96, 28, function() EM:SetGrid(not overlay:IsShown()) end)
    bar.grid:SetPoint("RIGHT", bar.done, "LEFT", -8, 0)
  end
  bar:Hide()
end

function EM:SetGrid(on)
  buildOverlay()
  overlay:SetShown(on and self.active)
  if bar.grid and bar.grid.label then bar.grid.label:SetText(on and "격자 끄기" or "격자 켜기") end
end

function EM:Start()
  if InCombatLockdown and InCombatLockdown() then
    NT:Print("전투 중에는 위치 편집을 시작할 수 없어요.")
    return false
  end
  local items = self:Available()
  if #items == 0 then
    NT:Print("지금 움직일 수 있는 표시가 없어요. (꺼진 기능은 빠집니다)")
    return false
  end
  buildOverlay()
  self.active = true
  local names = {}
  for _, item in ipairs(items) do
    pcall(item.set, true)
    names[#names + 1] = item.name
  end
  self.started = items
  if bar.list then bar.list:SetText("드래그해서 옮기기: " .. table.concat(names, " · ")) end
  bar:Show()
  self:SetGrid(true)
  if NT.UI and NT.UI.frame and NT.UI.frame:IsShown() then NT.UI.frame:Hide() end
  return true
end

function EM:Stop(silent)
  if not self.active then return end
  self.active = false
  for _, item in ipairs(self.started or {}) do pcall(item.set, false) end
  self.started = nil
  if overlay then overlay:Hide() end
  if bar then bar:Hide() end
  if not silent then NT:Print("위치 편집을 마쳤어요. 옮긴 위치는 저장됐어요.") end
end

function EM:Toggle()
  if self.active then self:Stop() else self:Start() end
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("EditMode")
  or CreateFrame("Frame")
proxy:RegisterEvent("PLAYER_REGEN_DISABLED")
proxy:SetScript("OnEvent", function()
  if EM.active then
    EM:Stop(true)
    NT:Print("전투가 시작돼서 위치 편집을 끝내고 잠갔어요.")
  end
end)
