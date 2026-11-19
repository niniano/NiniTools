-- NiniTools 2.8.12: WoW 포에버용 UI 배율 자동 (픽셀 퍼펙트).
-- 화면 세로 해상도에 맞춰 UI 배율을 768 ÷ 세로 로 맞춘다. FHD(1080) 0.711 · QHD(1440) 0.533.
-- 세로가 1600 을 넘으면(4K 등) 너무 작아지지 않게 두 배 (2160 → 0.711).
-- 와우 설정 칸은 0.64 아래로 못 내려가서, 그보다 작으면 설정값은 0.64 로 두고 화면 틀(UIParent) 배율을 직접 맞춘다.
-- 기본 꺼짐 (길드원 화면이 업데이트만으로 바뀌지 않게). 끄면 켜기 전 값으로 되돌린다.
-- NiniTools_Camelot.toc 에만 들어간다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local US = {}
NT.UIScaleAuto = US

local MIN_CVAR = 0.64
local pending = false

function US:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.uiScale
  if type(db) ~= "table" then db = {}; main.modules.uiScale = db end
  if db.enabled == nil then db.enabled = false end
  return db
end

function US:IsEnabled() return self:GetDB().enabled == true end

local function screenHeight()
  if type(GetPhysicalScreenSize) == "function" then
    local ok, w, h = pcall(GetPhysicalScreenSize)
    if ok and tonumber(h) and h > 0 then return tonumber(w), tonumber(h) end
  end
  local res = GetCVar and (GetCVar("gxFullscreenResolution") or GetCVar("gxWindowedResolution"))
  local w, h = type(res) == "string" and res:match("(%d+)x(%d+)")
  if h then return tonumber(w), tonumber(h) end
  return nil
end

-- 반환: 맞출 배율, 세로 해상도, 이름
function US:Target()
  local w, h = screenHeight()
  if not h then return nil end
  local s = 768 / h
  if h > 1600 then s = s * 2 end
  local name = (h == 1080 and "FHD") or (h == 1440 and "QHD") or (h == 2160 and "4K") or (w and (w .. "×" .. h)) or tostring(h)
  return s, h, name
end

local function inCombat() return InCombatLockdown and InCombatLockdown() end

function US:Apply()
  if not self:IsEnabled() then return end
  if inCombat() then pending = true; return end
  pending = false
  local s = self:Target()
  if not s then return end
  local db = self:GetDB()
  if db.prev == nil and GetCVar then
    db.prev = { use = GetCVar("useUiScale"), scale = GetCVar("uiScale") }
  end
  -- 이미 같은 값이면 다시 쓰지 않는다 (UI_SCALE_CHANGED 가 다시 불려 돌고 도는 것 막기)
  if SetCVar and GetCVar then
    if GetCVar("useUiScale") ~= "1" then pcall(SetCVar, "useUiScale", "1") end
    local want = math.max(MIN_CVAR, s)
    if math.abs((tonumber(GetCVar("uiScale")) or 0) - want) > 0.001 then pcall(SetCVar, "uiScale", tostring(want)) end
  end
  if UIParent and math.abs((UIParent:GetScale() or 1) - s) > 0.001 then UIParent:SetScale(s) end
end

function US:Restore()
  if inCombat() then pending = true; return end
  local db = self:GetDB()
  local prev = db.prev
  db.prev = nil
  if type(prev) ~= "table" or not SetCVar then return end
  if prev.use ~= nil then pcall(SetCVar, "useUiScale", prev.use) end
  if prev.scale ~= nil then pcall(SetCVar, "uiScale", prev.scale) end
  local s = tonumber(prev.scale) or 1
  if prev.use == "1" and UIParent then UIParent:SetScale(s) elseif UIParent then UIParent:SetScale(1) end
end

function US:SetEnabled(flag)
  self:GetDB().enabled = flag and true or false
  if flag then self:Apply() else self:Restore() end
  if pending then NT:Print("전투가 끝나면 UI 배율을 바꿀게요.") end
end

function US:StatusLine()
  local s, h, name = self:Target()
  local now = UIParent and UIParent:GetScale() or 1
  if not s then return string.format("화면 해상도를 못 읽었어요 · 지금 배율 %.3f", now) end
  return string.format("화면 %s(세로 %d) → 맞출 배율 %.3f · 지금 %.3f", name, h, s, now)
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("ForeverUIScale")
  or CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
  pcall(proxy.RegisterEvent, proxy, ev)
end
proxy:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if not pending then return end
    if US:IsEnabled() then US:Apply() else US:Restore() end
    return
  end
  if US:IsEnabled() then
    -- 블리자드가 같은 이벤트에서 배율을 다시 잡을 수 있어 한 프레임 뒤에 맞춘다
    if C_Timer and C_Timer.After then C_Timer.After(0, function() US:Apply() end) else US:Apply() end
  end
end)
