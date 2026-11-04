local ADDON_NAME = ...
local VERSION = _G.NiniTools.VERSION

local frame = _G.NiniTools.EventDispatcher:CreateProxy("Gold")
local db
local charKey
local lastMoney = 0
local ready = false
local minimapButton

local state = {
  merchant = false,
  auction = false,
  mail = false,
  repairPending = false,
  mailSnapshot = {},
  pendingMail = {},
  trade = {
    active = false,
    partner = nil,
    given = 0,
    received = 0,
    recentUntil = 0,
  },
}

local function isSecret(v)
  return type(issecretvalue) == "function" and issecretvalue(v)
end

local function safeString(v)
  if v == nil or isSecret(v) then return nil end
  if type(v) ~= "string" then return tostring(v) end
  return v
end

local function safeNumber(v)
  if v == nil or isSecret(v) then return nil end
  if type(v) == "number" then return v end
  return tonumber(v)
end

local function nowTime()
  if type(GetServerTime) == "function" then
    local v = safeNumber(GetServerTime())
    if v then return v end
  end
  return time()
end

local function dayKey(ts)
  return date("%Y-%m-%d", ts or nowTime())
end

local function monthKey(ts)
  return date("%Y-%m", ts or nowTime())
end

local function comma(n)
  n = math.floor(math.abs(tonumber(n) or 0))
  local s = tostring(n)
  local out = s
  while true do
    local changed
    out, changed = out:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
    if changed == 0 then break end
  end
  return out
end

local function moneyText(copper, short)
  copper = math.floor(math.abs(tonumber(copper) or 0))
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if short then
    if g > 0 then return comma(g) .. "골" end
    if s > 0 then return s .. "실" end
    return c .. "코"
  end
  if g > 0 then return string.format("%s골 %02d실 %02d코", comma(g), s, c) end
  if s > 0 then return string.format("%d실 %02d코", s, c) end
  return c .. "코"
end

local function signedMoney(copper)
  copper = tonumber(copper) or 0
  local sign = copper > 0 and "+" or (copper < 0 and "-" or "")
  return sign .. moneyText(copper, true)
end


local function newSummaryBucket()
  return {
    income = 0, expense = 0, repair = 0, net = 0,
    tradeIn = 0, tradeOut = 0,
    byChar = {},
  }
end

local function accumulateSummary(bucket, amount, kind, char)
  if not bucket then return end
  amount = tonumber(amount) or 0
  if amount > 0 then
    bucket.income = (bucket.income or 0) + amount
  elseif amount < 0 then
    bucket.expense = (bucket.expense or 0) + math.abs(amount)
  end
  bucket.net = (bucket.net or 0) + amount
  if kind == "repair" then bucket.repair = (bucket.repair or 0) + math.abs(amount) end
  if kind == "trade_in" then bucket.tradeIn = (bucket.tradeIn or 0) + math.max(amount, 0) end
  if kind == "trade_out" then bucket.tradeOut = (bucket.tradeOut or 0) + math.abs(math.min(amount, 0)) end

  char = char or "?"
  bucket.byChar = bucket.byChar or {}
  local c = bucket.byChar[char]
  if not c then
    c = { income = 0, expense = 0, repair = 0, net = 0 }
    bucket.byChar[char] = c
  end
  if amount > 0 then c.income = (c.income or 0) + amount
  elseif amount < 0 then c.expense = (c.expense or 0) + math.abs(amount) end
  c.net = (c.net or 0) + amount
  if kind == "repair" then c.repair = (c.repair or 0) + math.abs(amount) end
end

local function rebuildSummaries()
  db.stats = { lifetime = newSummaryBucket(), months = {} }
  for day, d in pairs(db.days or {}) do
    for _, e in ipairs(d.entries or {}) do
      local ts = tonumber(e.t)
      local mk = ts and monthKey(ts) or tostring(day):sub(1, 7)
      db.stats.months[mk] = db.stats.months[mk] or newSummaryBucket()
      accumulateSummary(db.stats.lifetime, e.amount, e.kind, e.char)
      accumulateSummary(db.stats.months[mk], e.amount, e.kind, e.char)
    end
  end
