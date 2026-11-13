-- NiniTools 2.8.5: 새 소식 카드.
-- 업데이트한 뒤 처음 접속하면 바뀐 내용을 카드로 한 번 보여 준다. 제목줄의 버전 글자를 누르면 다시 볼 수 있다.
-- 처음 설치한 사람에게는 띄우지 않는다 (저장된 설정이 하나도 없으면 첫 설치로 본다).
-- 내용은 CHANGELOG_x.txt 를 줄인 것. flavor: "forever" 는 포에버에서만, "retail" 은 본섭에서만 보인다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local NEWS = {
  { version = "2.8.8", flavor = "retail", cards = {
    { title = "보스 풀마다 애드온 부하 기록", lines = {
      "보스 전투가 끝나면 어떤 애드온이 얼마나 무거웠는지(보스 전투 평균 · 한 프레임 50ms 넘은 횟수)를 저장합니다. 화면이 끊긴 판의 원인 애드온을 찾는 데 씁니다.",
      "한 애드온이 한 풀에 50ms 넘은 프레임이 5번 이상이면 채팅에 한 줄 알려 줍니다.",
    } },
    { title = "명령어 대신 스위치", lines = {
      "NiniTools 창 오른쪽 위 톱니(설정 & 진단) → 「기록 (분석기용)」에서 애드온 부하 기록 · 부하 알림 · 공대 메모 캡처를 스위치로 켜고 끕니다. 기록 지우기 버튼 · 최근 기록도 여기서 봅니다.",
      "같은 화면에 글꼴(본문 · 숫자) 고르기와 자가진단 버튼도 있습니다. 명령어는 몰라도 됩니다.",
    } },
  } },
  { version = "2.8.7", flavor = "retail", cards = {
    { title = "NSRT 메모 · 글자 메모를 넣어도 쿨기 유지", lines = {
      "같은 전문화 메모를 다시 넣을 때, 넣는 메모에 있는 줄 종류만 바꿉니다. 스킬 줄(Lorrgs 쿨기)은 스킬 줄끼리, 글자 줄(직접 쓴 안내)은 글자 줄끼리.",
      "예전에는 울라텍 큰 알 같은 글자 메모를 넣으면 그 전문화 쿨기 줄이 모두 지워졌습니다. 지워진 메모는 다시 넣어 주세요.",
    } },
  } },
  { version = "2.8.6", flavor = "retail", cards = {
    { title = "NSRT 메모 · 보스 정보 없는 메모", lines = {
      "Lorrgs 메모가 「Name:Unknown;」으로 시작해 보스 정보가 없으면, 판별 결과 칸의 「보스 고르기」와 난이도 단추로 정해서 넣을 수 있습니다.",
      "고르지 않으면 이번 접속에서 마지막으로 풀한 레이드 보스가 기본으로 채워집니다. 적용 전에 판별 결과를 확인하세요.",
    } },
  } },
  { version = "2.8.5", cards = {
    { title = "설정 검색", lines = {
      "창 위 메뉴 줄 오른쪽 「설정 검색」 칸에 이름이나 설명을 쓰면 맞는 설정이 바로 아래에 뜹니다.",
      "누르면 그 페이지로 가서 항목을 펼치고 그 위치로 스크롤합니다. Enter 는 첫 번째 결과로 이동.",
    } },
    { title = "새 소식", lines = {
      "업데이트한 뒤 처음 접속하면 이 카드가 한 번 뜹니다.",
      "제목줄의 버전 글자(v" .. tostring(NT.VERSION or "") .. ")를 누르면 언제든 다시 볼 수 있습니다.",
    } },
    { title = "위치 편집", lines = {
      "제목줄 「위치 편집」 또는 /nt 편집 — 움직일 수 있는 니니툴 표시를 한꺼번에 잠금 해제하고 화면에 격자를 띄웁니다.",
      "드래그해서 옮긴 뒤 「완료」. 전투가 시작되면 자동으로 끝나고 잠깁니다.",
    } },
  } },
  { version = "2.8.4", flavor = "forever", cards = {
    { title = "주시 · 차단 매크로 자동 생성", lines = {
      "NiniKickFocus(주시 + 담당 징표)와 NiniKickAuto(주시 차단 → 없으면 가까운 적)를 캐릭터 전용 매크로로 만들어 둡니다.",
      "/m → 캐릭터 전용 탭에서 단축바로 끌어 놓으세요. 화면 & 편의 → 주시 · 차단 매크로에서 징표를 고를 수 있습니다.",
    } },
    { title = "파티 입장 인사", lines = {
      "남의 파티에 들어갈 때만 「안녕하세요.」를 보냅니다. 내가 만든 파티에서는 인사하지 않습니다.",
    } },
  } },
  { version = "2.8.2", flavor = "forever", cards = {
    { title = "전투 시간", lines = {
      "전투를 시작하면 화면에 경과 시간이 뜨고, 끝나면 걸린 시간을 2.5초 보여 줍니다. 화면 & 편의 → 전투 시간.",
    } },
  } },
  { version = "2.7.2", flavor = "retail", cards = {
    { title = "NSRT 메모 보관함", lines = {
      "나오 프로필을 새로 받아 NSRT 메모가 사라지면 「NSRT 메모 넣기」 창에서 골라 다시 넣을 수 있습니다.",
    } },
  } },
}

