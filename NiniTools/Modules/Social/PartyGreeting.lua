-- NiniTools 2.8.3: WoW 포에버용 파티 입장 인사 「안녕하세요.」
-- 본섭은 차단 모듈(Modules/Kick/Core.lua · 2.0.7)의 같은 기능을 쓰고, 이 파일은 NiniTools_Camelot.toc 에만 들어간다.
-- 규칙은 본섭과 같다:
--   · 혼자 → 파티가 될 때만 1초 뒤 한 번 (파티 채팅, 인스턴스 그룹이면 인스턴스 채팅)
--   · 공격대는 인사하지 않음 · 파티 ↔ 공격대 전환, /reload, 지역 이동으로는 다시 인사하지 않음
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local PG = {}
NT.PartyGreeting = PG

local GREETING = "안녕하세요."
local DELAY = 1.0

local initialized, wasInGroup, serial = false, false, 0

function PG:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.partyGreeting
  if type(db) ~= "table" then db = {}; main.modules.partyGreeting = db end
  if db.enabled == nil then db.enabled = true end
  return db
end

function PG:IsEnabled() return self:GetDB().enabled ~= false end
function PG:SetEnabled(flag) self:GetDB().enabled = flag and true or false end

local function call(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, ...)
  return ok and v and true or false
end

local function inAnyGroup() return call(IsInGroup) or call(IsInRaid) end
local function eligible() return inAnyGroup() and not call(IsInRaid) end

local function update(initializing)
  local grouped = inAnyGroup()
  if initializing or not initialized then
    initialized, wasInGroup = true, grouped
    serial = serial + 1
    return
  end
  local was = wasInGroup
  wasInGroup = grouped
  if not grouped then serial = serial + 1; return end
  if was or not eligible() or not PG:IsEnabled() then return end

  serial = serial + 1
  local mine = serial
  C_Timer.After(DELAY, function()
    if mine ~= serial or not PG:IsEnabled() or not eligible() then return end
    local channel = "PARTY"
    if LE_PARTY_CATEGORY_INSTANCE and call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) then channel = "INSTANCE_CHAT" end
    if type(SendChatMessage) == "function" then pcall(SendChatMessage, GREETING, channel) end
  end)
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("ForeverPartyGreeting")
  or CreateFrame("Frame")
proxy:RegisterEvent("PLAYER_ENTERING_WORLD")
proxy:RegisterEvent("GROUP_ROSTER_UPDATE")
proxy:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    -- 접속 · /reload · 지역 이동: 지금 상태를 기준으로만 잡는다 (이미 파티면 인사 안 함)
    update(not initialized)
  else
    update(false)
  end
end)
