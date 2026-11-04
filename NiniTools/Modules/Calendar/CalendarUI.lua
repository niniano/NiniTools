local ADDON_NAME, NT = ...
if not NT or not NT.UI then return end

-- 2.5.8: 계정 달력 화면 (NiniTools 창 「계정 달력」 탭)
-- 2.5.9: 오른쪽 위 초대 목록을 초대 수만큼만 · 상세를 바로 아래로 · 참가자 16줄 · 위 목록에서 휠 → 참가자 목록
local UI = NT.UI
local M = NT.AccountCalendar

local C = UI.C or {
  panel = { .075, .098, .125 }, panel2 = { .094, .122, .153 }, border = { .141, .176, .212 },
  text = { .94, .97, 1 }, muted = { .49, .58, .66 }, accent = { 0, .81, 1 },
  good = { .35, .9, .55 }, warn = { 1, .72, .25 }, bad = { 1, .35, .35 },
}
local GOLD = { 0.957, 0.698, 0.227 }
local TEAL = { 0.22, 0.84, 0.77 }
local GROUP_COLOR = { yes = C.good, maybe = C.warn, wait = GOLD, no = { .55, .58, .62 }, info = { .62, .70, .78 } }
local WEEK = { "일", "월", "화", "수", "목", "금", "토" }

local GX, GY = 16, -64
local CW, CH, GAP = 80, 64, 2
local HEAD_H = 22
local RX = GX + 7 * (CW + GAP) + 12
local RW = 984 - RX - 16
local DAY_ROWS = 4    -- 2.5.9: 그날 초대 목록은 초대 수만큼만 (최대 4줄, 넘으면 휠)
local PART_ROWS = 16  -- 2.5.9: 참가자 목록을 더 길게

local function F(parent, size, text, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local path = (NT.BodyFont and NT:BodyFont()) or STANDARD_TEXT_FONT
  if not pcall(fs.SetFont, fs, path, size, "OUTLINE") then pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, "OUTLINE") end
  fs:SetText(text or "")
  local c = color or C.text
  fs:SetTextColor(c[1], c[2], c[3], 1)
  fs:SetJustifyH("LEFT")
  return fs
end

local function hex(c) return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + .5), math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5)) end

local function classHex(cls)
  local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if c then return string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + .5), math.floor(c.g * 255 + .5), math.floor(c.b * 255 + .5)) end
  return "|cffd8dee6"
end

local function className(cls)
  return (cls and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls]) or cls or "?"
end

local function ago(t)
  if not t then return "아직 없음" end
  local s = math.max(0, ((time and time()) or 0) - t)
  if s < 90 then return "방금" end
  if s < 3600 then return math.floor(s / 60) .. "분 전" end
  if s < 86400 then return math.floor(s / 3600) .. "시간 전" end
  return math.floor(s / 86400) .. "일 전"
end

local function hhmm(e) return string.format("%02d:%02d", e.h or 0, e.mi or 0) end

local function panel(parent, x, y, w, h)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", x, y)
  f:SetSize(w, h)
  UI:Backdrop(f, C.panel, C.border)
  f:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.68)
  f:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.54)
  return f
end

local function smallButton(parent, text, w, fn)
  local b = UI:Button(parent, text, w, 24, fn)
  b:SetHeight(24)
  return b
end

local function setEnabled(b, on, why)
  b:SetEnabled(on and true or false)
  b:SetAlpha(on and 1 or 0.38)
  b.disabledWhy = (not on) and why or nil
end

-- ── 복사 창 (로그 주소) ───────────────────────────────
local copyBox
local function ShowCopy(title, text)
  if not copyBox then
    local f = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    f:SetSize(520, 108)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel((UI.frame:GetFrameLevel() or 1) + 90)
    UI:Backdrop(f, C.panel2, C.border)
    f:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
    f.title = F(f, 12, "", C.accent); f.title:SetPoint("TOPLEFT", 14, -12)
    f.hint = F(f, 11, "Ctrl+C 로 복사한 뒤 브라우저에 붙여넣으세요 · Esc 닫기", C.muted); f.hint:SetPoint("BOTTOMLEFT", 14, 12)
    local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    eb:SetPoint("TOPLEFT", 14, -36); eb:SetPoint("TOPRIGHT", -14, -36); eb:SetHeight(28)
    UI:Backdrop(eb, C.panel, C.border)
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetAutoFocus(false)
    pcall(eb.SetFont, eb, (NT.BodyFont and NT:BodyFont()) or STANDARD_TEXT_FONT, 12, "")
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.value or ""); self:HighlightText() end end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.eb = eb
    local x = CreateFrame("Button", nil, f)
    x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -6, -6)
    x.label = F(x, 14, "×", C.muted); x.label:SetPoint("CENTER")
    x:SetScript("OnClick", function() f:Hide() end)
    copyBox = f
  end
  copyBox.value = text
  copyBox.title:SetText(title or "로그 주소")
  copyBox:ClearAllPoints()
  copyBox:SetPoint("CENTER", UI.frame, "CENTER", 0, 40)
  copyBox:Show()
  copyBox.eb:SetText(text or "")
  copyBox.eb:SetFocus()
  copyBox.eb:HighlightText()
