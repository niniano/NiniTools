-- NiniTools 2.8.12: 홈 페이지.
-- 창을 열면 기능 페이지로 가기 전에 지금 상태를 카드로 한눈에 본다. 카드를 누르면 그 페이지로 간다.
--   본섭: NSRT 메모 · 생존기 알림 담당(Naowh / NiniTools) · 골드 · 마지막 보스 풀 애드온 부하
--   포에버: 골드 · 던전 기록 · 전투 시간 · 주시 매크로
-- 아래에는 자주 쓰는 버튼, 최근 기록, 새 소식 요약.
local ADDON_NAME, NT = ...
if not NT then return end
local UI = NT.UI
if not UI then return end
local C = UI.C

local CARD_H = 104
local GAP = 10

local function goldDB()
  local g = _G.NiniGoldDB
  return type(g) == "table" and g or nil
end

local function moneyShort(copper, signed)
  copper = tonumber(copper) or 0
  local g = math.floor(math.abs(copper) / 10000)
  local s = math.floor(math.abs(copper) % 10000 / 100)
  local txt
  if g > 0 then
    local str = tostring(g)
    repeat local k; str, k = str:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
    txt = str .. "골"
  else
    txt = s .. "실"
  end
  if signed then return (copper > 0 and "+" or (copper < 0 and "-" or "")) .. txt end
  return txt
end

local function todayNet()
  local g = goldDB()
  local now = (GetServerTime and GetServerTime()) or time()
  local d = g and type(g.days) == "table" and g.days[date("%Y-%m-%d", now)]
  local net = 0
  for _, e in ipairs(d and d.entries or {}) do net = net + (tonumber(e.amount) or 0) end
  return net
end

local function trackedTotal()
  local g = goldDB()
  local total, n = 0, 0
  for _, c in pairs(g and g.characters or {}) do
    total = total + (tonumber(c.gold) or 0); n = n + 1
  end
  return total, n
end

local function tone(c, name)
  local col = C[name] or C.text
  c.value:SetTextColor(col[1], col[2], col[3], 1)
end