end

local function initDB()
  if _G.NiniTools then _G.NiniTools:BindModuleDB() end
  NiniGoldDB = NiniGoldDB or {}
  db = NiniGoldDB
  db.characters = db.characters or {}
  db.days = db.days or {}
  db.settings = db.settings or {}
  if db.settings.minimapAngle == nil then db.settings.minimapAngle = 220 end
  if db.settings.minimapHide == nil then db.settings.minimapHide = false end

  if not db.stats or not db.stats.lifetime or not db.stats.months or (tonumber(db.version) or 0) < 2 then
    rebuildSummaries()
  end
  db.version = 2
end

local function currentCharacterKey()
  local name = safeString(UnitName("player")) or "Unknown"
  local realm = safeString(GetRealmName()) or "Unknown"
  return realm .. "-" .. name
end

local function shortCharacterName(key)
  if not key then return "?" end
  local name = key:match("^[^-]+%-(.+)$")
  return name or key
end

local function ensureCharacter(captureMoney)
  if not db then return end
  charKey = charKey or currentCharacterKey()
  local rec = db.characters[charKey] or {}
  rec.name = safeString(UnitName("player")) or shortCharacterName(charKey)
  rec.realm = safeString(GetRealmName()) or ""
  rec.class = safeString(select(2, UnitClass("player")))

  if captureMoney ~= false then
    local money = safeNumber(GetMoney())
    if money ~= nil then rec.gold = money end
  end

  if rec.gold == nil then rec.gold = 0 end
  rec.lastSeen = nowTime()
  db.characters[charKey] = rec
end

local function notifyGoldChanged()
  if type(_G.NiniTools_GoldSnapshotChanged) == "function" then
    pcall(_G.NiniTools_GoldSnapshotChanged)
  end
end

local function syncInitialMoney()
  if not db then return false end
  charKey = charKey or currentCharacterKey()
  ensureCharacter(false)

  local current = safeNumber(GetMoney())
  if current == nil then return false end

  db.characters[charKey].gold = current
  db.characters[charKey].goldVerified = true
  db.characters[charKey].lastSeen = nowTime()
  lastMoney = current
  ready = true
  notifyGoldChanged()
  return true
end

local function ensureDay(key)
  key = key or dayKey()
  db.days[key] = db.days[key] or { entries = {} }
  db.days[key].entries = db.days[key].entries or {}
  return db.days[key]
end

