# NiniTools 다음 버전 할 일

배포 ZIP에는 안 들어가는 메모입니다 (`NiniTools/` 폴더 밖).

## 2.8.22 따끔 (11/26~27 · 시험판 ouch-test1~3 · 로컬 브랜치 ouch-test)
- test1(공대): UNIT_COMBAT 은 비밀 값 아님 · 공대 쫄 광역 물리기(야만적인 고함 · 칼날 부채 · 피 채취)에도 울려 너무 잦음
- test3(송곳니의 제단 +12 · 11/27): UnitThreatSituation 비밀 아님 · 어그로 판단 정확(18:52 26초 몹에게 맞을 때만) · 적 이름표 대상은 전부 비밀
  · 쐐기 안 SendChatMessage SAY = ADDON_ACTION_BLOCKED 7/7 → 나만 보기(채팅창 + RaidNotice 가운데) · 소리 없음 (사용자)
  · 말하기는 쐐기 밖 5인 던전만 선택 · 막히면 그 접속 동안 말하기 끔
- 남은 것: 「가운데 반짝임」 미리보기(UI.lua pvModel)는 2.8.23 으로

## 2.8.21 Navi 직업 요정 (11/23~24 · 시험판 test1~9 · wow-personal navi-class-mockup)
- 「가운데 요정」 = 요정(Aura87) · 직업 요정 코스프레(NaviClassCosplay · 시안 11 · 직접 그림) · 직업 요정 컬러(NaviClassColor · 사용자 제공 그림)
- 모든 요정: 3D 빛(모델) · 가운데 파란 구슬 끔 (dim 0) · 요정 +5 · 0.9 (사용자: 인게임에서 하얗게 묻힘 → 「가운데 빛 모두 끄기」)
- 컬러: BLEND · 1.4배 · 직업별 크기 보정(COLOR_CLASS_FIX) · 그림 무게중심으로 기본 요정 자리 맞춤(COLOR_CENTER)
- 죽은 8자: 화면 가운데 고정 · Spiral 프레임당 1번
- 시험판 값(class · class9 · class10 · class11)은 cosplay 로 · naviFairyTestClass 지움

## 2.8.21 (다음 버전업 때 넣기 · 2026-11-23 사용자 「다음버전업할때 넣자」)
다른 AI 검토(2.8.20) 중 맞는 것만. 모델 9개 「연구실」 · SetModel 결과 검사 · 임시값 저장은 안 함 (2.8.16 에 4개만 남기기로 정함)
- [x] 포에버 링 문구: UI.lua 3158 「Navi 둘레 시전바 · 자동공격 링」 → 「시전바 · 원거리 자동 사격 링」 · 1469 검색어 · NaviCursor.lua 머리 주석(8 · 378 · 476 · 683)
- [x] README_KO.txt: 첫 줄 2.8.16 → 현재 버전 · 「포에버는 자동공격 링도」 → 원거리 자동 사격 링
- [ ] (2.8.23 으로 미룸) 설정창 Navi 미리보기(UI.lua ~3214 pvModel 166890)에 고른 반짝임 모델도 그리기 (SparkModelID · 끄기면 안 그림 · 포에버 빛줄기 165816)
- [x] 죽은 나비 8자 좌표: 프레임마다 Spiral() 을 ApplyAnchor 마다 다시 계산 → 한 프레임에 한 번 계산해 같이 쓰기 (체감은 작음)
- [x] 계정 달력 ↔ 분석기 안내 (2026-11-23 사용자): NiniAnalyzer(BLUE 1.0.16~)와 같이 쓰면 계정 달력 공대 초대가 구글 캘린더 「니니 레이드 (WoW)」에 저장된다고 적기
      · README_KO.txt [계정 달력] 단락 끝 한 줄 · 2.8.21 새 소식 카드 (본섭만 · 포에버는 계정 달력 없음) · 디스코드 체인지로그 한 줄 (제품명 영어: NiniAnalyzer)

