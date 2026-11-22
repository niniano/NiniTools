-- NiniTools 2.8.5: 새 소식 카드.
-- 업데이트한 뒤 처음 접속하면 바뀐 내용을 카드로 한 번 보여 준다. 제목줄의 버전 글자를 누르면 다시 볼 수 있다.
-- 처음 설치한 사람에게는 띄우지 않는다 (저장된 설정이 하나도 없으면 첫 설치로 본다).
-- 내용은 CHANGELOG_x.txt 를 줄인 것. flavor: "forever" 는 포에버에서만, "retail" 은 본섭에서만 보인다.
local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools

local NEWS = {
  { version = "2.8.20", flavor = "forever", cards = {
    { title = "보호된 함수 오류", lines = {
      "포에버에서 「보호된 함수 UNKNOWN() 호출」 오류가 계속 뜨던 것을 고쳤습니다.",
      "포에버가 전투 정보를 막아서 근접 자동공격 링은 뺐습니다. 원거리 자동 사격 링은 그대로입니다.",
    } },
  } },
  { version = "2.8.19", cards = {
    { title = "죽었을 때 Navi", lines = {
      "죽었을 때 가운데가 하얗게 번져 요정이 안 보이던 것을 고쳤습니다. 분홍 원이 가운데를 덮고, 링과 요정이 보입니다.",
      "죽으면 요정이 커서 둘레를 8자로 날아다닙니다.",
    } },
  } },
  { version = "2.8.18", flavor = "forever", cards = {
    { title = "/rl · /기 로 리로드", lines = {
      "포에버에서도 /rl 이나 /기(한글 자판으로 /rl)로 UI를 다시 불러옵니다.",
    } },
  } },
  { version = "2.8.18", flavor = "retail", cards = {
    { title = "Navi 반짝임 자리", lines = {
      "본섭에서 가운데 반짝임 효과가 요정보다 아래로 내려가 보이던 것을 원래 자리로 돌렸습니다.",
    } },
  } },
  { version = "2.8.17", flavor = "forever", cards = {
    { title = "골드 내역: 같은 캐릭터가 두 줄로 나오던 것", lines = {
      "포에버가 접속할 때 서버 이름을 비워 보내서 같은 캐릭터가 따로 쌓였습니다. 한 줄로 합쳤고 거래 내역도 그대로 옮겼습니다.",
    } },
  } },
  { version = "2.8.16", cards = {
    { title = "Navi 가운데 반짝임 효과 고르기", lines = {
      "요정 가운데를 파랗게 덮던 빛을 요정 뒤로 옮기고 약하게 해서 요정 모양이 또렷합니다.",
      "사운드 & Navi → Navi · 마우스 커서 → 「가운데 반짝임 효과」에서 끄기 · 반짝반짝 · 비전 양손 모으기 · 비전 반짝이(본섭만) 중에 고릅니다 (고르면 바로 바뀜).",
    } },
  } },
  { version = "2.8.16", flavor = "forever", cards = {
    { title = "포에버도 반짝임 고르기", lines = {
      "포에버 기본은 지금까지의 빛줄기(물건 창조) 그대로이고, 같은 칸에서 다른 반짝임이나 끄기를 고를 수 있습니다.",
    } },
  } },
  { version = "2.8.16", flavor = "retail", cards = {
    { title = "본섭 기본은 반짝임 없음", lines = {
      "본섭은 기본으로 가운데 반짝임이 없습니다 (2.8.12 모습). 원하면 위 칸에서 골라 켭니다.",
    } },
  } },
  { version = "2.8.16", cards = {
    { title = "홈 부하 카드", lines = {
      "「애드온 부하」 카드가 숫자를 먼저 보여 줍니다 (이름이 길어도 ms 가 잘리지 않음).",
    } },
  } },
  { version = "2.8.15", flavor = "retail", cards = {
    { title = "Navi 반짝임 조금 크게", lines = {
      "요정 바깥 원 안으로 빛줄기가 모여 뱅그르 터지는 효과를 조금 키웠습니다. 2.8.14 의 「가운데 빛」 슬라이더는 뺐습니다.",
    } },
  } },
  { version = "2.8.13", cards = {
    { title = "Navi 가운데 반짝임 · 굵은 꼬리", lines = {
      "Navi 가운데로 빛 알갱이가 빨려 들며 반짝입니다 (포에버 Navi 위크오라와 같은 게임 주문 효과).",
      "꼬리가 굵고 길어졌습니다 (빛 점 44px · 0.7초 · 천천히 흩어지며 작아짐). Navi 를 끄면 남은 꼬리 · 링도 바로 지웁니다.",
    } },
  } },
  { version = "2.8.13", flavor = "retail", cards = {
    { title = "NSRT 전문화 전용 메모도 보관함에서 그대로", lines = {
      "보관함에서 되살린 메모가 전문화 연결과 고른 칸까지 돌아옵니다 (전문화 전용 메모가 일반 메모로 바뀌지 않음).",
      "메모 1개짜리 프로필을 덮어써도 보관함에 남깁니다.",
    } },
  } },
  { version = "2.8.12", cards = {
    { title = "홈 페이지", lines = {
      "창 맨 앞 「홈」 탭에서 지금 상태를 카드로 한눈에 봅니다. 카드를 누르면 그 페이지로 갑니다.",
      "아래에는 자주 쓰는 버튼(위치 편집 · 새 소식 · UI 다시 불러오기 등)과 최근 기록이 있습니다.",
    } },
    { title = "위치 편집 · 붙이기 · 화살표 · 되돌리기", lines = {
      "옮긴 표시는 8px 칸에 맞춰 붙습니다 (도구 막대 「붙이기」로 끄고 켜기). 고른 표시는 테두리와 가운데 안내선이 보이고, 화면 가운데에 맞으면 선이 초록이 됩니다.",
      "화살표 키로 1px, Shift+화살표로 10px 옮깁니다. Tab 은 다음 표시 고르기, Ctrl+Z 또는 「되돌리기」는 한 단계 되돌리기, Esc 는 끝내기.",
    } },
    { title = "화면 & 편의 · 세부 탭", lines = {
      "칸이 많아 길던 「화면 & 편의」를 위쪽 세부 탭(화면 표시 · 전투 & 던전 · 파티 & 매크로 · NiniTools 창)으로 나눴습니다. 마지막에 본 탭을 기억합니다.",
    } },
  } },
  { version = "2.8.12", cards = {
    { title = "마우스 Navi · 꼬리 · 죽은 모습 · 둘레 링", lines = {
      "Navi 가 날아간 자리에 꼬리가 남고, 죽으면 분홍빛 다른 모습으로 커서 가운데에 붙습니다.",
      NT.FOREVER and "Navi 둘레에 시전바 링(안쪽)과 자동공격 · 자동 사격 링(바깥쪽)이 돕니다. 사운드 & Navi → Navi · 마우스 커서에서 끄고 켭니다."
        or "Navi 둘레에 시전바 링이 돕니다. 사운드 & Navi → Navi · 마우스 커서에서 끄고 켭니다.",
    } },
  } },
  { version = "2.8.12", flavor = "forever", cards = {
    { title = "UI 배율 자동", lines = {
      "화면 & 편의 → 화면 표시 → 「UI 배율 자동」을 켜면 해상도에 맞춰 픽셀 퍼펙트 배율(FHD 0.711 · QHD 0.533)로 맞춥니다. 기본은 꺼짐, 끄면 원래대로.",
    } },
  } },
  { version = "2.8.12", flavor = "retail", cards = {
    { title = "NSRT 메모 · 한꺼번에 사라지면 보관함에 남김", lines = {
      "같은 이름 NSRT 프로필을 덮어써서 메모가 한꺼번에 사라지면, 지운 게 아니라 프로필이 바뀐 것으로 보고 보관함에 남겨 둡니다. 「메모 고르기」에서 다시 넣을 수 있습니다.",
      "한두 개만 없어진 것은 예전처럼 직접 지운 것으로 봅니다. 홈의 「NSRT 개인 메모」 카드에 빠진 메모 수가 보이고, 누르면 고르는 창이 뜹니다.",
    } },
  } },
  { version = "2.8.12", flavor = "forever", cards = {
    { title = "던전 기록", lines = {
      "파티 던전에 들어가면 판을 시작해 걸린 시간 · 얻은 골드 · 경험치(시간당) · 보스 잡은 시각 · 죽은 횟수를 셉니다. 던전 안에서는 작은 패널로 보입니다.",
      "밖에 나갔다 15분 안에 다시 들어오면 같은 판으로 이어집니다. 지난 판은 화면 & 편의 → 전투 & 던전 → 던전 기록에서 봅니다 (최근 30판).",
    } },
  } },
  { version = "2.8.11", flavor = "retail", cards = {
    { title = "부하 기록 「최대」 숫자 고침", lines = {
      "예전 「최대」는 접속 후 가장 큰 값이라 풀마다 같은 숫자가 반복됐습니다. 이제 그 풀에서 새로 커졌을 때만 「이번 풀 최대」로 보입니다.",
    } },
  } },
  { version = "2.8.10", flavor = "retail", cards = {
    { title = "부하 기록 복사", lines = {
      "「부하 기록 보기」 창 오른쪽 위 「복사용 글」을 누르면 글이 전체 선택됩니다. Ctrl+C 로 복사해서 붙여 넣으면 됩니다 (모든 애드온 숫자 포함).",
    } },
  } },
  { version = "2.8.9", cards = {
    { title = "화면 다듬기", lines = {
      "작은 스크롤 막대(골드 캐릭터 목록 · NSRT 메모 칸 · 메모 넣기 창)를 니니툴 모양으로 바꿨습니다. 내용이 짧으면 막대가 숨습니다.",
      "글꼴 고르기 버튼에서 글자가 삐져나오던 것을 고쳤습니다. 페이지 이름은 「차단 & 쐐기」 · 「골드 내역」으로 한글로 맞췄습니다.",
      "「설정 & 진단」은 칸 여백을 줄여 스크롤 없이 한 화면에 보입니다. 흐려진 스위치에서 원이 겹쳐 보이던 것도 고쳤습니다.",
    } },
    { title = "골드 내역 · 상점 판매 한 줄로", lines = {
      "상점을 한 번 열고 닫는 동안 판 물건은 한 줄(합계 · n건)로 묶입니다. 이전에 쌓인 기록은 그대로입니다.",
    } },
  } },
  { version = "2.8.9", flavor = "retail", cards = {
    { title = "부하 기록 보기 · 버튼 추가", lines = {
      "설정 & 진단 → 「기록」 칸의 「부하 기록 보기」로 풀마다 어떤 애드온이 무거웠는지(끊김 횟수) 게임 안에서 바로 봅니다.",
      "「유지관리」 칸에 주문 경보 켜기 · 적 숫자 테스트 · 주시 매크로 캐릭터용 버튼이 생겼습니다.",
    } },
  } },
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