local function pruneOldDays()
  local keys = {}
  for k in pairs(db.days) do keys[#keys + 1] = k end
  table.sort(keys, function(a,b) return a > b end)
  for i = 91, #keys do db.days[keys[i]] = nil end
end

local function recordEntry(amount, kind, who, detail)
  if not db or not charKey or not amount or amount == 0 then return end
  local d = ensureDay()
  local ts = nowTime()
  d.entries[#d.entries + 1] = {
    t = ts,
    char = charKey,
    amount = amount,
    kind = kind,
    who = safeString(who),
    detail = safeString(detail),
  }

  db.stats = db.stats or { lifetime = newSummaryBucket(), months = {} }
  db.stats.lifetime = db.stats.lifetime or newSummaryBucket()
  db.stats.months = db.stats.months or {}
  local mk = monthKey(ts)
  db.stats.months[mk] = db.stats.months[mk] or newSummaryBucket()
  accumulateSummary(db.stats.lifetime, amount, kind, charKey)
  accumulateSummary(db.stats.months[mk], amount, kind, charKey)

  if #d.entries > 1000 then table.remove(d.entries, 1) end
end

local function readTradePartner()
  -- Only the actual trade unit/recipient is authoritative; target can be unrelated.
  local name, realm
  if type(UnitFullName) == "function" then
    name, realm = UnitFullName("npc")
    name, realm = safeString(name), safeString(realm)
  end
  if name and name ~= "" then
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
  end
  if type(GetUnitName) == "function" then
    name = safeString(GetUnitName("npc", true))
    if name and name ~= "" then return name end
  end
  if TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
    local text = safeString(TradeFrameRecipientNameText:GetText())
    if text and text ~= "" then return text end
  end
end

local function readTradeMoney()
  if not state.trade.active then return end
  if type(GetPlayerTradeMoney) == "function" then
    local v = safeNumber(GetPlayerTradeMoney())
    if v then state.trade.given = v end
  end
  if type(GetTargetTradeMoney) == "function" then
    local v = safeNumber(GetTargetTradeMoney())
    if v then state.trade.received = v end
  end
  state.trade.partner = state.trade.partner or readTradePartner()
end

local function tradeMessage(messageType, message)
  local name
  messageType = safeNumber(messageType)
  if messageType and type(GetGameMessageInfo) == "function" then
    local ok, value = pcall(GetGameMessageInfo, messageType)
    if ok then name = safeString(value) end
  end
  message = safeString(message)
  if name == "ERR_TRADE_COMPLETE" or (message and ERR_TRADE_COMPLETE and message == ERR_TRADE_COMPLETE) then
    state.trade.completed = true
    state.trade.cancelled = false
    state.trade.active = false
    state.trade.recentUntil = GetTime() + 3
  elseif name == "ERR_TRADE_CANCELLED" or (message and ERR_TRADE_CANCELLED and message == ERR_TRADE_CANCELLED) then
    state.trade.cancelled = true
    state.trade.active = false
    state.trade.recentUntil = 0
  end
end

local function snapshotInbox()
  if not state.mail then return end
  wipe(state.mailSnapshot)
  local count = safeNumber(GetInboxNumItems and GetInboxNumItems()) or 0
  for i = 1, count do
    local _, _, sender, subject, money = GetInboxHeaderInfo(i)
    sender, subject, money = safeString(sender), safeString(subject), safeNumber(money)
    if money and money > 0 then
      state.mailSnapshot[i] = { sender = sender, subject = subject, money = money }
    end
  end
end

local function consumePendingMail(amount)
  for i, m in ipairs(state.pendingMail) do
    if m and m.money == amount then
      table.remove(state.pendingMail, i)
      return m
    end
  end
  if #state.pendingMail > 0 then return table.remove(state.pendingMail, 1) end
end

local function classifyAndRecord(delta, trade)
  local kind, who, detail
  local absAmount = math.abs(delta)

  local t = trade or state.trade
  local expected = (t.received or 0) - (t.given or 0)
  -- 2.0.19: ERR_TRADE_COMPLETE 가 UI_INFO_MESSAGE 로 오지 않는 클라이언트에서도
  -- 거래가 "기타"로 새지 않도록, 취소 없이 닫혔고 금액이 정확히 일치하면 완료로 본다.
  local closedCleanly = t.closed and not t.cancelled and expected ~= 0
  if (t.completed or closedCleanly) and not t.cancelled and not t.consumed and expected == delta
    and GetTime() <= (t.recentUntil or 0) then
    recordEntry(delta, delta > 0 and "trade_in" or "trade_out",
      t.partner, t.partner and "플레이어 거래" or "플레이어 거래 (상대 확인 불가)")
    t.consumed = true
    return
  end

  if state.merchant and delta < 0 and state.repairPending then
    state.repairPending = false
    recordEntry(delta, "repair", nil, "장비 수리")
    return
  end

  if state.mail and delta > 0 then
    local m = consumePendingMail(absAmount)
    if m then
      who = m.sender
      if AUCTION_HOUSE_MAIL_SELLER and safeString(AUCTION_HOUSE_MAIL_SELLER) == who then
        kind = "auction"
        detail = m.subject or "경매장 우편"
      else
        kind = "mail"
        detail = m.subject or "우편 골드"
      end
      recordEntry(delta, kind, who, detail)
      return
    end
  end

  if state.merchant then
    recordEntry(delta, delta > 0 and "vendor_in" or "vendor_out", nil, "상점")
    return
  end

  if state.auction then
    recordEntry(delta, "auction", nil, "경매장")
    return
  end

  recordEntry(delta, delta > 0 and "other_in" or "other_out", nil, "기타")
end

local function processMoneyChange()
  if not ready then return end
  local current = safeNumber(GetMoney())
  if not current then return end
  local delta = current - lastMoney
  if delta ~= 0 then
    local t = state.trade
    local expected = (t.received or 0) - (t.given or 0)
    if not t.completed and not t.closed and not t.cancelled and not t.consumed and expected == delta
      and (t.active or GetTime() <= (t.recentUntil or 0)) and C_Timer and C_Timer.After then
      -- PLAYER_MONEY and completion can arrive in either order. Retain this
      -- transaction object even when another trade is opened immediately.
      C_Timer.After(0.5, function()
        classifyAndRecord(delta, t)
        notifyGoldChanged()
      end)
    else
      classifyAndRecord(delta, t)
    end
  end
  lastMoney = current
  ensureCharacter()
  db.characters[charKey].gold = current
  db.characters[charKey].goldVerified = true
  db.characters[charKey].lastSeen = nowTime()
  notifyGoldChanged()
end

local function aggregateToday()
  local result = {
    income = 0, expense = 0, repair = 0, net = 0,
    tradeIn = 0, tradeOut = 0,
    byChar = {}, entries = {},
  }
  local d = db.days[dayKey()]
  if not d then return result end
  for _, e in ipairs(d.entries or {}) do
    local amount = tonumber(e.amount) or 0
    if amount > 0 then result.income = result.income + amount else result.expense = result.expense + math.abs(amount) end
    result.net = result.net + amount
    if e.kind == "repair" then result.repair = result.repair + math.abs(amount) end
    if e.kind == "trade_in" then result.tradeIn = result.tradeIn + amount end
    if e.kind == "trade_out" then result.tradeOut = result.tradeOut + math.abs(amount) end
    local c = e.char or "?"
    result.byChar[c] = result.byChar[c] or { income = 0, expense = 0, repair = 0, net = 0 }
    local r = result.byChar[c]
    if amount > 0 then r.income = r.income + amount else r.expense = r.expense + math.abs(amount) end
    if e.kind == "repair" then r.repair = r.repair + math.abs(amount) end
    r.net = r.net + amount
    result.entries[#result.entries + 1] = e
  end
  table.sort(result.entries, function(a,b) return (a.t or 0) > (b.t or 0) end)
  return result
end

local function currentMonthSummary()
  if not db or not db.stats or not db.stats.months then return newSummaryBucket() end
  return db.stats.months[monthKey()] or newSummaryBucket()
end

local function lifetimeSummary()
  if not db or not db.stats then return newSummaryBucket() end
  return db.stats.lifetime or newSummaryBucket()
end

local function trackedTotal()
  local total = 0
  for _, c in pairs(db.characters) do total = total + (tonumber(c.gold) or 0) end
  return total
end

local function printLine(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100NiniGold|r " .. tostring(msg))
end

local function printToday()
  local a = aggregateToday()
  local m = currentMonthSummary()
  local l = lifetimeSummary()
  printLine("오늘 수입 " .. moneyText(a.income, true) .. " / 지출 " .. moneyText(a.expense, true) .. " / 수리 " .. moneyText(a.repair, true) .. " / 순증감 " .. signedMoney(a.net))
  printLine("이번 달 수입 " .. moneyText(m.income, true) .. " / 지출 " .. moneyText(m.expense, true) .. " / 수리 " .. moneyText(m.repair, true) .. " / 순증감 " .. signedMoney(m.net))
  printLine("총 누계 수입 " .. moneyText(l.income, true) .. " / 지출 " .. moneyText(l.expense, true) .. " / 수리 " .. moneyText(l.repair, true) .. " / 순증감 " .. signedMoney(l.net))
  printLine("기록 캐릭터 총 보유골드: " .. moneyText(trackedTotal(), true))
  local chars = {}
  for key, c in pairs(db.characters) do chars[#chars+1] = { key=key, c=c } end
  table.sort(chars, function(x,y) return (x.c.gold or 0) > (y.c.gold or 0) end)
  for _, x in ipairs(chars) do
    local d = a.byChar[x.key] or { net = 0 }
    local cm = (m.byChar and m.byChar[x.key]) or { net = 0 }
    local cl = (l.byChar and l.byChar[x.key]) or { net = 0 }
    printLine(string.format("%s: %s (오늘 %s / 이번 달 %s / 누계 %s)",
      x.c.name or shortCharacterName(x.key), moneyText(x.c.gold or 0, true),
      signedMoney(d.net or 0), signedMoney(cm.net or 0), signedMoney(cl.net or 0)))
  end
end

local function toggleUI()
  -- 2.0.22: 골드 장부는 니니툴즈 통합 창에서만 연다.
  -- 구형 호출이 남아 있어도 별도 NiniGold 창이 다시 뜨지 않도록 라우팅한다.
  if _G.NiniTools and type(_G.NiniTools.ToggleUI)=="function" then
    _G.NiniTools:ToggleUI("GOLD")
    return
  end
  printLine("통합 골드 탭이 아직 준비되지 않았습니다.")
end

local function updateMinimapButtonPosition()
  if not minimapButton or not db or not Minimap then return end
  local angle = math.rad(tonumber(db.settings.minimapAngle) or 220)
  local radius = math.max(70, math.min(Minimap:GetWidth() or 140, Minimap:GetHeight() or 140) * 0.5 + 10)
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function updateMinimapAngleFromCursor()
  if not minimapButton or not db or not Minimap then return end
  local mx, my = Minimap:GetCenter()
  if not mx or not my then return end
  local scale = UIParent:GetEffectiveScale() or 1
  local cx, cy = GetCursorPosition()
  if not cx or not cy then return end
  cx, cy = cx / scale, cy / scale
  local angle = math.deg(math.atan2(cy - my, cx - mx))
  if angle < 0 then angle = angle + 360 end
  db.settings.minimapAngle = angle
  updateMinimapButtonPosition()
end

local function refreshMinimapTooltip()
  if not minimapButton or not minimapButton:IsMouseOver() or not db then return end
  local a = aggregateToday()
  GameTooltip:SetOwner(minimapButton, "ANCHOR_LEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("NiniGold " .. VERSION, 1, 0.82, 0)
  GameTooltip:AddLine(" ")
  local m = currentMonthSummary()
  local l = lifetimeSummary()
  GameTooltip:AddDoubleLine("현재 총골드", moneyText(trackedTotal(), true), 1, 1, 1, 1, 0.82, 0)
  local netColor = (a.net or 0) >= 0 and "|cff66ff66" or "|cffff6666"
  local monthColor = (m.net or 0) >= 0 and "|cff66ff66" or "|cffff6666"
  local lifeColor = (l.net or 0) >= 0 and "|cff66ff66" or "|cffff6666"
  GameTooltip:AddDoubleLine("오늘 순증감", netColor .. signedMoney(a.net or 0) .. "|r", 1, 1, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine("이번 달 순증감", monthColor .. signedMoney(m.net or 0) .. "|r", 1, 1, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine("총 누계 순증감", lifeColor .. signedMoney(l.net or 0) .. "|r", 1, 1, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine("오늘 수리비", moneyText(a.repair or 0, true), 1, 1, 1, 1, 0.67, 0.27)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("좌클릭: 니니툴즈 골드 탭", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("우클릭: 오늘 요약 채팅 출력", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("드래그: 아이콘 위치 이동", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function createMinimapButton()
  if minimapButton or not Minimap or not db then return minimapButton end

  local b = CreateFrame("Button", "NiniGoldMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(22, 22)
  icon:SetPoint("CENTER")
  icon:SetTexture((_G.NiniTools and _G.NiniTools.GetBrandMinimapIcon and _G.NiniTools:GetBrandMinimapIcon()) or (_G.NiniTools and _G.NiniTools.GetBrandRoundIcon and _G.NiniTools:GetBrandRoundIcon()) or "Interface\\AddOns\\NiniTools\\Media\\NiniTools_Minimap.tga")
  icon:SetTexCoord(0, 1, 0, 1)
  b.icon = icon

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(52, 52)
  border:SetPoint("CENTER", 10, -10)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b.border = border

  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      printToday()
    elseif _G.NiniTools and type(_G.NiniTools.ToggleUI)=="function" then
      -- 2.0.19: 별도 장부 창 대신 니니툴즈 골드 탭을 연다.
      _G.NiniTools:ToggleUI("GOLD")
    else
      toggleUI()
    end
  end)

  b:SetScript("OnEnter", refreshMinimapTooltip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  b:SetScript("OnDragStart", function(self)
    self.dragging = true
    self:SetScript("OnUpdate", updateMinimapAngleFromCursor)
  end)
  b:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    updateMinimapAngleFromCursor()
  end)

  minimapButton = b
  updateMinimapButtonPosition()
  if db.settings.minimapHide then b:Hide() else b:Show() end
  return b
end

local function setMinimapVisible(show)
  if type(_G.NiniTools_SetMinimapVisible)=="function" then
    _G.NiniTools_SetMinimapVisible(show)
    if db and db.settings then db.settings.minimapHide = not show end
    return
  end
  if not db then return end
  db.settings.minimapHide = not show
  local b = createMinimapButton()
  if not b then return end
  if show then
    b:Show()
    updateMinimapButtonPosition()
    printLine("미니맵 아이콘 표시")
  else
    b:Hide()
    GameTooltip:Hide()
    printLine("미니맵 아이콘 숨김")
  end
end

SLASH_NINIGOLD1 = "/ng"
SLASH_NINIGOLD2 = "/ninigold"
SlashCmdList.NINIGOLD = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "today" or msg == "오늘" then
    printToday()
  elseif msg == "version" then
    printLine("v" .. VERSION)
  elseif msg == "minimap" or msg == "mm" then
    setMinimapVisible(db and db.settings and db.settings.minimapHide)
  elseif msg == "old" or msg == "window" then
    -- 구형 명령도 통합 골드 탭으로 보낸다.
    toggleUI()
  else
    -- 2.0.19: 기본 동작은 니니툴즈 설정창의 골드 탭.
    if _G.NiniTools and type(_G.NiniTools.ToggleUI)=="function" then
      _G.NiniTools:ToggleUI("GOLD")
    else
      toggleUI()
    end
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name ~= ADDON_NAME then return end
    initDB()
    pruneOldDays()
    if type(RepairAllItems) == "function" then
      hooksecurefunc("RepairAllItems", function()
        state.repairPending = true
      end)
    end
    if type(TakeInboxMoney) == "function" then
      hooksecurefunc("TakeInboxMoney", function(index)
        local i = safeNumber(index)
        local m = i and state.mailSnapshot[i]
        if m and m.money and m.money > 0 then
          state.pendingMail[#state.pendingMail + 1] = { sender=m.sender, subject=m.subject, money=m.money }
        end
      end)
    end
  elseif event == "PLAYER_LOGIN" then
    initDB()
    charKey = currentCharacterKey()
    ready = false
    ensureCharacter(false)

    -- 캐릭터 전환 직후 GetMoney()가 초기값 0으로 보이는 타이밍을 피한다.
    -- 첫 유효 스냅샷을 기준선으로 잡은 뒤부터 실제 증감만 기록한다.
    if C_Timer and C_Timer.After then
      C_Timer.After(0.25, function()
        if not ready then syncInitialMoney() end
      end)
      C_Timer.After(1.00, function()
        if not ready then syncInitialMoney() else syncInitialMoney() end
      end)
      C_Timer.After(2.50, function()
        syncInitialMoney()
      end)
    else
      syncInitialMoney()
    end

    -- NiniTools 통합판에서는 개별 미니맵 버튼을 만들지 않습니다.
  elseif event == "PLAYER_ENTERING_WORLD" then
    if C_Timer and C_Timer.After then
      C_Timer.After(0.50, function() syncInitialMoney() end)
    else
      syncInitialMoney()
    end
  elseif event == "PLAYER_LOGOUT" then
    if db and charKey then
      -- 절대 여기서 GetMoney()를 다시 읽지 않는다.
      -- 로그아웃 단계에서는 GetMoney()가 0/불안정한 값으로 보일 수 있어
      -- 방금 플레이한 캐릭터의 저장 골드를 0으로 덮어쓰는 원인이 된다.
      ensureCharacter(false)
      if ready and type(db.characters[charKey])=="table" then
        db.characters[charKey].gold = tonumber(lastMoney) or db.characters[charKey].gold or 0
        db.characters[charKey].goldVerified = true
        db.characters[charKey].lastSeen = nowTime()
      end
      notifyGoldChanged()
    end
  elseif event == "PLAYER_MONEY" then
    if not ready then
      syncInitialMoney()
    else
      processMoneyChange()
    end
  elseif event == "MERCHANT_SHOW" then
    state.merchant = true
  elseif event == "MERCHANT_CLOSED" then
    state.merchant = false
    state.repairPending = false
  elseif event == "AUCTION_HOUSE_SHOW" then
    state.auction = true
  elseif event == "AUCTION_HOUSE_CLOSED" then
    state.auction = false
  elseif event == "MAIL_SHOW" then
    state.mail = true
    snapshotInbox()
  elseif event == "MAIL_INBOX_UPDATE" then
    snapshotInbox()
  elseif event == "MAIL_CLOSED" then
    state.mail = false
    wipe(state.mailSnapshot)
    wipe(state.pendingMail)
  elseif event == "UI_INFO_MESSAGE" then
    tradeMessage(...)
  elseif event == "TRADE_SHOW" then
    state.trade = {active=true, partner=readTradePartner(), given=0, received=0, recentUntil=0}
    local t = state.trade
    C_Timer.After(0, function()
      if state.trade == t and t.active then readTradeMoney() end
    end)
  elseif event == "TRADE_MONEY_CHANGED" or event == "TRADE_ACCEPT_UPDATE" or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" then
    if state.trade.active then readTradeMoney() end
  elseif event == "TRADE_CLOSED" then
    -- The native money widgets can already be cleared here. Keep the last
    -- offer and recipient captured while the trade was open.
    state.trade.active = false
    state.trade.closed = true
    if not state.trade.cancelled then state.trade.recentUntil = GetTime() + 3 end
  elseif event == "TRADE_REQUEST_CANCEL" then
    if not state.trade.completed then
      state.trade.cancelled = true
      state.trade.active = false
      state.trade.recentUntil = 0
    end
  end
end)

for _, event in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY",
  "MERCHANT_SHOW", "MERCHANT_CLOSED",
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
  "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED",
  "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE",
  "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
  "TRADE_CLOSED", "TRADE_REQUEST_CANCEL", "UI_INFO_MESSAGE",
}) do frame:RegisterEvent(event) end