## 2.8.20
- 포에버 ADDON_ACTION_FORBIDDEN (CLEU 등록 막힘 · 22x) → CLEU 안 씀 · test6 근접 링 공격 속도 주기 → UnitAttackSpeed 비밀 값(232x) → 포에버 근접 링 뺌 · plainNum 으로 시전/원거리만

## 2.8.19
- 죽은 모습(166351) 가운데 너무 밝음 (사용자 스샷) → modelAlpha 1 → 0.45 · orb 흰 0.51 → 분홍 (1,0.62,0.78) 0.28 · 더 어둡게 원하면 modelAlpha 부터
  → test1(45%)도 하얗게 번짐 (모델이 빛을 겹쳐 그림) → 사용자: 「가운데 빛 아예 없애기」 → dead.model = nil (ClearModel) · orb 0
  → test2: 「링이 없어졌다」(신성 보호막 모델이 링 역할이었음) → deadRing: NaviRing.tga 분홍 46px ADD · 시전 링과 같은 자리
  → 사용자가 위크오라 문자열 다시 줌 → 풀어 보니 죽은 모습 겹침 순서가 다름: 모델 → 공 65 → 분홍 원 50 BLEND → Aura87 요정 → 분홍 빛 30 ADD .65
    니니툴: 요정(background) 맨 아래(+1) · 분홍 원 ADD → 하얗게 번짐. → 죽을 때 요정 +5 · 원 BLEND 50 · 공 65 · deadCore 추가 · 모델 0.9 · deadRing 뺌
    (위크오라 죽은 모습은 커서 한가운데 · 니니툴은 2.8.16 부터 평소 자리 유지)
  → 「원본은 죽으면 나비가 막 움직이지?」 → 위크오라 죽은 묶음 전부 preset spiralandpulse = 이동만 (6초 · x/y 100 · WeakAuras Prototypes.lua 의 식) → Shift() 에 Spiral() · 죽은 동안 매 프레임 ApplyGeometry

## 2.8.18
- /rl · /기 리로드 (UI.lua · PLAYER_LOGIN 때 다른 애드온이 안 쓰는 것만) · 사용자: 본섭은 되는데 포에버는 안 됨
- Navi 반짝임 -6px 는 포에버만 (사용자: 본섭은 2.8.16 이전 자리가 맞았음 · 반짝반짝 · 비전 모으기)

## 2.8.17
- 골드: 포에버 11/20 부터 GetRealmName() == "" → "-니니" 키로 따로 쌓임 (사용자 WTF: 171건 · 34g) → realmName() 빈 값 무시 · 같은 이름 하나면 기존 서버 키 이어 씀 · mergeBlankRealm (거래 char 옮김 · db.mergedKeys · goldBackupMerged)
  같은 이름 캐릭이 서버 여럿이면 고르지 않음 → "Unknown-이름" (포에버 서버 하나라 해당 없음)

## 대기 (버전 미정)
- 포에버 UI 배율 자동 (2.8.12 · 기본 꺼짐): 사용자가 써 보고 없앨지 둘지 정하기로 함 (11/19). 없애면 UIScale.lua · Camelot TOC 줄 · QOL uiscale 칸 · News/CHANGELOG/README 한 줄씩
- 대기: 사용자가 포에버에 LittleWigs 설치 + BigWigs 승리·초읽기 소리를 뜌미로 설정함 (11/9) → 다음 인던에서 소리 나면 이 항목은 안 함
- 포에버 인던 네임드 킬 → 「뜌미 승리」 소리 (사용자 요청 · 2.8.4 의 「인던 관련」 한 가지가 이것)
  · 본섭은 이미 됨: 니니툴은 LSM 에 「뜌미 승리」만 등록하고, 소리는 BigWigs 승리 소리 설정이 냄 → 본섭은 건드리지 않음
  · 포에버 먼저 확인: BigWigs 옵션 승리 소리를 「뜌미 승리」로 고르면 되는지 (니니툴이 포에버에서도 등록함)
  · 인던 보스 모듈(LittleWigs)이 없어 BigWigs 가 안 울리면 → 니니툴 Camelot 전용으로 ENCOUNTER_END 성공 + 던전(party)일 때 재생
  · BigWigs 가 이미 울린 킬은 건너뛰어 두 번 안 나게 · 켜고 끄는 스위치