end
UI.ShowCalendarCopy = ShowCopy

-- ── 캐릭 선택 팝업 ────────────────────────────────────
local function OpenCharMenu(p, anchor)
  if p.charMenu and p.charMenu:IsShown() then p.charMenu:Hide(); return end
  if not p.charMenu then
    local f = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel((UI.frame:GetFrameLevel() or 1) + 80)
    UI:Backdrop(f, C.panel2, C.border)
    f.rows = {}
    p.charMenu = f
  end
  local f = p.charMenu
  local items = { { key = nil, text = "전체 캐릭" } }
  for _, c in ipairs(M:Chars()) do
    items[#items + 1] = { key = c.key, text = classHex(c.class) .. tostring(c.name) .. "|r  " .. hex(C.muted) .. ago(c.synced) .. " · " .. c.count .. "개|r" }
  end
  for i, it in ipairs(items) do
    local b = f.rows[i]
    if not b then
      b = CreateFrame("Button", nil, f, "BackdropTemplate")
      b:SetHeight(24)
      UI:Backdrop(b, C.panel2, C.border)
      b:SetBackdropColor(0, 0, 0, 0); b:SetBackdropBorderColor(0, 0, 0, 0)
      b.label = F(b, 12, "", C.text); b.label:SetPoint("LEFT", 8, 0)
      b:SetScript("OnEnter", function(self) self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.12) end)
      b:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
      b:SetScript("OnClick", function(self)
        p.filter = self.key
        p.selected = nil
        f:Hide()
        p:Refresh()
      end)
      f.rows[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
    b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 26)
    b.key = it.key
    b.label:SetText(it.text)
    b:Show()
  end
  for i = #items + 1, #f.rows do f.rows[i]:Hide() end
  f:SetSize(250, #items * 26 + 8)
  f:ClearAllPoints()
  f:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
  f:Show()
end

-- ── 페이지 ────────────────────────────────────────────
function UI:BuildCalendar()
  if not M then return end
  local p = self:NewPage("CAL")
  p.contentHeight = 790
  local t = M:Today()
  p.viewY, p.viewM, p.selDay = t.year, t.month, t.day
  p.listOffset, p.partOffset = 0, 0

  -- 상단 줄
  local prev = smallButton(p, "‹", 30, function() p.viewY, p.viewM = M.AddMonths(p.viewY, p.viewM, -1); p.selDay = 1; p.selected = nil; p:Refresh() end)
  prev:SetPoint("TOPLEFT", GX, -10)
  local today = smallButton(p, "오늘", 54, function()
    local d = M:Today(); p.viewY, p.viewM, p.selDay = d.year, d.month, d.day; p.selected = nil; p:Refresh()
  end)
  today:SetPoint("LEFT", prev, "RIGHT", 4, 0)
  local nextB = smallButton(p, "›", 30, function() p.viewY, p.viewM = M.AddMonths(p.viewY, p.viewM, 1); p.selDay = 1; p.selected = nil; p:Refresh() end)
  nextB:SetPoint("LEFT", today, "RIGHT", 4, 0)
  p.monthTitle = F(p, 18, "", C.text)
  p.monthTitle:SetPoint("LEFT", nextB, "RIGHT", 14, 0)

  p.syncButton = smallButton(p, "지금 동기화", 96, function()
    local ok, why = M:Scan("manual")
    if not ok then
      NT:Print(why == "blizzard" and "와우 달력 창을 닫으면 바로 읽습니다." or (why == "combat" and "전투가 끝나면 읽습니다." or ("지금은 읽을 수 없습니다 (" .. tostring(why) .. ")")))
    end
    p:Refresh()
  end)
  p.syncButton:SetPoint("TOPLEFT", GX + 7 * (CW + GAP) - 96 - GAP, -10)
  p.charButton = smallButton(p, "전체 캐릭", 150, function(self) OpenCharMenu(p, self) end)
  p.charButton:SetPoint("RIGHT", p.syncButton, "LEFT", -6, 0)

  p.legend = F(p, 11, hex(GOLD) .. "■|r 받은 초대   " .. hex(TEAL) .. "■|r 내 메모   " .. hex(C.good) .. "수락|r · " .. hex(C.warn) .. "미정|r · " .. hex(GOLD) .. "응답 전|r · " .. hex(GROUP_COLOR.no) .. "거절|r   · 각 캐릭이 접속할 때 이번 달·다음 달 자동 동기화", C.muted)
  p.legend:SetPoint("TOPLEFT", GX, -42)

  -- 요일 머리
  for i = 1, 7 do
    local w = F(p, 12, WEEK[i], i == 1 and C.bad or (i == 7 and { .45, .68, 1 } or C.muted))
    w:SetPoint("TOPLEFT", GX + (i - 1) * (CW + GAP) + 6, GY - 3)
  end

  -- 칸 42개
  p.cells = {}
  for r = 0, 5 do
    for c = 0, 6 do
      local cell = CreateFrame("Button", nil, p, "BackdropTemplate")
      cell:SetSize(CW, CH)
      cell:SetPoint("TOPLEFT", GX + c * (CW + GAP), GY - HEAD_H - r * (CH + GAP))
      UI:Backdrop(cell, C.panel, C.border)
      cell.dayText = F(cell, 12, "", C.text); cell.dayText:SetPoint("TOPLEFT", 5, -4)
      cell.memo = cell:CreateTexture(nil, "ARTWORK")
      cell.memo:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 1)
      cell.memo:SetSize(7, 7); cell.memo:SetPoint("TOPRIGHT", -5, -6)
      cell.lines = {}
      for i = 1, 3 do
        local fs = F(cell, 10, "", C.text)
        fs:SetPoint("TOPLEFT", 4, -4 - i * 14)
        fs:SetWidth(CW - 8)
        UI:SingleLine(fs)
        cell.lines[i] = fs
      end
      cell:SetScript("OnClick", function(self)
        if not self.day then return end
        p.selDay = self.day; p.selected = nil; p.listOffset = 0
        p:Refresh()
      end)
      cell:SetScript("OnEnter", function(self)
        if not self.items or #self.items == 0 or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format("%d월 %d일", p.viewM, self.day), 1, 1, 1)
        for _, it in ipairs(self.items) do
          local label, grp = M:StatusInfo(it.e.status, it.e.ctype)
          local gc = GROUP_COLOR[grp] or C.text
          GameTooltip:AddDoubleLine(hhmm(it.e) .. "  " .. it.e.title .. "  " .. classHex(it.ch.class) .. tostring(it.ch.name) .. "|r", label, .9, .9, .9, gc[1], gc[2], gc[3])
        end
        local note = M:GetNote(M.DayKey(p.viewY, p.viewM, self.day))
        if note then GameTooltip:AddLine(" "); GameTooltip:AddLine(note, TEAL[1], TEAL[2], TEAL[3], true) end
        GameTooltip:Show()
      end)
      cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      p.cells[#p.cells + 1] = cell
    end
  end

  -- 날짜 메모 (달력 아래)
  local memoY = GY - HEAD_H - 6 * (CH + GAP) - 10
  local memo = panel(p, GX, memoY, 7 * (CW + GAP) - GAP, 104)
  p.memoTitle = F(memo, 12, "", TEAL); p.memoTitle:SetPoint("TOPLEFT", 12, -10)
  local eb = CreateFrame("EditBox", nil, memo, "BackdropTemplate")
  eb:SetPoint("TOPLEFT", 12, -32); eb:SetPoint("BOTTOMRIGHT", -150, 12)
  UI:Backdrop(eb, C.panel2, C.border)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(300)
  eb:SetTextInsets(8, 8, 6, 6)
  pcall(eb.SetFont, eb, (NT.BodyFont and NT:BodyFont()) or STANDARD_TEXT_FONT, 12, "")
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  p.memoBox = eb
  local save = smallButton(memo, "메모 저장", 120, function()
    M:SetNote(M.DayKey(p.viewY, p.viewM, p.selDay), eb:GetText()); eb:ClearFocus(); p:Refresh()
  end)
  save:SetPoint("TOPRIGHT", -12, -32)
  local del = smallButton(memo, "삭제", 120, function()
    M:SetNote(M.DayKey(p.viewY, p.viewM, p.selDay), ""); eb:SetText(""); eb:ClearFocus(); p:Refresh()
  end)
  del:SetPoint("TOPRIGHT", save, "BOTTOMRIGHT", 0, -6)

  -- 동기화 상태 · 설정 (메모 아래)
  local infoY = memoY - 104 - 10
  local info = panel(p, GX, infoY, 7 * (CW + GAP) - GAP, 112)
  p.syncText = F(info, 12, "", C.text)
  p.syncText:SetPoint("TOPLEFT", 12, -10); p.syncText:SetPoint("RIGHT", -12, 0)
  p.syncText:SetWordWrap(true)
  local function getS() return M:DB().settings end
  local function check(label, key, x, y, tip)
    local b = CreateFrame("Button", nil, info)
    b:SetSize(180, 22)
    b:SetPoint("TOPLEFT", x, y)
    b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(14, 14); b.box:SetPoint("LEFT", 0, 0)
    b.text = F(b, 12, label, C.text); b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.Refresh = function(self)
      local on = getS()[key] and true or false
      if on then self.box:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
      else self.box:SetColorTexture(C.muted[1] * .5, C.muted[2] * .5, C.muted[3] * .5, 0.95) end
    end
    b:SetScript("OnClick", function(self)
      local s = getS(); s[key] = not s[key]; self:Refresh()
      if key == "showAnnouncements" then M:Scan("setting") end
      p:Refresh()
    end)
    b:SetScript("OnEnter", function(self) if tip and GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
  end
  p.checks = {
    check("계정 달력 켜기", "enabled", 12, -74, "끄면 접속할 때 달력을 읽지 않습니다 (모아 둔 내용은 남음)"),
    check("참가자 자동 읽기", "autoDetails", 200, -74, "접속한 캐릭의 2주 안 일정 몇 개의 참가자 목록을 미리 읽습니다"),
    check("길드 공지도 표시", "showAnnouncements", 388, -74, "초대가 아닌 길드 공지도 달력에 표시합니다"),
  }

  -- 오른쪽: 그날 초대 목록
  local dayP = panel(p, RX, -10, RW, 40 + 28 + 8)
  p.dayPanel = dayP
  p.dayTitle = F(dayP, 14, "", C.text); p.dayTitle:SetPoint("TOPLEFT", 12, -10)
  p.dayCount = F(dayP, 11, "", C.muted); p.dayCount:SetPoint("TOPRIGHT", -12, -12)
  p.dayRows = {}
  for i = 1, DAY_ROWS do
    local b = CreateFrame("Button", nil, dayP, "BackdropTemplate")
    b:SetHeight(26)
    b:SetPoint("TOPLEFT", 8, -36 - (i - 1) * 28)
    b:SetPoint("TOPRIGHT", -8, -36 - (i - 1) * 28)
    UI:Backdrop(b, C.panel2, C.border)
    b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetWidth(3); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT")
    b.text = F(b, 12, "", C.text); b.text:SetPoint("LEFT", 10, 0); b.text:SetPoint("RIGHT", -60, 0); UI:SingleLine(b.text)
    b.state = F(b, 11, "", C.muted); b.state:SetPoint("RIGHT", -8, 0); b.state:SetJustifyH("RIGHT")
    b:SetScript("OnClick", function(self)
      if not self.item then return end
      p.selected = { char = self.item.char, key = M.DetailKey(self.item.e) }
      p.partOffset = 0
      p:Refresh()
      -- 접속한 캐릭 일정이면 참가자를 바로 읽어 온다
      if self.item.char == M:CurrentCharKey() then
        local det = M:Detail(self.item.e)
        if not det or ((time and time() or 0) - (det.updated or 0)) > 120 then M:Open(self.item.char, self.item.e, nil, true) end
      end
    end)
    p.dayRows[i] = b
  end
  -- 2.5.9: 참가자 목록 휠. 오른쪽 위 목록에서 굴려도 (초대가 4개를 넘지 않으면) 참가자 목록이 움직인다.
  local function scrollParts(delta)
    p.partOffset = math.max(0, math.min((p.partCount or 0) - PART_ROWS, (p.partOffset or 0) - delta * 3))
    p:Refresh()
  end
  dayP:EnableMouseWheel(true)
  dayP:SetScript("OnMouseWheel", function(_, delta)
    if (p.dayItemsCount or 0) > DAY_ROWS then
      p.listOffset = math.max(0, math.min((p.dayItemsCount or 0) - DAY_ROWS, (p.listOffset or 0) - delta))
      p:Refresh()
    else
      scrollParts(delta)
    end
  end)

  -- 오른쪽: 선택한 초대 상세
  local det = panel(p, RX, -10, RW, 600)
  det:ClearAllPoints()
  det:SetPoint("TOPLEFT", dayP, "BOTTOMLEFT", 0, -8)   -- 2.5.9: 위 목록 높이에 붙어 따라 올라감
  p.detPanel = det
  p.detTitle = F(det, 15, "", C.text); p.detTitle:SetPoint("TOPLEFT", 12, -10); p.detTitle:SetPoint("RIGHT", -12, 0); UI:SingleLine(p.detTitle)
  p.detLines = F(det, 12, "", C.text); p.detLines:SetPoint("TOPLEFT", 12, -34); p.detLines:SetPoint("RIGHT", -12, 0)
  p.detLines:SetSpacing(3)
  p.btnYes = smallButton(det, "수락", 70, function() if p.cur then M:Respond(p.cur.char, p.cur.e, "yes") end end)
  p.btnMaybe = smallButton(det, "미정", 70, function() if p.cur then M:Respond(p.cur.char, p.cur.e, "maybe") end end)
  p.btnNo = smallButton(det, "거절", 70, function() if p.cur then M:Respond(p.cur.char, p.cur.e, "no") end end)
  p.btnLog = smallButton(det, "로그 주소", 90, function()
    if not p.cur then return end
    local url, label = M:EventURL(p.cur.char, p.cur.e)
    if url then ShowCopy(label, url) else NT:Print("로그 주소를 만들 정보가 없습니다.") end
  end)
  p.btnYes:SetPoint("TOPLEFT", 12, -104)
  p.btnMaybe:SetPoint("LEFT", p.btnYes, "RIGHT", 6, 0)
  p.btnNo:SetPoint("LEFT", p.btnMaybe, "RIGHT", 6, 0)
  p.btnLog:SetPoint("TOPRIGHT", -12, -104)
  for _, b in ipairs({ p.btnYes, p.btnMaybe, p.btnNo }) do
    b:HookScript("OnEnter", function(self)
      if self.disabledWhy and GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.disabledWhy, 1, .8, .4, true); GameTooltip:Show() end
    end)
    b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  p.respondNote = F(det, 11, "", C.muted); p.respondNote:SetPoint("TOPLEFT", 12, -132); p.respondNote:SetPoint("RIGHT", -12, 0)

  p.partHead = F(det, 12, "", C.accent); p.partHead:SetPoint("TOPLEFT", 12, -156); p.partHead:SetPoint("RIGHT", -12, 0)
  p.partComp = F(det, 11, "", C.text); p.partComp:SetPoint("TOPLEFT", 12, -176); p.partComp:SetPoint("RIGHT", -12, 0)
  p.partComp:SetWordWrap(true)
  p.partRows = {}
  for i = 1, PART_ROWS do
    local b = CreateFrame("Button", nil, det)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", 12, -214 - (i - 1) * 22)
    b:SetPoint("TOPRIGHT", -12, -214 - (i - 1) * 22)
    b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08); b.hl:Hide()
    b.name = F(b, 12, "", C.text); b.name:SetPoint("LEFT", 4, 0); b.name:SetPoint("RIGHT", -150, 0); UI:SingleLine(b.name)
    b.cls = F(b, 11, "", C.muted); b.cls:SetPoint("RIGHT", -70, 0)
    b.state = F(b, 11, "", C.muted); b.state:SetPoint("RIGHT", -4, 0)
    b:SetScript("OnEnter", function(self) self.hl:Show(); if GameTooltip and self.inv then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("클릭: 이 캐릭 로그 주소", 1, 1, 1); GameTooltip:Show() end end)
    b:SetScript("OnLeave", function(self) self.hl:Hide(); if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", function(self)
      if not self.inv or not p.cur then return end
      ShowCopy(self.inv.name .. " 로그", M:CharacterURL(self.inv.name, p.cur.ch.realm))
    end)
    p.partRows[i] = b
  end
  det:EnableMouseWheel(true)
  det:SetScript("OnMouseWheel", function(_, delta) scrollParts(delta) end)
  p.partFoot = F(det, 11, "", C.muted); p.partFoot:SetPoint("BOTTOMLEFT", 12, 10); p.partFoot:SetPoint("RIGHT", -12, 0)

  -- ── 다시 그리기 ─────────────────────────────────────
  p.Refresh = function(self)
    local db = M:DB()
    local y, m = self.viewY, self.viewM
    local nd = M.DaysIn(y, m)
    if not self.selDay or self.selDay > nd then self.selDay = 1 end
    self.monthTitle:SetText(string.format("%d년 %d월", y, m))
    local filterName
    if self.filter and db.chars[self.filter] then
      local ch = db.chars[self.filter]
      filterName = classHex(ch.class) .. tostring(ch.name) .. "|r"
    else
      self.filter = nil
    end
    self.charButton.label:SetText(filterName or "전체 캐릭")

    local idx = M:MonthIndex(y, m, self.filter)
    local td = M:Today()
    local first = M.Weekday(y, m, 1)
    for i, cell in ipairs(self.cells) do
      local d = i - first + 1
      if d >= 1 and d <= nd then
        cell.day = d
        cell:Show()
        cell:EnableMouse(true)
        local items = idx[d] or {}
        cell.items = items
        local isToday = (y == td.year and m == td.month and d == td.day)
        local wd = M.Weekday(y, m, d)
        local dc = isToday and C.accent or (wd == 1 and C.bad or (wd == 7 and { .45, .68, 1 } or C.text))
        cell.dayText:SetText(tostring(d) .. (isToday and "  오늘" or ""))
        cell.dayText:SetTextColor(dc[1], dc[2], dc[3], 1)
        for li = 1, 3 do
          local fs = cell.lines[li]
          local it = items[li]
          if li == 3 and #items > 3 then
            fs:SetText(hex(C.muted) .. "+" .. (#items - 2) .. "개 더|r")
          elseif it then
            local _, grp = M:StatusInfo(it.e.status, it.e.ctype)
            local gc = GROUP_COLOR[grp] or C.text
            fs:SetText(hex(gc) .. hhmm(it.e) .. "|r " .. classHex(it.ch.class) .. tostring(it.ch.name) .. "|r")
          else
            fs:SetText("")
          end
        end
        cell.memo:SetShown(M:GetNote(M.DayKey(y, m, d)) ~= nil)
        local sel = (d == self.selDay)
        if sel then
          cell:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.10)
          cell:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.95)
        elseif #items > 0 then
          cell:SetBackdropColor(GOLD[1] * .25, GOLD[2] * .25, GOLD[3] * .25, 0.55)
          cell:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.75)
        else
          cell:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.68)
          cell:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.54)
        end
      else
        cell.day = nil
        cell.items = nil
        cell:EnableMouse(false)
        cell.dayText:SetText("")
        for li = 1, 3 do cell.lines[li]:SetText("") end
        cell.memo:Hide()
        cell:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.22)
        cell:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.20)
      end
    end

    -- 그날 목록
    local items = idx[self.selDay] or {}
    self.dayItemsCount = #items
    self.listOffset = math.max(0, math.min(math.max(0, #items - DAY_ROWS), self.listOffset or 0))
    local visRows = math.max(1, math.min(DAY_ROWS, #items))
    self.dayPanel:SetHeight(40 + visRows * 28 + 8)
    self.dayTitle:SetText(string.format("%d월 %d일 (%s)", m, self.selDay, WEEK[M.Weekday(y, m, self.selDay)]))
    self.dayCount:SetText(#items > 0 and ("받은 초대 " .. #items .. "개" .. (#items > DAY_ROWS and " · 휠로 더 보기" or "")) or "")
    local selectedItem
    for i, row in ipairs(self.dayRows) do
      local it = (i <= visRows) and items[i + self.listOffset] or nil
      row.item = it
      if it then
        local label, grp = M:StatusInfo(it.e.status, it.e.ctype)
        local gc = GROUP_COLOR[grp] or C.text
        local diff = it.e.diff and (" · " .. it.e.diff) or ""
        row.text:SetText(hhmm(it.e) .. "  " .. it.e.title .. hex(C.muted) .. diff .. "|r  " .. classHex(it.ch.class) .. tostring(it.ch.name) .. "|r")
        row.state:SetText(label); row.state:SetTextColor(gc[1], gc[2], gc[3], 1)
        row.bar:SetColorTexture(gc[1], gc[2], gc[3], 1)
        local isSel = self.selected and self.selected.char == it.char and self.selected.key == M.DetailKey(it.e)
        row:SetBackdropBorderColor(isSel and C.accent[1] or C.border[1], isSel and C.accent[2] or C.border[2], isSel and C.accent[3] or C.border[3], isSel and 0.95 or 0.5)
        row:Show()
      else
        row:Hide()
      end
    end
    if self.selected then
      for _, it in ipairs(items) do
        if it.char == self.selected.char and M.DetailKey(it.e) == self.selected.key then selectedItem = it end
      end
    end
    if not selectedItem and items[1] then
      selectedItem = items[1]
      self.selected = { char = selectedItem.char, key = M.DetailKey(selectedItem.e) }
    end
    self.cur = selectedItem

    -- 메모
    local dk = M.DayKey(y, m, self.selDay)
    self.memoTitle:SetText(string.format("%d월 %d일 메모 (계정 공용)", m, self.selDay))
    if not self.memoBox:HasFocus() or self.memoDay ~= dk then
      self.memoBox:SetText(M:GetNote(dk) or "")
      self.memoDay = dk
    end

    -- 상세
    local cur = self.cur
    local respondable = false
    if not cur then
      self.detTitle:SetText(hex(C.muted) .. "이 날은 받은 초대가 없습니다|r")
      self.detLines:SetText("")
      self.respondNote:SetText("")
      self.partHead:SetText(""); self.partComp:SetText(""); self.partFoot:SetText("")
      for _, r in ipairs(self.partRows) do r:Hide() end
      for _, b in ipairs({ self.btnYes, self.btnMaybe, self.btnNo, self.btnLog }) do b:Hide() end
    else
      local e, ch = cur.e, cur.ch
      for _, b in ipairs({ self.btnYes, self.btnMaybe, self.btnNo, self.btnLog }) do b:Show() end
      local label, grp = M:StatusInfo(e.status, e.ctype)
      local gc = GROUP_COLOR[grp] or C.text
      local detail = M:Detail(e)
      self.detTitle:SetText(e.title)
      local typeName = ({ PLAYER = "개인 초대", GUILD_EVENT = "길드 일정", COMMUNITY_EVENT = "커뮤니티 일정", GUILD_ANNOUNCEMENT = "길드 공지" })[e.ctype] or e.ctype
      local lines = {
        string.format("%04d-%02d-%02d %s · %s%s", e.y, e.m, e.d, hhmm(e), typeName, e.diff and (" · " .. e.diff) or ""),
        "받은 캐릭 " .. classHex(ch.class) .. tostring(ch.name) .. "|r  ·  초대한 사람 " .. tostring((detail and detail.creator) or e.by or "?"),
        "상태 " .. hex(gc) .. label .. "|r" .. (M:IsSignup(e) and hex(C.muted) .. "  (신청형 일정)|r" or "") .. (e.locked and hex(C.bad) .. "  잠김|r" or ""),
      }
      self.detLines:SetText(table.concat(lines, "\n"))
      local ok, why = M:CanRespond(cur.char, e)
      respondable = ok
      setEnabled(self.btnYes, ok, why); setEnabled(self.btnMaybe, ok, why); setEnabled(self.btnNo, ok and not M:IsSignup(e), why or "신청형 일정은 신청 · 미정만 할 수 있습니다")
      self.btnYes.label:SetText(M:IsSignup(e) and "신청" or "수락")
      self.respondNote:SetText(ok and "" or (hex(C.muted) .. tostring(why) .. "|r"))
      setEnabled(self.btnLog, M:EventURL(cur.char, e) ~= nil, "로그 주소를 만들 정보가 없습니다")

      local invs = detail and detail.invites
      if invs and #invs > 0 then
        local cnt = { yes = 0, maybe = 0, wait = 0, no = 0 }
        local cls = {}
        local sorted = {}
        for _, inv in ipairs(invs) do
          local _, g = M:StatusInfo(inv.status)
          cnt[g] = (cnt[g] or 0) + 1
          if g == "yes" or g == "maybe" then cls[inv.class or "?"] = (cls[inv.class or "?"] or 0) + 1 end
          sorted[#sorted + 1] = inv
        end
        local order = { yes = 1, maybe = 2, wait = 3, no = 4 }
        table.sort(sorted, function(a, b)
          local _, ga = M:StatusInfo(a.status); local _, gb = M:StatusInfo(b.status)
          if order[ga] ~= order[gb] then return (order[ga] or 9) < (order[gb] or 9) end
          if (a.class or "") ~= (b.class or "") then return (a.class or "") < (b.class or "") end
          return a.name < b.name
        end)
        self.partHead:SetText(string.format("참가자 %d명  ·  %s수락 %d|r · %s미정 %d|r · %s응답 전 %d|r · %s거절 %d|r",
          #invs, hex(C.good), cnt.yes, hex(C.warn), cnt.maybe, hex(GOLD), cnt.wait, hex(GROUP_COLOR.no), cnt.no))
        local comp = {}
        local names = {}
        for k in pairs(cls) do names[#names + 1] = k end
        table.sort(names, function(a, b) return cls[a] > cls[b] or (cls[a] == cls[b] and a < b) end)
        for _, k in ipairs(names) do comp[#comp + 1] = classHex(k) .. className(k) .. " " .. cls[k] .. "|r" end
        self.partComp:SetText(#comp > 0 and ("수락·미정 직업 " .. table.concat(comp, "  ")) or "")
        self.partCount = #sorted
        self.partOffset = math.max(0, math.min(math.max(0, #sorted - PART_ROWS), self.partOffset or 0))
        for i, r in ipairs(self.partRows) do
          local inv = sorted[i + self.partOffset]
          r.inv = inv
          if inv then
            local l, g = M:StatusInfo(inv.status)
            local c = GROUP_COLOR[g] or C.text
            r.name:SetText(classHex(inv.class) .. inv.name .. "|r" .. ((inv.mod == "CREATOR" and hex(GOLD) .. "  ★|r") or (inv.mod == "MODERATOR" and hex(C.muted) .. "  관리|r") or ""))
            r.cls:SetText(className(inv.class))
            r.state:SetText(l); r.state:SetTextColor(c[1], c[2], c[3], 1)
            r:Show()
          else
            r:Hide()
          end
        end
        local who = detail.by and db.chars[detail.by] and db.chars[detail.by].name or "?"
        self.partFoot:SetText(string.format("%s 기준 (%s 접속 때 읽음)%s", ago(detail.updated), who, #sorted > PART_ROWS and " · 오른쪽 아무 곳에서나 마우스 휠로 더 보기" or ""))
      else
        self.partCount = 0
        for _, r in ipairs(self.partRows) do r:Hide() end
        self.partHead:SetText("참가자")
        self.partComp:SetText("")
        if e.ctype == "GUILD_ANNOUNCEMENT" then
          self.partFoot:SetText("길드 공지는 참가자 목록이 없습니다")
        elseif cur.char == M:CurrentCharKey() then
          self.partFoot:SetText(M.pending and "참가자 목록을 읽는 중…" or "이 초대를 누르면 참가자 목록을 읽습니다")
        else
          self.partFoot:SetText(tostring(ch.name) .. " 캐릭으로 접속하면 참가자 목록을 읽어 옵니다")
        end
      end
    end

    -- 동기화 상태
    local chars = M:Chars()
    local parts = {}
    local curKey = M:CurrentCharKey()
    for _, c in ipairs(chars) do
      parts[#parts + 1] = classHex(c.class) .. tostring(c.name) .. "|r " .. hex(C.muted) .. ago(c.synced) .. "|r" .. (c.key == curKey and hex(C.accent) .. "(접속 중)|r" or "")
    end
    local head = "동기화한 캐릭 " .. #chars .. "  ·  "
    if #chars == 0 then head = "아직 읽은 캐릭이 없습니다. 접속하면 자동으로 읽고, 「지금 동기화」로 바로 읽을 수 있습니다." end
    local block = ""
    if M.lastBlock and M.pendingScan then
      block = "\n" .. hex(C.warn) .. (({ blizzard = "와우 달력 창이 열려 있어 닫힌 뒤 읽습니다", combat = "전투 중이라 전투 뒤 읽습니다", pending = "달력 응답 처리 중이라 잠시 뒤 읽습니다" })[M.lastBlock] or "") .. "|r"
    end
    self.syncText:SetText(head .. table.concat(parts, "   ") .. block)
    for _, c in ipairs(self.checks) do c:Refresh() end
  end
end