-- 카드 정의: available() 이 false 면 빼고, fill(card) 가 value · hint 를 채운다.
local CARDS = {
  { id = "nsrt", title = "NSRT 개인 메모", page = "NSRT",
    available = function() return not NT.FOREVER and NT.NSRTImport ~= nil end,
    fill = function(c)
      local st = NT.NSRTImport:HomeStatus()
      if not st.loaded then
        c.value:SetText("NSRT 없음"); tone(c, "muted")
        c.hint:SetText("NSRT 를 켜면 메모 상태가 보여요")
        return
      end
      c.value:SetText(string.format("메모 %d개", st.personal)); tone(c, "text")
      local miss = st.missing > 0 and UI:ColorText(string.format("빠진 메모 %d개 · 눌러서 넣기", st.missing), C.warn)
        or "빠진 메모 없음"
      c.hint:SetText(string.format("프로필 %s · 보관함 %d · %s", tostring(st.profile or "?"), st.vault, miss))
    end },
  { id = "defensive", title = "생존기 알림", page = "KICK",
    available = function() return not NT.FOREVER end,
    fill = function(c)
      local A = NT.Adapters
      local s = A and type(A.GetNaowhReminderState) == "function" and A:GetNaowhReminderState() or nil
      if s and s.owner == "naowh" then c.value:SetText("Naowh 담당"); tone(c, "good")
      elseif s and s.override then c.value:SetText("NiniTools 강제"); tone(c, "accent")
      else c.value:SetText("NiniTools 담당"); tone(c, "accent") end
      local L = NT.NaowhUILink
      local ok, st = pcall(function() return L and L:Status() end)
      if ok and type(st) == "table" and st.installed then
        c.hint:SetText(string.format("NaowhUI%s · %s", st.version and (" v" .. st.version) or "",
          st.loaded and (#st.applied > 0 and ("프로필 " .. #st.applied .. "개 적용") or "프로필 아직 없음") or "꺼져 있음"))
      else
        c.hint:SetText("NaowhUI 미설치")
      end
    end },
  { id = "gold", title = "골드", page = "GOLD",
    available = function() return true end,
    fill = function(c)
      local total, n = trackedTotal()
      if n == 0 then total = GetMoney and GetMoney() or 0 end
      c.value:SetText(moneyShort(total)); tone(c, "text")
      local net = todayNet()
      c.hint:SetText(string.format("캐릭터 %d명 합계 · 오늘 %s", math.max(1, n),
        net == 0 and "변동 없음" or UI:ColorText(moneyShort(net, true), net > 0 and C.good or C.bad)))
    end },
  { id = "perf", title = "애드온 부하 (마지막 보스)", page = "TOOLS",
    available = function() return not NT.FOREVER and NT.AddonPerf ~= nil and NT.AddonPerf.LastPull ~= nil end,
    fill = function(c)
      local p = NT.AddonPerf:LastPull()
      if not p then
        c.value:SetText("기록 없음"); tone(c, "muted")
        c.hint:SetText("보스 풀이 끝나면 채워져요")
        return
      end
      local top = p.addons and p.addons[1]
      local spikes = 0
      for _, r in ipairs(p.addons or {}) do spikes = spikes + (r.n50 or 0) end
      if top then
        c.value:SetText(string.format("%s %.1fms", top.a, top.avg or 0))
        tone(c, spikes >= 5 and "warn" or "text")
      else
        c.value:SetText(p.error and "측정 불가" or "부하 없음"); tone(c, "muted")
      end
      c.hint:SetText(string.format("%s · %s · 50ms 넘은 프레임 %d번", tostring(p.name or p.enc or "?"),
        p.success and "킬" or "전멸", spikes))
    end },
  { id = "drun", title = "던전 기록", page = "QOL",
    available = function() return NT.FOREVER and NT.DungeonRun ~= nil end,
    fill = function(c)
      local DR = NT.DungeonRun
      local db = DR:GetDB()
      local run = DR:Current() or db.runs[#db.runs]
      if not run then
        c.value:SetText("기록 없음"); tone(c, "muted")
        c.hint:SetText("파티 던전에 들어가면 자동으로 시작")
        return
      end
      local live = DR:Current() == run and not run.left
      c.value:SetText((live and "지금 " or "") .. DR.Clock(DR:Elapsed(run))); tone(c, live and "good" or "text")
      c.hint:SetText(string.format("%s · 골드 +%s · XP %s · 보스 %d", run.name or "?", DR.Money(run.gold), DR.XP(run.xp),
        #(run.bosses or {})))
    end },
  { id = "ctimer", title = "전투 시간", page = "QOL",
    available = function() return NT.FOREVER and NT.CombatTimer ~= nil end,
    fill = function(c)
      local on = NT.CombatTimer:IsEnabled()
      c.value:SetText(on and "켜짐" or "꺼짐"); tone(c, on and "accent" or "muted")
      c.hint:SetText(string.format("글자 %dpx · 위치는 「위치 편집」으로", NT.CombatTimer:GetSize()))
    end },
  { id = "fmacro", title = "주시 · 차단 매크로", page = "QOL",
    available = function() return NT.FOREVER and NT.ForeverMacros ~= nil end,
    fill = function(c)
      local F = NT.ForeverMacros
      local on = F:GetDB().enabled ~= false
      c.value:SetText(on and (F.MARKER_NAMES[F:GetDB().marker] or "켜짐") or "꺼짐"); tone(c, on and "accent" or "muted")
      local ok, st = pcall(F.Status, F)
      c.hint:SetText(ok and tostring(st or "") or "")
    end },
}

local function makeCard(p, def)
  local c = UI:Card(p, def.title, "", "", 0, 0, 220, CARD_H)
  c.def = def
  c:EnableMouse(true)
  c.hint:SetWordWrap(true)
  c.go = UI:Font(c, 9, "›", C.muted); c.go:SetPoint("TOPRIGHT", -12, -12)
  c:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], .9)
    self.go:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  c:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], .68)
    self.go:SetTextColor(C.muted[1], C.muted[2], C.muted[3], 1)
  end)
  c:SetScript("OnMouseUp", function(self)
    if self.def.id == "nsrt" and NT.NSRTImport then
      local ok, st = pcall(NT.NSRTImport.HomeStatus, NT.NSRTImport)
      if ok and st.missing > 0 then
        pcall(NT.NSRTImport.OpenRestorePicker, NT.NSRTImport, false)
        return
      end
    end
    UI:ShowPage(self.def.page)
  end)
  return c
end

function UI:BuildHome()
  local p = self:NewPage("HOME")
  p.cards = {}
  for _, def in ipairs(CARDS) do
    local ok, yes = pcall(def.available)
    if ok and yes then p.cards[#p.cards + 1] = makeCard(p, def) end
  end

  local y = -8 - CARD_H - 14

  -- 빠른 실행
  local quick = self:Section(p, "빠른 실행", nil, y, 92)
  local btns = {}
  local function add(text, fn) btns[#btns + 1] = self:Button(quick, text, 140, 30, fn) end
  add("위치 편집", function() if NT.EditMode then NT.EditMode:Start() end end)
  if not NT.FOREVER then
    add("NSRT 메모 고르기", function()
      local NR = NT.NSRTImport
      if not NR or not NR:IsNSRTLoaded() then NT:Print("NSRT가 켜져 있을 때 쓸 수 있어요."); return end
      pcall(NR.SnapshotVault, NR)
      local ok, n = pcall(NR.OpenRestorePicker, NR, true)
      if ok and n == 0 then NT:Print("지금 NSRT 프로필에 보관한 메모가 모두 있어요.") end
    end)
    add("부하 기록 보기", function() if UI.ShowPerfLog then UI:ShowPerfLog() end end)
  else
    add("던전 새 판", function() if NT.DungeonRun then NT.DungeonRun:NewRun(); UI:RefreshVisiblePage() end end)
  end
  add("새 소식", function() if NT.News then NT.News:Show(true) end end)
  add("UI 다시 불러오기", function() ReloadUI() end)
  for i, b in ipairs(btns) do
    if i == 1 then b:SetPoint("TOPLEFT", 16, -44) else b:SetPoint("LEFT", btns[i - 1], "RIGHT", 10, 0) end
  end
  y = y - 92 - 10

  -- 최근 기록
  local recentTitle = NT.FOREVER and "최근 던전" or "최근 보스 풀 부하"
  local recentSub = NT.FOREVER and "판마다 시간 · 골드 · XP · 보스 수 (자세한 스플릿은 화면 & 편의 → 전투 & 던전)"
    or "보스 풀마다 무거웠던 애드온 상위 3개 (전체는 「부하 기록 보기」)"
  local recent = self:Section(p, recentTitle, recentSub, y, 132)
  p.recentText = self:Font(recent, 9, "", C.text)
  p.recentText:SetPoint("TOPLEFT", 16, -56); p.recentText:SetPoint("RIGHT", -16, 0)
  p.recentText:SetJustifyH("LEFT"); p.recentText:SetJustifyV("TOP")
  if p.recentText.SetSpacing then p.recentText:SetSpacing(4) end
  if p.recentText.SetWordWrap then p.recentText:SetWordWrap(false) end
  y = y - 132 - 10

  -- 새 소식 요약
  local news = self:Section(p, "새 소식", "이번 버전에서 바뀐 것 · 제목줄 버전 글자를 눌러도 다시 볼 수 있어요", y, 150)
  p.newsText = self:Font(news, 9, "", C.text)
  p.newsText:SetPoint("TOPLEFT", 16, -56); p.newsText:SetPoint("RIGHT", -16, 0)
  p.newsText:SetJustifyH("LEFT"); p.newsText:SetJustifyV("TOP")
  if p.newsText.SetSpacing then p.newsText:SetSpacing(4) end
  if p.newsText.SetWordWrap then p.newsText:SetWordWrap(false) end
  y = y - 150 - 10
  p.contentHeight = -y + 8

  local function layoutCards()
    local n = #p.cards
    if n == 0 then return end
    local w = math.max(600, (p:GetWidth() or 984)) - 32
    local cw = math.floor((w - GAP * (n - 1)) / n)
    for i, c in ipairs(p.cards) do
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 16 + (i - 1) * (cw + GAP), -8)
      c:SetSize(cw, CARD_H)
    end
  end

  p.Refresh = function(self)
    layoutCards()
    for _, c in ipairs(self.cards) do
      local ok, err = pcall(c.def.fill, c)
      if not ok then c.value:SetText("?"); c.hint:SetText(tostring(err)) end
    end

    local lines = {}
    if NT.FOREVER then
      local DR = NT.DungeonRun
      if DR then
        local db = DR:GetDB()
        local cur = DR:Current()
        if cur then lines[#lines + 1] = UI:ColorText((cur.left and "잠시 나감 · " or "지금 · ") .. DR:Line(cur), C.accent) end
        for i = #db.runs, math.max(1, #db.runs - 4), -1 do lines[#lines + 1] = DR:Line(db.runs[i]) end
      end
      if #lines == 0 then lines[1] = UI:ColorText("아직 기록이 없어요.", C.muted) end
    else
      local AP = NT.AddonPerf
      local ok, list = pcall(function() return AP and AP:SummaryLines(4) end)
      if ok and type(list) == "table" then
        for i = #list, 2, -1 do lines[#lines + 1] = list[i] end   -- 1번 줄은 머리말
      end
      if #lines == 0 then lines[1] = UI:ColorText("아직 기록이 없어요. 보스 풀이 끝나면 채워져요.", C.muted) end
    end
    self.recentText:SetText(table.concat(lines, "\n"))

    local newsLines = {}
    local entries = NT.News and NT.News:Entries(nil) or {}
    for _, entry in ipairs(entries) do
      for _, card in ipairs(entry.cards or {}) do
        if #newsLines < 4 then
          newsLines[#newsLines + 1] = UI:ColorText("v" .. entry.version .. "  " .. card.title, C.accent)
            .. "  " .. UI:ColorText(tostring(card.lines and card.lines[1] or ""), C.muted)
        end
      end
    end
    if #newsLines == 0 then newsLines[1] = UI:ColorText("새 소식이 없어요.", C.muted) end
    self.newsText:SetText(table.concat(newsLines, "\n"))
  end
  if p.viewport then p.viewport:HookScript("OnSizeChanged", layoutCards) end
end