## 2.8.16
- coreGlow(가운데 하늘색 빛): 2.8.13 은 요정(+2) 위(+5) · 100% 라 요정 가운데를 파랗게 덮음 (11/20 사용자 스샷) → 요정 뒤(+1) · 45% (사용자: 「요정 뒤에 깔리게 약하게」) → 10% (사용자 11/20 릴리스 직전)
- 죽은 모습 shift=false (평소 자리 · 사용자 11/20) · 반짝임 숨김은 form.dead 로
- 포에버 = 2.8.12 + conjureitem 100% · 본섭 기본 = 끄기(2.8.12 모습) · 「가운데 반짝임 효과」 드롭다운으로 시험 (db.naviSparkModel · NT.NAVI_SPARK_CHOICES)
  후보 FileDataID 는 wowdev/wow-listfile community-listfile.csv 에서 찾음 (모델 위치 · 크기는 conjureitem 과 같게 시작 · 실게임에서 사용자가 골라 보고 알려 주기로)
  165816 conjureitem · 1709417 cfx_mage_arcaneprecastgeneric_precasthand · 1710678 cfx_priest_holyprecastbluegeneric_precasthand ·
  5054341 10gfx_arcane_precasthands · 3090068 cfx_kyrian_mage_arcane_precast · 794764 fill_arcane_precast_01 · 165817 conjureitemcast ·
  6907664 11fx_arcanesparkles01 · 5876234 11fx_sparklysparkles01
  (참고: Navi 요정 166890 = spells/slam_impact_chest.m2 · 죽은 모습 166351 = spells/holyprotection_chest.m2)
- 사용자 시험 후 (11/20): 끄기 · 반짝반짝(5876234) · 비전 양손 모으기(5054341) · 비전 반짝이(6907664)만 남김 · 포에버에도 같은 드롭다운 + 빛줄기(165816, 포에버 기본)
  예전 시험판에서 고른 값이 목록에 없으면 기본으로 (SPARK_OK) · 포에버 확인(11/20 영상): 비전 양손 모으기 · 반짝반짝 나옴 · 비전 반짝이는 텍스처 없어 체크무늬 → 포에버 목록에서 뺌(retailOnly)
- 사용자: 포에버 비전 양손 모으기 위치가 안 맞음 (11/20 영상: 고리가 요정보다 약간 아래) → 효과 위치 ←→ · ↓↑ 슬라이더 (db.naviSparkOffset[id], 픽셀)
  → 사용자: 「모두 0 / -6 으로 위치 고정」(11/20) · 슬라이더 빼고 SPARK_FIX (0, -6) 모든 효과 · 본섭 · 포에버
- 홈 부하 카드 숫자 먼저 · EllesmereUI → EUI

## 2.8.15
- 사용자: 시험판(효과 2배 · coreGlow 뺌 · 뒤 요정 겹) 폐기 → NaviCursor.lua · UI.lua 를 v2.8.13 으로 되돌림 (가운데 빛 슬라이더 제거)
- 본섭만 conjureitem 틀 1.3배 (RETAIL_SPARK_SCALE) · 빛 모이는 가운데(모델 baseY) 기준으로 위치 보정
  (사용자 뜻: 「요정 바깥 원 안으로 빛줄기가 모여 뱅그르 터지는 것」 크기만 조금 크게)
- CHANGELOG_2.8.14.txt 가 v2.8.14 에 빠져 있었음 → 지금 추가

