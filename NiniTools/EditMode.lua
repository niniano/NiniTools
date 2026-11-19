-- NiniTools 2.8.5: 위치 편집 모드.
-- 움직일 수 있는 니니툴 표시를 한꺼번에 잠금 해제하고, 화면에 격자 · 가운데 선을 띄워 줄 맞추기 쉽게 한다.
-- 저장은 각 기능이 원래 하던 대로(드래그를 놓을 때) 한다. 이 파일은 켜고 끄기와 격자만 맡는다.
-- 전투가 시작되면 자동으로 끝내고 모두 잠근다.
-- 2.8.12: 붙이기(8px 칸) · 화살표 1px(Shift 10px) · 되돌리기(Ctrl+Z) · 고른 표시 테두리와 가운데 안내선 · 좌표 표시.
--   옮긴 뒤에는 각 기능의 원래 OnDragStop 을 한 번 더 불러 그 기능 방식대로 저장한다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local EM = { active = false }
NT.EditMode = EM

local GRID = 32
local SNAP = 8
local UNDO_MAX = 40

-- 움직일 수 있는 표시들. available() 이 false 면 이 클라이언트 · 설정에서는 건너뛴다.
local function kickDB() return (NT.GetKickDB and NT:GetKickDB()) or {} end
EM.items = {
  { name = "차단 알림",
    available = function() return not NT.FOREVER and SlashCmdList and SlashCmdList.NINIKICK ~= nil end,
    set = function(on) NT:CallSlash("NINIKICK", on and "unlock" or "lock") end,
    get = function() return kickDB().unlocked and true or false end,
    frames = function() return _G.NiniKickNSRTAlert end },
  { name = "전투 시간",
    available = function() return not NT.FOREVER and SlashCmdList and SlashCmdList.NINIKICK ~= nil and kickDB().combatTimerEnabled ~= false end,
    set = function(on) NT:CallSlash("NINIKICK", on and "combattime unlock" or "combattime lock") end,
    get = function() return kickDB().combatTimerUnlocked and true or false end,
    frames = function() return _G.NiniKickCombatTimer end },
  { name = "주변 적 숫자",
    available = function()
      local api = _G.NiniEnemyCount
      return not NT.FOREVER and api and api.SetUnlocked and (not api.IsEnabled or api.IsEnabled())
    end,
    set = function(on) _G.NiniEnemyCount.SetUnlocked(on) end,
    get = function() return _G.NiniEnemyCount.IsUnlocked() and true or false end,
    frames = function() return _G.NiniToolsEnemyCountFrame end },
  { name = "전투 시간",
    available = function() return NT.FOREVER and NT.CombatTimer and NT.CombatTimer:IsEnabled() end,
    set = function(on) NT.CombatTimer:SetUnlocked(on) end,
    get = function() return NT.CombatTimer:IsUnlocked() end,
    frames = function() return _G.NiniToolsForeverCombatTimer end },
  { name = "던전 기록",
    available = function() return NT.FOREVER and NT.DungeonRun and NT.DungeonRun:IsEnabled() and NT.DungeonRun:GetDB().panel ~= false end,
    set = function(on) NT.DungeonRun:SetUnlocked(on) end,
    get = function() return NT.DungeonRun:IsUnlocked() end,
    frames = function() return NT.DungeonRun:PanelFrame() end },
  { name = "Navi 채팅",
    available = function() return NT.SetNaviChatUnlocked and NT.IsNaviChatEnabled and NT:IsNaviChatEnabled() end,
    set = function(on) NT:SetNaviChatUnlocked(on) end,
    get = function() return NT:IsNaviChatUnlocked() and true or false end,
    frames = function() if NT.NaviChatEditFrames then return NT:NaviChatEditFrames() end end },
}