local News = { list = NEWS }
NT.News = News

local function forThisClient(entry)
  if entry.flavor == "forever" then return NT.FOREVER and true or false end
  if entry.flavor == "retail" then return not NT.FOREVER end
  return true
end

local function versionKey(v)
  local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)")
  return (tonumber(a) or 0) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
end

function News:GetDB()
  local main = NT:GetDB()
  main.modules = type(main.modules) == "table" and main.modules or {}
  local db = main.modules.news
  if type(db) ~= "table" then db = {}; main.modules.news = db end
  return db
end

-- 보여 줄 버전 목록. sinceVersion 이 있으면 그보다 새 것만, 없으면 최근 3개.
function News:Entries(sinceVersion)
  local out = {}
  local since = sinceVersion and versionKey(sinceVersion) or nil
  for _, entry in ipairs(NEWS) do
    if forThisClient(entry) and versionKey(entry.version) <= versionKey(NT.VERSION) then
      if since then
        if versionKey(entry.version) > since then out[#out + 1] = entry end
      elseif #out < 3 then
        out[#out + 1] = entry
      end
    end
  end
  return out
end

local frame

local function build()
  if frame then return frame end
  local UI = NT.UI
  local C = UI.C
  frame = CreateFrame("Frame", "NiniToolsNewsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(520, 300)
  frame:SetPoint("CENTER", 0, 60)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  UI:Backdrop(frame, C.bg, C.border)
  frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], .985)
  tinsert(UISpecialFrames, "NiniToolsNewsFrame")   -- ESC 로 닫기

  local top = frame:CreateTexture(nil, "ARTWORK")
  top:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], .9)
  top:SetPoint("TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", 0, 0); top:SetHeight(2)

  frame.title = UI:Font(frame, 13, "NiniTools 새 소식", C.text)
  frame.title:SetPoint("TOPLEFT", 18, -14)
  frame.sub = UI:Font(frame, 8, "", C.muted)
  frame.sub:SetPoint("TOPLEFT", 18, -36)

  local close = CreateFrame("Button", nil, frame)
  close:SetSize(28, 28); close:SetPoint("TOPRIGHT", -6, -6)
  close.label = UI:Font(close, 16, "×", C.muted); close.label:SetPoint("CENTER", 0, 1)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame.ok = UI:Button(frame, "확인", 96, 26, function() frame:Hide() end)
  frame.ok:SetPoint("BOTTOMRIGHT", -16, 14)
  frame.open = UI:Button(frame, "NiniTools 열기", 130, 26, function() frame:Hide(); NT:ToggleUI() end)
  frame.open:SetPoint("RIGHT", frame.ok, "LEFT", -8, 0)

  frame.body = CreateFrame("Frame", nil, frame)
  frame.body:SetPoint("TOPLEFT", 16, -58)
  frame.body:SetPoint("TOPRIGHT", -16, -58)
  frame.pool = {}
  return frame