## 2.8.14
- Navi 「가운데 빛」 밝기 슬라이더 (naviGlowAlpha 20~100 · 기본 60): background · orb · coreGlow 알파에 곱함 (11/19 본섭 영상: 파란 빛이 요정 모양 가림)
- 본섭에서 conjureitem(165816) 빛줄기가 포에버처럼 안 보임 (사용자 본섭 영상) · 포에버는 잘 나옴 → 본섭용 대체 효과는 미정

## 2.8.13
- v2.8.12 태그(1a5f2a2) 이후 고친 것들 (11/19)
- 검토 반영 (11/19 다른 AI 검토): 보관함 전문화 연결(PersonalReminderSpecs) · 고른 칸 보관 · 복원 /
  메모 전부 사라짐 = 덮어쓰기 (1개 프로필) / Navi 끌 때 꼬리 · 링 즉시 정리
- Navi 꼬리 굵게 (NaviSpark 44px · 0.7초 · 간격 12 · 드리프트 · 40개)
- Navi 가운데 반짝임 = spells/conjureitem.m2 (165816, 포에버 위크오라 Navi Glow Alive 11 과 같은 위치 · 크기) + CircleGlow 30 하늘색
  (처음 만든 자작 별빛 · 모이는 고리는 사용자 영상 보고 이걸로 바꿈)

## 2.8.12
- 홈 페이지(HomeUI.lua): 상태 카드(본섭 NSRT 메모 · 생존기 담당 · 골드 · 마지막 풀 부하 / 포에버 골드 · 던전 기록 · 전투 시간 · 매크로) · 빠른 실행 · 최근 기록 · 새 소식
- 위치 편집: 붙이기 8px · 화살표 1px(Shift 10px) · Tab · Ctrl+Z 되돌리기 · 고른 표시 테두리 · 가운데 안내선 · 좌표
- 화면 & 편의 세부 탭 (UI:AccordionGroups · db.subTabs)
- NSRT 보관함: 한꺼번에 사라지면(3개 이상 또는 2개 이상 & 절반 이상) 보관함에 남김 · 1~2개는 지운 것으로
- 포에버 던전 기록 (Modules/Combat/DungeonRun.lua · Camelot TOC 만)
- 마우스 Navi: 꼬리 · 죽은 모습(모델 166351 · 분홍) · 시전 링 / 포에버 자동공격 링(CLEU) · 그림 NaviRing/NaviDot 자체 제작
  (11/19 사용자: 포에버 UntrueUI Navi 위크오라는 안 쓰고 이것만. 위크오라 코드 · Fairy/NaviTarget 그림 · 젤다 소리는 안 넣음)
- Navi 출처 표기 (11/19 사용자 제안): NaviCursor/NaviChat 머리 주석 · README_KO 「출처 · 고마운 분」 · 설정 Navi 미리보기 아래 한 줄
- 포에버 UI 배율 자동 (Modules/Media/UIScale.lua · 768/세로 · 기본 꺼짐)
- 목조르기 커버리지에 파열 추가는 안 하기로 (11/19 · 추적하는 오라가 늘수록 이름표 오라 훑기가 늘어 부하 · Naowh Dot Coverage 끄고 끊김 없어짐)

## 2.8.11
- 부하 기록 PeakTime 은 세션 누적 → Snapshot 에 peak 저장 · 풀 끝에 더 커졌을 때만 r.peak · p.peakPerPull 없는 예전 기록은 최대 숨김
  (사용자 11/15 붙여 준 기록에서 707.7/235.2/183.2 가 모든 풀에 반복)

## 2.8.10
- 부하 기록 창 「복사용 글」 (사용자 11/15: 「부하 기록은 텍스트로 못 긁네」) · EditBox 읽기 전용 · 애드온 전부