function EM:Available()
  local out = {}
  for _, item in ipairs(self.items) do
    local ok, yes = pcall(item.available)
    if ok and yes then out[#out + 1] = item end
  end
  return out
end

local overlay, bar, guides, sel

-- ── 좌표 도우미: UIParent 가운데를 0,0 으로 한 UIParent 단위 ──
local function ratio(f)
  local us, fs = UIParent:GetEffectiveScale(), f:GetEffectiveScale()
  if not us or us == 0 or not fs or fs == 0 then return 1 end
  return fs / us
end

local function centerOffset(f)
  if not f then return nil end
  local cx, cy = f:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return nil end
  local r = ratio(f)
  return cx * r - ux, cy * r - uy
end

local function placeCenter(f, x, y)
  local r = ratio(f)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", x / r, y / r)
end

local function round(v, step)
  step = step or 1
  return math.floor(v / step + .5) * step
end

local function snapDB()
  local db = NT.GetDB and NT:GetDB() or {}
  if db.editSnap == nil then db.editSnap = true end
  return db
end

-- ── 각 표시 연결 ──
local hooked = {}
EM.history = {}

local function resolve(item)
  if not item.frames then return nil end
  local ok, handle, target, save = pcall(item.frames)
  if not ok or not handle then return nil end
  item._handle, item._target, item._save = handle, target or handle, save
  return item._target
end

-- 옮긴 위치를 그 기능 방식대로 저장한다.
local function saveItem(item)
  if item._save then pcall(item._save); return end
  local h = item._handle
  local fn = h and h.GetScript and h:GetScript("OnDragStop")
  if type(fn) ~= "function" then return end
  EM.busy = true
  pcall(fn, h)
  EM.busy = false
end

function EM:Push(item)
  local t = item and item._target
  local x, y = centerOffset(t)
  if not x then return end
  local h = self.history
  h[#h + 1] = { item = item, x = x, y = y }
  if #h > UNDO_MAX then table.remove(h, 1) end
  self:RefreshBar()
end

function EM:Select(item)
  self.selected = item
  if sel then
    if item and item._target then
      sel:ClearAllPoints(); sel:SetAllPoints(item._target); sel:Show()
    else
      sel:Hide()
    end
  end
  self:RefreshBar()
end

function EM:SnapItem(item)
  local x, y = centerOffset(item._target)
  if not x then return end
  placeCenter(item._target, round(x, SNAP), round(y, SNAP))
  saveItem(item)
end

local function hookItem(item)
  if not resolve(item) then return end
  local h = item._handle
  if hooked[h] or not h.HookScript then return end
  hooked[h] = item
  h:HookScript("OnDragStart", function()
    if not EM.active or EM.busy then return end
    EM:Push(item)
    EM:Select(item)
    EM.dragging = item
  end)
  h:HookScript("OnDragStop", function()
    if not EM.active or EM.busy then return end
    EM.dragging = nil
    if snapDB().editSnap then EM:SnapItem(item) end
    EM:Select(item)
  end)
end

function EM:Nudge(dx, dy)
  local item = self.selected
  if not item or not item._target then return end
  local x, y = centerOffset(item._target)
  if not x then return end
  local now = GetTime and GetTime() or 0
  local last = self.history[#self.history]
  if not (last and last.item == item and self.lastNudge and now - self.lastNudge < 1.5) then self:Push(item) end
  self.lastNudge = now
  placeCenter(item._target, round(x) + dx, round(y) + dy)
  saveItem(item)
  self:RefreshBar()
end

function EM:Undo()
  local h = self.history
  local step = table.remove(h)
  if not step then NT:Print("되돌릴 위치가 없어요."); return end
  local item = step.item
  if item._target then
    placeCenter(item._target, step.x, step.y)
    saveItem(item)
    self.lastNudge = nil
    self:Select(item)
  end
end

function EM:SetSnap(on)
  snapDB().editSnap = on and true or false
  self:RefreshBar()
end

-- ── 화면 ──
local function line(parent, vertical, offset, alpha, r, g, b, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetColorTexture(r or 1, g or 1, b or 1, alpha)
  if vertical then
    t:SetWidth(1); t:SetPoint("TOP", parent, "TOP", offset, 0); t:SetPoint("BOTTOM", parent, "BOTTOM", offset, 0)
  else
    t:SetHeight(1); t:SetPoint("LEFT", parent, "LEFT", 0, offset); t:SetPoint("RIGHT", parent, "RIGHT", 0, offset)
  end
  return t
end

local function edge(f, a, b, w, h, r, g, bl)
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetColorTexture(r, g, bl, .95)
  t:SetPoint(a); t:SetPoint(b)
  if w then t:SetWidth(w) else t:SetHeight(h) end
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

  -- 고른 표시의 가운데를 지나는 안내선 (화면 가운데와 맞으면 초록)
  guides = CreateFrame("Frame", "NiniToolsEditGuides", UIParent)
  guides:SetAllPoints(UIParent)
  guides:SetFrameStrata("FULLSCREEN")
  guides:EnableMouse(false)
  guides.v = line(guides, true, 0, .5, ar, ag, ab, "ARTWORK")
  guides.h = line(guides, false, 0, .5, ar, ag, ab, "ARTWORK")
  guides.acc = 0
  guides:SetScript("OnUpdate", function(self, elapsed)
    self.acc = self.acc + (elapsed or 0)
    if self.acc < .03 then return end
    self.acc = 0
    local item = EM.selected
    local x, y = centerOffset(item and item._target)
    if not x then self.v:Hide(); self.h:Hide(); return end
    self.v:ClearAllPoints(); self.v:SetPoint("TOP", self, "TOP", x, 0); self.v:SetPoint("BOTTOM", self, "BOTTOM", x, 0)
    self.h:ClearAllPoints(); self.h:SetPoint("LEFT", self, "LEFT", 0, y); self.h:SetPoint("RIGHT", self, "RIGHT", 0, y)
    local onV, onH = math.abs(x) < 1, math.abs(y) < 1
    self.v:SetColorTexture(onV and .3 or ar, onV and 1 or ag, onV and .45 or ab, onV and .9 or .45)
    self.h:SetColorTexture(onH and .3 or ar, onH and 1 or ag, onH and .45 or ab, onH and .9 or .45)
    self.v:Show(); self.h:Show()
    if EM.dragging then EM:RefreshBar() end
  end)
  guides:Hide()

  -- 고른 표시 테두리
  sel = CreateFrame("Frame", "NiniToolsEditSelection", UIParent)
  sel:SetFrameStrata("FULLSCREEN_DIALOG")
  sel:EnableMouse(false)
  edge(sel, "TOPLEFT", "TOPRIGHT", nil, 2, ar, ag, ab)
  edge(sel, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2, ar, ag, ab)
  edge(sel, "TOPLEFT", "BOTTOMLEFT", 2, nil, ar, ag, ab)
  edge(sel, "TOPRIGHT", "BOTTOMRIGHT", 2, nil, ar, ag, ab)
  sel:Hide()

  -- 위쪽 가운데 도구 막대
  local UI = NT.UI
  bar = CreateFrame("Frame", "NiniToolsEditBar", UIParent, "BackdropTemplate")
  bar:SetSize(660, 82)
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
    bar.list:SetPoint("TOPLEFT", 14, -30); bar.list:SetPoint("RIGHT", -360, 0); bar.list:SetJustifyH("LEFT")
    bar.sel = UI:Font(bar, 9, "", C.text)
    bar.sel:SetPoint("TOPLEFT", 14, -50); bar.sel:SetPoint("RIGHT", -360, 0); bar.sel:SetJustifyH("LEFT")
    bar.done = UI:Button(bar, "완료", 64, 28, function() EM:Stop() end)
    bar.done:SetPoint("RIGHT", -12, 0)
    bar.grid = UI:Button(bar, "격자 끄기", 84, 28, function() EM:SetGrid(not overlay:IsShown()) end)
    bar.grid:SetPoint("RIGHT", bar.done, "LEFT", -6, 0)
    bar.snap = UI:Button(bar, "붙이기 켜짐", 92, 28, function() EM:SetSnap(not snapDB().editSnap) end)
    bar.snap:SetPoint("RIGHT", bar.grid, "LEFT", -6, 0)
    bar.undo = UI:Button(bar, "되돌리기", 84, 28, function() EM:Undo() end)
    bar.undo:SetPoint("RIGHT", bar.snap, "LEFT", -6, 0)
  end
  -- 화살표 1px · Shift 10px · Ctrl+Z 되돌리기 · Esc 끝내기. 다른 키는 게임으로 넘긴다.
  if bar.EnableKeyboard then
    bar:EnableKeyboard(true)
    bar:SetScript("OnKeyDown", function(self, key)
      local handled = true
      local step = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
      if key == "UP" then EM:Nudge(0, step)
      elseif key == "DOWN" then EM:Nudge(0, -step)
      elseif key == "LEFT" then EM:Nudge(-step, 0)
      elseif key == "RIGHT" then EM:Nudge(step, 0)
      elseif key == "Z" and IsControlKeyDown and IsControlKeyDown() then EM:Undo()
      elseif key == "TAB" then EM:SelectNext()
      elseif key == "ESCAPE" then EM:Stop()
      else handled = false end
      if self.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then
        pcall(self.SetPropagateKeyboardInput, self, not handled)
      end
    end)
  end
  bar:Hide()
end

local function setLabel(btn, text)
  if btn and btn.label then btn.label:SetText(text) end
end

function EM:RefreshBar()
  if not bar then return end
  setLabel(bar.snap, snapDB().editSnap and "붙이기 켜짐" or "붙이기 꺼짐")
  setLabel(bar.undo, #self.history > 0 and string.format("되돌리기 %d", #self.history) or "되돌리기")
  if bar.sel then
    local item = self.selected
    local x, y = centerOffset(item and item._target)
    if x then
      bar.sel:SetText(string.format("고름: %s   x %d · y %d   ·  화살표 1px · Shift 10px · Tab 다음 · Ctrl+Z",
        item.name, round(x), round(y)))
    else
      bar.sel:SetText("표시를 드래그하거나 Tab 으로 고르면 화살표로 1px씩 옮길 수 있어요.")
    end
  end
end

function EM:SelectNext()
  local list = {}
  for _, item in ipairs(self.started or {}) do if item._target then list[#list + 1] = item end end
  if #list == 0 then return end
  local idx = 0
  for i, item in ipairs(list) do if item == self.selected then idx = i end end
  self:Select(list[idx % #list + 1])
end

function EM:SetGrid(on)
  buildOverlay()
  overlay:SetShown(on and self.active)
  setLabel(bar.grid, on and "격자 끄기" or "격자 켜기")
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
  self.history = {}
  self.selected = nil
  local names = {}
  for _, item in ipairs(items) do
    pcall(item.set, true)
    pcall(hookItem, item)
    names[#names + 1] = item.name
  end
  self.started = items
  if bar.list then bar.list:SetText("드래그해서 옮기기: " .. table.concat(names, " · ")) end
  bar:Show()
  guides:Show()
  self:SetGrid(true)
  self:Select(nil)
  if NT.UI and NT.UI.frame and NT.UI.frame:IsShown() then NT.UI.frame:Hide() end
  return true
end

function EM:Stop(silent)
  if not self.active then return end
  self.active = false
  for _, item in ipairs(self.started or {}) do pcall(item.set, false) end
  self.started = nil
  self.selected = nil
  self.dragging = nil
  if overlay then overlay:Hide() end
  if guides then guides:Hide() end
  if sel then sel:Hide() end
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
