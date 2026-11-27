-- NiniTools 2.8.12: WoW 포에버용 던전 기록 (한 번 돈 던전 = 한 판).
-- 파티 던전에 들어가면 판을 시작하고 걸린 시간 · 얻은 골드 · 경험치 · 보스 잡은 시각(스플릿) · 죽은 횟수를 센다.
-- 밖에 나갔다가 15분 안에 같은 던전에 다시 들어오면(시체 찾기 · 수리) 같은 판으로 이어 간다.
-- 다른 던전에 들어가거나, 15분이 지나거나, 던전을 초기화하면 판을 끝내고 기록에 남긴다 (최근 30판).
-- NiniTools_Camelot.toc 에만 들어간다. 본섭은 쐐기 기록이 따로 있으니 싣지 않는다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local DR = {}
NT.DungeonRun = DR

local DEFAULTS = { enabled = true, panel = true, x = -420, y = 160 }
local REJOIN = 15 * 60
local KEEP = 30
local MIN_KEEP_SEC = 60

local panel
local unlocked = false

local function now() return (GetServerTime and GetServerTime()) or time() end

function DR:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.dungeonRun
  if type(db) ~= "table" then db = {}; main.modules.dungeonRun = db end
  for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
  db.runs = type(db.runs) == "table" and db.runs or {}
  return db
end

function DR:IsEnabled() return self:GetDB().enabled ~= false end

-- ── 글자 ──
local function comma(n)
  local s = tostring(math.floor(math.abs(tonumber(n) or 0)))
  local out, k = s, 0
  repeat out, k = out:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
  return out
end

function DR.Money(copper)
  copper = math.floor(math.abs(tonumber(copper) or 0))
  local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
  if g > 0 then return string.format("%s골 %d실", comma(g), s) end
  if s > 0 then return string.format("%d실 %d코", s, c) end
  return c .. "코"
end

function DR.Clock(sec)
  sec = math.max(0, math.floor(tonumber(sec) or 0))
  local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

function DR.XP(n) return comma(n) end

-- ── 판 관리 ──
function DR:Current() return self:GetDB().current end

function DR:Elapsed(run)
  run = run or self:Current()
  if not run then return 0 end
  return (run.ended or run.left or now()) - (run.start or now())
end

local function snapshotPlayer()
  local d = DR.track
  d.money = GetMoney and GetMoney() or 0
  d.xp = UnitXP and UnitXP("player") or 0
  d.xpMax = UnitXPMax and UnitXPMax("player") or 0
  d.level = UnitLevel and UnitLevel("player") or 0
end
DR.track = {}

function DR:Finish(reason)
  local db = self:GetDB()
  local run = db.current
  if not run then return end
  db.current = nil
  run.ended = run.left or now()
  run.left = nil
  run.reason = reason
  local dur = run.ended - (run.start or run.ended)
  if dur >= MIN_KEEP_SEC or #(run.bosses or {}) > 0 then
    table.insert(db.runs, run)
    while #db.runs > KEEP do table.remove(db.runs, 1) end
  end
  self:RefreshPanel()
  if NT.UI and NT.UI.RefreshVisiblePage and NT.UI.frame and NT.UI.frame:IsShown() then NT.UI:RefreshVisiblePage() end
end

function DR:Begin(name, instanceID, difficultyName)
  local db = self:GetDB()
  if db.current then self:Finish("new") end
  db.current = {
    name = name, instanceID = instanceID, diff = difficultyName,
    start = now(), date = date("%m/%d %H:%M"),
    gold = 0, spent = 0, xp = 0, deaths = 0, bosses = {},
    level = UnitLevel and UnitLevel("player") or nil,
  }
  snapshotPlayer()
  self:RefreshPanel()
end

-- 지금 있는 곳을 보고 판을 시작 · 이어 가기 · 잠시 나감으로 바꾼다.
function DR:CheckZone()
  if not self:IsEnabled() or type(GetInstanceInfo) ~= "function" then return end
  local db = self:GetDB()
  local run = db.current
  if run and run.left and now() - run.left > REJOIN then self:Finish("timeout"); run = nil end
  local name, itype, _, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  if itype == "party" then
    if run and run.instanceID == instanceID then
      if run.left then run.left = nil; snapshotPlayer() end
    else
      self:Begin(name, instanceID, difficultyName)
    end
  elseif run and not run.left then
    run.left = now()
  end
  self:RefreshPanel()
end

function DR:Inside()
  local run = self:Current()
  return run and not run.left
end

