-- NiniTools 2.8.3: WoW 포에버용 파티 입장 인사 「안녕하세요.」
-- 본섭은 차단 모듈(Modules/Kick/Core.lua · 2.0.7)의 같은 기능을 쓰고, 이 파일은 NiniTools_Camelot.toc 에만 들어간다.
-- 규칙:
--   · 혼자 → 파티가 될 때 1초 뒤 한 번 (파티 채팅, 인스턴스 그룹이면 인스턴스 채팅)
--   · 2.8.4: 「남의 파티에 들어갈 때만」 — 내가 파티장이면(내가 초대해서 만든 파티) 인사하지 않음.
--     던전 찾기처럼 자동으로 모인 인스턴스 그룹은 파티장이 누구든 인사함.
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
local function inInstanceGroup() return LE_PARTY_CATEGORY_INSTANCE ~= nil and call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) end
-- 2.8.4: 내가 만든 파티(내가 파티장)는 인사 안 함 · 인스턴스 그룹은 예외
local function joinedSomeoneElses()
  if inInstanceGroup() then return true end
  return not call(UnitIsGroupLeader, "player")
end
PG.JoinedSomeoneElses = joinedSomeoneElses
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
    -- 파티장 정보가 늦게 들어올 수 있어 1초 뒤 보내기 직전에 판단한다
    if mine ~= serial or not PG:IsEnabled() or not eligible() or not joinedSomeoneElses() then return end
    local channel = "PARTY"
    if inInstanceGroup() then channel = "INSTANCE_CHAT" end
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