## 2.8.9
- 사용자 11/13~14 스크린샷 예약 2건 + 「전체적으로 보완할 것 훑어보기 → 보완 ㄱㄱ」
  · UI:DropdownRow 한 줄 글 + width 인자 (글꼴 2줄만 240px) · 글꼴 항목 「자동」
  · UI:ScrollArea (작은 칸 공용 스크롤 · 가는 막대 · 내용 짧으면 숨김) → 골드 캐릭터 목록 · NSRT 메모 칸 · 메모 넣기 창
  · UI:CheckBox · 메모 넣기 창/자가진단 창 닫기 버튼 니니툴 모양
  · 페이지 이름 한글 (차단 & 쐐기 · 골드 내역) · 영어 채팅 안내 한글
  · 골드: 상점 방문(MERCHANT_SHOW~CLOSED) 한 번의 판매/구매를 한 줄로 (entry.visit · n · detail 「상점 · n건」)
  · 설정 & 진단: 「부하 기록 보기」 창 (UI:ShowPerfLog) · 유지관리 버튼 3개 (주문 경보 켜기 · 적 숫자 테스트 · 주시 매크로 캐릭터용)
  · 2.8.3 이전 CHANGELOG → docs/changelog (배포 ZIP 밖)
- 릴리스 후 보강 (사용자 11/14 「2.8.9로 작업 가능?」 · 같은 2.8.9 로 다시 냄)
  · UI:Toggle 흐림: row:SetAlpha 를 가로채 글자만 투명 · 스위치는 불투명 + 바탕색과 섞은 색 (원 겹침 수정)
  · 설정 & 진단 2단 배치 (왼쪽 버전 · 현재 환경 260px / 오른쪽 유지관리 · 글꼴 / 아래 기록 224) · contentHeight 약 514
- 안 한 것 (남김)
  · 슬라이더 2곳의 OptionsSliderTemplate: 끌기 안정성 때문에 일부러 쓰는 것 (손잡이 · 선은 이미 니니툴 모양) → 그대로
  · EXBoss 프로필 창 버튼: UI:Button 이 있으면 이미 니니툴 모양 (기본 버튼은 비상용) → 그대로
  · /nini check cpu: 부하 기록과 겹치지만 자가진단 코드에 깊이 섞여 있어 이번엔 그대로 둠 (다음에 정리할지 사용자 확인)
  · /nk debug · /nk kickstate: 개발용이라 버튼 안 만듦

## 2.8.8
- 보스 풀 애드온 부하 기록 (Modules/Perf/AddonPerf.lua · 본섭 TOC만 · 기본 켜짐): C_AddOnProfiler EncounterAverageTime 상위 8 · CountTimeOver5/50/100Ms 풀 전후 차이 · 전투 밖에서만 읽음
  (사용자 11/13: 울라텍 6·7트 암살 끊김 원인 확인 — 로그상 내 디버프 동시 90개 · 잠행 판 3배 → 이름표 애드온 의심 · 측정으로 확정하려고)
- 저장: NiniToolsDB.modules.addonPerf.pulls[] = {at, enc, name, diff, spec, char, success, dur, allAvg, appAvg, addons[{a, avg, peak, n5, n50, n100}]}
- 다음: GOLD 분석기에서 WTF 의 addonPerf 를 트라이에 붙여 보여 주기 (풀 시각으로 맞춤)
- 릴리스 전 보강 (사용자 11/13 「명령어 다 외워서 치기 어려움 · 박스나 온오프로」): 설정 & 진단(TOOLS) 페이지에
  「기록 (분석기용)」 스위치 3개(부하 기록 · 부하 알림 · 공대 메모 캡처) + 최근 기록 글 + 지우기 버튼(두 번 눌러야) ·
  「글꼴」 드롭다운 2개(본문 · 숫자 · 자동) · 「유지관리」 자가진단 버튼 · 채팅 안내에서 명령어 표시 뺌 (명령어 자체는 그대로 동작)

## 2.8.7
- NSRT 개인 메모 넣기: 같은 전문화라도 넣는 메모에 있는 줄 종류(스킬/글자)만 교체 (사용자 11/12: 울라텍 큰 알 글자 메모를 넣자 잠행·암살 쿨기 줄이 지워짐)
- 메모 캡처: NSRT_REMINDER_CHANGED 콜백이 (owner, 이벤트, 개인, 공유) 로 와서 개인 메모를 공유 메모로 적던 것 수정
- 참고 (안 고침 · NSRT 쪽): 풀 전 개인 메모 자동 불러오기는 NSRT 지역표(BossData PrePullEncounterZones) · 레디체크/풀카운트 때만. 못 찾으면 ENCOUNTER_START 때 불러옴