function DR:OnMoney()
  local d = self.track
  local m = GetMoney and GetMoney() or 0
  local delta = m - (d.money or m)
  d.money = m
  local run = self:Current()
  if not run or run.left or delta == 0 then return end
  if delta > 0 then run.gold = (run.gold or 0) + delta else run.spent = (run.spent or 0) - delta end
end

function DR:OnXP()
  local d = self.track
  local xp, max, lvl = UnitXP("player") or 0, UnitXPMax("player") or 0, UnitLevel("player") or 0
  local gain = 0
  if d.level and lvl > d.level then
    gain = math.max(0, (d.xpMax or 0) - (d.xp or 0)) + xp
  elseif d.xp and xp >= d.xp then
    gain = xp - d.xp
  end
  d.xp, d.xpMax, d.level = xp, max, lvl
  local run = self:Current()
  if run and not run.left and gain > 0 then run.xp = (run.xp or 0) + gain end
end

function DR:OnBoss(encounterID, name, success)
  local run = self:Current()
  if not run or run.left or success ~= 1 then return end
  for _, b in ipairs(run.bosses) do
    if (encounterID and b.id == encounterID) or b.name == name then return end
  end
  run.bosses[#run.bosses + 1] = { id = encounterID, name = name or "?", t = self:Elapsed(run) }
  self:RefreshPanel()
end

function DR:NewRun()
  self:Finish("manual")
  self:CheckZone()
  NT:Print(self:Inside() and "던전 기록: 새 판을 시작했어요." or "던전 기록: 지난 판을 끝냈어요. 던전에 들어가면 새로 시작해요.")
end

-- 한 줄 요약 (홈 · 설정 화면용)
function DR:Line(run)
  local xpRate = ""
  local dur = self:Elapsed(run)
  if (run.xp or 0) > 0 and dur > 60 then xpRate = string.format(" (%s/시간)", DR.XP(run.xp / dur * 3600)) end
  return string.format("%s · %s · %s · 골드 +%s · XP %s%s · 보스 %d%s",
    run.date or "?", run.name or "?", DR.Clock(dur), DR.Money(run.gold), DR.XP(run.xp), xpRate,
    #(run.bosses or {}), (run.deaths or 0) > 0 and (" · 죽음 " .. run.deaths) or "")
end

function DR:Splits(run)
  local parts = {}
  for i, b in ipairs(run.bosses or {}) do parts[#parts + 1] = string.format("%d. %s %s", i, b.name, DR.Clock(b.t)) end
  return table.concat(parts, "  ·  ")
end

-- ── 화면 패널 ──
local function accent()
  local C = NT.UI and NT.UI.C
  if C then return C.accent[1], C.accent[2], C.accent[3] end
  return 0, .81, 1
end

local function buildPanel()
  if panel then return panel end
  panel = CreateFrame("Frame", "NiniToolsDungeonRunPanel", UIParent, "BackdropTemplate")
  panel:SetSize(260, 84)   -- 2.8.22: 글씨 2pt 키움 (사용자)
  panel:SetFrameStrata("MEDIUM")
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(false)
  panel:RegisterForDrag("LeftButton")
  if panel.SetBackdrop then
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel:SetBackdropColor(.03, .04, .055, .72)
    panel:SetBackdropBorderColor(.14, .18, .22, .9)
  end
  local font = (NT.NumberFont and select(2, pcall(NT.NumberFont, NT))) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  if type(font) ~= "string" then font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
  local function fs(size, r, g, b)
    local t = panel:CreateFontString(nil, "OVERLAY")
    t:SetFont(STANDARD_TEXT_FONT or font, size, "OUTLINE")
    t:SetTextColor(r, g, b, 1)
    t:SetJustifyH("LEFT")
    return t
  end
  panel.title = fs(13, accent())
  panel.title:SetPoint("TOPLEFT", 9, -7); panel.title:SetPoint("RIGHT", -74, 0)
  if panel.title.SetWordWrap then panel.title:SetWordWrap(false) end
  panel.clock = panel:CreateFontString(nil, "OVERLAY")
  panel.clock:SetFont(font, 16, "OUTLINE")
  panel.clock:SetTextColor(1, 1, 1, 1)
  panel.clock:SetPoint("TOPRIGHT", -9, -6)
  panel.stats = fs(12, .9, .93, .96)
  panel.stats:SetPoint("TOPLEFT", 9, -29); panel.stats:SetPoint("RIGHT", -9, 0)
  panel.splits = fs(12, .62, .7, .78)
  panel.splits:SetPoint("TOPLEFT", 9, -48); panel.splits:SetPoint("RIGHT", -9, 0)
  panel:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not ux then return end
    local db = DR:GetDB()
    db.x, db.y = math.floor(cx - ux + .5), math.floor(cy - uy + .5)
    self:ClearAllPoints(); self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  end)
  panel.acc = 0
  panel:SetScript("OnUpdate", function(self, elapsed)
    self.acc = self.acc + (elapsed or 0)
    if self.acc < .5 then return end
    self.acc = 0
    DR:PaintPanel()
  end)
  local db = DR:GetDB()
  panel:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULTS.x, db.y or DEFAULTS.y)
  panel:Hide()
  return panel
end

local SAMPLE = { name = "죽음의 폐광", start = 0, gold = 123456, xp = 18400, deaths = 0,
  bosses = { { name = "루즈니크", t = 312 }, { name = "길녹", t = 655 } } }

function DR:PaintPanel()
  if not panel then return end
  local run = self:Current()
  local sample = false
  if not (run and not run.left) then
    if not unlocked then return end
    run, sample = SAMPLE, true
  end
  local dur = sample and 1342 or self:Elapsed(run)
  panel.title:SetText(run.name or "던전")
  panel.clock:SetText(DR.Clock(dur))
  local rate = ""
  if (run.xp or 0) > 0 and dur > 60 then rate = string.format(" · %s/시간", DR.XP(run.xp / dur * 3600)) end
  panel.stats:SetText(string.format("골드 +%s   XP %s%s%s", DR.Money(run.gold), DR.XP(run.xp), rate,
    (run.deaths or 0) > 0 and ("   죽음 " .. run.deaths) or ""))
  local lines = {}
  local list = run.bosses or {}
  local from = math.max(1, #list - 3)
  for i = from, #list do lines[#lines + 1] = string.format("%d. %s  %s", i, list[i].name, DR.Clock(list[i].t)) end
  if #lines == 0 then lines[1] = "보스 아직 없음" end
  panel.splits:SetText(table.concat(lines, "\n"))
  panel:SetHeight(56 + #lines * 15)
end

function DR:RefreshPanel()
  local db = self:GetDB()
  local want = unlocked or (db.enabled ~= false and db.panel ~= false and self:Inside())
  if not want then
    if panel then panel:Hide() end
    return
  end
  buildPanel()
  panel:EnableMouse(unlocked)
  panel:Show()
  self:PaintPanel()
end

function DR:SetEnabled(flag)
  local db = self:GetDB()
  db.enabled = flag and true or false
  if db.enabled then self:CheckZone() else self:Finish("off") end
  self:RefreshPanel()
end

function DR:SetPanel(flag)
  self:GetDB().panel = flag and true or false
  self:RefreshPanel()
end

function DR:IsUnlocked() return unlocked end
function DR:SetUnlocked(flag)
  unlocked = flag and true or false
  self:RefreshPanel()
end
function DR:PanelFrame() return buildPanel() end

function DR:ResetPosition()
  local db = self:GetDB()
  db.x, db.y = DEFAULTS.x, DEFAULTS.y
  if panel then panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y) end
end

function DR:ClearHistory()
  self:GetDB().runs = {}
end

-- ── 이벤트 ──
local resetPattern
local function isResetMessage(msg)
  if type(msg) ~= "string" then return false end
  if resetPattern == nil then
    local fmt = _G.INSTANCE_RESET_SUCCESS
    if type(fmt) == "string" then fmt = fmt:gsub("|1[^;]*;[^;]*;", "") end   -- 한글 조사 표시(|1이;가;) 빼기
    resetPattern = type(fmt) == "string" and ("^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", ".+") .. "$") or false
  end
  return resetPattern and msg:match(resetPattern) ~= nil or false
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("ForeverDungeonRun")
  or CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY",
  "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "ENCOUNTER_END", "CHAT_MSG_SYSTEM" }) do
  pcall(proxy.RegisterEvent, proxy, ev)
end
proxy:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    snapshotPlayer()
    return
  end
  if not DR:IsEnabled() then return end
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if event == "PLAYER_ENTERING_WORLD" then snapshotPlayer() end
    DR:CheckZone()
  elseif event == "PLAYER_MONEY" then
    DR:OnMoney()
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    DR:OnXP()
  elseif event == "PLAYER_DEAD" then
    local run = DR:Current()
    if run and not run.left then run.deaths = (run.deaths or 0) + 1 end
  elseif event == "ENCOUNTER_END" then
    local encounterID, name, _, _, success = ...
    DR:OnBoss(encounterID, name, success)
  elseif event == "CHAT_MSG_SYSTEM" then
    local run = DR:Current()
    if run and run.left and isResetMessage((...)) then DR:Finish("reset") end
  end
end)