end

local function card(i)
  local UI, C = NT.UI, NT.UI.C
  local c = frame.pool[i]
  if not c then
    c = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    UI:Backdrop(c, C.panel, C.border)
    c:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], .74)
    c:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], .68)
    c.badge = UI:Font(c, 8, "", C.accent)
    c.badge:SetPoint("TOPRIGHT", -12, -10)
    c.title = UI:Font(c, 10, "", C.text)
    c.title:SetPoint("TOPLEFT", 12, -9)
    c.text = UI:Font(c, 9, "", C.muted)
    c.text:SetPoint("TOPLEFT", 12, -30)
    c.text:SetPoint("RIGHT", -12, 0)
    c.text:SetJustifyH("LEFT")
    c.text:SetSpacing(3)
    frame.pool[i] = c
  end
  return c
end

-- entries: News:Entries(...) 결과
function News:ShowEntries(entries, subtitle)
  if not (NT.UI and NT.UI.C) or #entries == 0 then return false end
  build()
  frame:Show()   -- 보이는 상태에서 글자 폭 · 높이를 재야 카드 높이가 맞는다
  for _, c in ipairs(frame.pool) do c:Hide() end
  local y, i = 0, 0
  for _, entry in ipairs(entries) do
    for _, item in ipairs(entry.cards) do
      i = i + 1
      local c = card(i)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 0, -y); c:SetPoint("TOPRIGHT", 0, -y)
      c.badge:SetText("v" .. entry.version)
      c.title:SetText(item.title)
      c.text:SetWidth(frame.body:GetWidth() > 0 and frame.body:GetWidth() - 24 or 464)
      c.text:SetText("· " .. table.concat(item.lines, "\n· "))
      local h = 40 + math.ceil(tonumber(c.text:GetStringHeight()) or 14)
      c:SetHeight(h)
      c:Show()
      y = y + h + 8
    end
  end
  frame.sub:SetText(subtitle or ("v" .. tostring(NT.VERSION)))
  frame:SetHeight(math.min(640, 58 + y + 50))
  return true
end

-- manual: 제목줄 버전 글자를 눌렀을 때 (최근 3개 버전)
function News:Show(manual)
  if manual then
    return self:ShowEntries(self:Entries(nil), "최근 바뀐 내용 · 현재 v" .. tostring(NT.VERSION))
  end
  local db = self:GetDB()
  local seen = db.seen
  db.seen = tostring(NT.VERSION)
  if seen == tostring(NT.VERSION) then return false end
  if not seen then
    -- 2.8.5 처음 깐 기존 사용자 vs 새로 설치한 사람: 다른 저장된 설정이 있으면 업데이트로 본다
    local main = NT:GetDB()
    local hasOther = false
    for k in pairs(main.modules or {}) do if k ~= "news" then hasOther = true; break end end
    if not hasOther and main.lastPage == nil then return false end
    seen = "2.8.4"
  end
  local entries = self:Entries(seen)
  return self:ShowEntries(entries, "v" .. tostring(seen) .. " → v" .. tostring(NT.VERSION) .. " 에서 바뀐 내용")
end

local proxy = NT.EventDispatcher and NT.EventDispatcher.CreateProxy and NT.EventDispatcher:CreateProxy("News")
  or CreateFrame("Frame")
proxy:RegisterEvent("PLAYER_LOGIN")
proxy:SetScript("OnEvent", function()
  -- 접속 직후 다른 창 · 채팅이 정리될 시간을 두고, 전투 중이면 전투 뒤로 미룬다
  local function try()
    if InCombatLockdown and InCombatLockdown() then C_Timer.After(5, try); return end
    pcall(News.Show, News, false)
  end
  C_Timer.After(6, try)
end)