## 2.8.6
- NSRT 개인 메모: 보스 정보 없는 Lorrgs 메모(Name:Unknown · EncounterID 없음) → 보스 고르기 · 난이도 단추 · 기본값 = 이번 접속 마지막 레이드 풀 (사용자 11/10 스크린샷)

## 2.8.5
- 레이아웃 보완 (사용자 2026-11-09 「추천은 빼고 니니툴이랑 분석기 레이아웃 보완」)
  · 설정 검색 (UI.lua BuildSearchBox · 접는 항목 · 섹션 · SEARCH_KEYWORDS)
  · 새 소식 카드 (News.lua · modules.news.seen · 첫 설치는 안 띄움)
  · 위치 편집 모드 (EditMode.lua · 각 기능 잠금 API 호출 + 격자 · 전투 시작 시 자동 종료)

## 2.8.4
- 포에버 주시 · 차단 매크로 자동 생성 (Modules/Kick/ForeverMacros.lua · NiniKickFocus 징표 아이콘 고정 · NiniKickAuto)
- 포에버 파티 인사: 남의 파티에 들어갈 때만 (내가 파티장이면 안 함 · 인스턴스 그룹은 함)

## 2.8.3
- 포에버 파티 입장 인사 「안녕하세요.」 (Modules/Social/PartyGreeting.lua · Camelot TOC 전용 · 본섭 규칙과 같음)

## 2.8.2
- 포에버 전투 시간 (Modules/Combat/CombatTimer.lua · Camelot TOC 전용 · 화면&편의 「전투 시간」)

## 2.8.1
- 포에버 목적지 안내: showInGameNavigation=0 이어도 표시 (포에버 기본 0)

## 2.8.0
- WoW 포에버 지원: NiniTools_Camelot.toc (16001 · camelot) · NT.FOREVER · 포에버 메뉴 = Gold · 화면&편의 · 사운드&Navi
- 포에버 기능 추가는 플레이하면서 결정 (사용자 2026-11-07)

## 2.7.2
- NSRT 「메모 보관함」 (개인 + 공용): NSRT에 있는 개인 메모 · 공용 메모 사본을 NiniTools 계정 DB에 둠.
  NSRT 프로필이 바뀌어 없는 메모가 생기면(나오 /nui install 등) 접속 · /reload 때 「NSRT 메모 넣기」 창 → 넣을 메모만 체크.
  같은 이름은 덮어쓰지 않음 · 그 프로필에서 지운 메모는 보관함에서도 뺌 · 체크 해제한 메모는 그 프로필에서 다시 안 물음.
  NSRT 페이지 아래 「메모 고르기」 버튼으로 언제든 열기. (실제 저장 파일: Naowh → Naowh 2 2 개인 20 + 공용 2 확인)

## 2.7.1 에서 끝남 (2026-11-06)
- Navi 커서 링 · 반짝임 토글 없애고 항상 켬
- 버튼 이름: 「/nui install」 · 「그래픽 최적화」
- □ 기호: 검색 돋보기 · Navi 미리보기 커서 · 드롭다운 화살표 · NSRT 결과 ✓/✕
- NSRT 12.1.33 전문화별 개인 메모 대응
- 「!」 EllesmereUI 이름표 체력바에 직접 붙이기

## 보류
- EllesmereUI 차단 추적기(쐐기 · 기본 꺼짐)와 겹침 옵션: NiniTools 「Interrupt & M+」는 파티원별 쿨 막대가 아니라
  「내 차단 차례」 알림이라 겹치지 않음 → 넣지 않음. 길드원이 둘 다 켜서 헷갈린다고 하면 다시 보기.
