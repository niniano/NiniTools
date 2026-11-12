NiniTools 2.8.7

NiniTools는 차단/M+, 골드 기록, NSRT 개인 메모, 화면 편의, 사운드/Navi, Naowh Smart Reminders 연동을 한 창에 모은 WoW 통합 편의 애드온입니다.

[메인 메뉴]
- Gold History
- Interrupt & M+
- NSRT 개인 메모
- 화면 & 편의
- 사운드 & Navi
- 계정 달력 (2.5.8)
- 우측 상단 버튼: 버전/상태/기본 설정

[주요 기능]
- 차단 담당 징표/로테이션, 중요 시전·생존기 알림, 중요몹 ! 표시
- 중요몹 ! 표시: 그림 클래식(기본)/기울임 · 흰 외곽선 · 주황↔핫핑크 · 기본형/펄스형/강조형, 크기 · 위치(체력바 위 기준 X·Y 이동) + 실시간 미리보기
- 「!」는 쐐기 · 추종자 던전에서 표시 · /nini bang test 로 어디서나 모양 확인
- NiniTools N 브랜드: 설정창 왼쪽 상단은 배경 없는 Wordmark, 우측 설정 버튼은 배경 없는 Round, 미니맵은 설정 버튼과 같은 두 줄 N(미니맵용 굵은 선) 사용
- 전투시간 및 주변 적 숫자 표시
- Lorrgs 등 메모를 NSRT 개인 메모로 가져오기
- NSRT 메모 보관함: NSRT 프로필이 바뀌어도(나오 /nui install 등) 개인·공용 메모를 골라서 다시 넣기
- 목적지 안내, 채팅 말풍선, 던전 검색, 미니맵/창 설정
- GTFO, 효과음, CallMe 이름 호출, Navi 마우스 커서
- Gold History: 현재 소지금 스냅샷, 거래 기록, 필터/검색, 전투부대 은행

[Naowh Smart Reminders]
- 도적 프로필: Nini Rogue M+ S2 - Safe Alpha
- 암살/무법/잠행 3특성에 같은 프로필을 연결합니다.
- 쐐기 기본 규칙과 Raid S2 Safe Alpha 기본 체크를 같은 프로필에 구성합니다.
- 레이드 기본 체크는 숫자 seed version으로 최초 필요한 항목만 채우며, 이후 사용자가 Raid Bosses에서 추가한 수동 체크는 보존합니다.
- 레이드 기본값은 교란 중심이며, 영혼살무사 네크잘리의 기원은 그림자 망토로 시드합니다. 자동 회피 레이드 바인딩은 넣지 않습니다.
- Naowh Smart Reminders의 활성 프로필이 실제 ON일 때만 Naowh가 생존기 알림 담당으로 판정됩니다.
- Smart Reminders OFF/미설치/API 준비 전에는 NiniTools 경로를 유지합니다.
- 설정 > 차단 > 생존기 알림에서 'Naowh가 켜져 있어도 NiniTools 생존기 알림 유지'를 선택할 수 있습니다.
- /nini check에서 현재 담당과 판정 근거를 확인할 수 있습니다.
- EXBoss 사용 시 도적 AoE는 EXBoss 음성 뒤 생존기 TTS가 이어집니다.
- EXBoss 미사용/미설치 시 검증된 AoE fallback을 NiniTools가 추적합니다.
- NiniTools 자체 Media/Sounds/Sonar.ogg를 포함합니다.
- 테스트: /nininsr sonar
- 상태: /nininsr status 또는 /nininsr fallbackstatus
- (2.5.7) 내가 고른 Smart Reminders 프로필은 건드리지 않습니다.
  - 기본(auto): 활성 프로필이 비었거나 기본·니니 프로필일 때만 니니 프로필로 맞춥니다. 다른 프로필이 켜져 있으면 그대로 두고, 니니 생존기 알림도 끕니다.
  - /nininsr use (또는 설정 「니니 프로필 쓰기」): 늘 니니 프로필을 씁니다 (예전 동작).
  - /nininsr off (또는 설정 「안 씀」): 니니 프로필을 설치·전환하지 않습니다. /nininsr auto 로 기본으로 돌아갑니다.
  - 니니 프로필 안의 관리 항목(presets·규칙·전문화 연결)은 접속 때마다 NiniTools 기본값으로 다시 맞춰집니다. 내 설정은 니니 프로필을 복사한 다른 이름의 프로필에 하세요.

[전용 매크로]
- NiniTools는 차단 흐름에 필요한 NiniKickFocus / NiniKickAuto 두 개만 관리합니다.
- 범용 매크로 제작은 EllesmereUI 등 외부 편의 기능에 맡깁니다.
- 기존 NiniPotion 매크로는 삭제하지 않지만 NiniTools가 더 이상 생성/수정하지 않습니다.

[설치]
1. 게임을 종료합니다.
2. ZIP 안의 NiniTools 폴더를 World of Warcraft/_retail_/Interface/AddOns/에 넣습니다.
3. 기존 NiniTools를 덮어쓸 때 WTF의 NiniToolsDB는 삭제하지 마세요.
4. 게임 실행 후 NiniTools 설정창과 /nini check로 상태를 확인하세요.

[업데이트 주의]
- 기존 NiniToolsDB를 유지하면 설정과 골드 기록이 보존됩니다.
- 기존 Raid Bosses 수동 체크는 2.5.2의 보존 병합 구조에서 유지됩니다.
- 레이드 seed version은 애드온 문자열 버전과 별개이므로 2.5.2 정식 전환만으로 재시드/초기화되지 않습니다.

[2.5.2 안정성 확인]
- EventDispatcher의 미등록 이벤트 UnregisterEvent 경로 수정 후 ADDON_ACTION_FORBIDDEN 재발 0회 확인.
- /reload, 전투 진입/종료, 쐐기 시작, 특성 변경, 지역 이동 흐름에서 사용 확인.
- Naowh 레이드 기본 체크와 이후 수동 체크 보존 확인.

[배포]
- 현재 정식 버전: 2.8.7
- 최신 변경사항: CHANGELOG_2.8.7.txt (2.8.6: CHANGELOG_2.8.6.txt · 2.8.5: CHANGELOG_2.8.5.txt · 2.8.4: CHANGELOG_2.8.4.txt · 2.8.3: CHANGELOG_2.8.3.txt · 2.8.2: CHANGELOG_2.8.2.txt · 2.8.1: CHANGELOG_2.8.1.txt · 2.8.0: CHANGELOG_2.8.0.txt · 2.7.2: CHANGELOG_2.7.2.txt · 2.7.1: CHANGELOG_2.7.1.txt · 2.7.0: CHANGELOG_2.7.0.txt · 2.6.9: CHANGELOG_2.6.9.txt · 2.6.8: CHANGELOG_2.6.8.txt · 2.6.7: CHANGELOG_2.6.7.txt · 2.6.6: CHANGELOG_2.6.6.txt · 2.6.5: CHANGELOG_2.6.5.txt · 2.6.4: CHANGELOG_2.6.4.txt · 2.6.3: CHANGELOG_2.6.3.txt · 2.6.0 ~ 2.6.2는 2.6.3에 포함 · 2.5.9: CHANGELOG_2.5.9.txt · 2.5.8: CHANGELOG_2.5.8.txt · 2.5.7: CHANGELOG_2.5.7.txt · 2.5.6: CHANGELOG_2.5.6.txt · 2.5.5: CHANGELOG_2.5.5.txt · 2.5.4: CHANGELOG_2.5.4.txt)

[계정 달력 (2.5.8)]
- NiniTools 창 「계정 달력」 탭 · /nini cal
- 각 캐릭이 접속할 때 와우 달력에서 이번 달·다음 달 초대를 읽어 계정 전체를 한 달력에 모읍니다.
- 날짜 칸: 금색 = 받은 초대 · 청록 점 = 내 메모 · 글자색 = 수락/미정/응답 전/거절
- 초대를 누르면 받은 캐릭 · 초대한 사람 · 상태 · 참가자(직업·응답)를 봅니다.
- (2.5.9) 오른쪽 위 초대 목록은 그날 초대 수만큼만 차지하고, 오른쪽 아무 곳에서나 마우스 휠로 참가자 목록을 넘깁니다.
- 접속한 캐릭의 초대는 창에서 바로 수락·미정·거절 (신청형 일정은 신청·미정).
- 참가자 목록은 그 캐릭으로 접속했을 때 읽습니다 (2주 안 일정은 접속할 때 몇 개 미리 읽음).
- 로그 주소: 길드 일정은 길드 로그, 개인 초대는 초대한 사람 로그 · 참가자 이름을 누르면 그 캐릭 로그 (복사 창).
- 날짜 메모는 계정 공용입니다. 지난 초대는 120일까지 남깁니다.
- 와우 기본 달력 창이 열려 있거나 전투 중에는 달력을 건드리지 않고, 닫히거나 전투가 끝나면 읽습니다.

[WoW 포에버 (2.8.0)]
- 같은 NiniTools 폴더를 포에버 AddOns 폴더에도 넣으면 됩니다. 포에버에서는 NiniTools_Camelot.toc 가 대신 읽힙니다.
- 포에버에서 되는 것: Gold History · 사운드 & Navi(GTFO · 효과음 · CallMe · Navi 커서 · Navi 채팅) · 화면 & 편의(목적지 안내 · 전투 시간 · 파티 입장 인사 · 주시 · 차단 매크로 · 채팅 말풍선 · 미니맵 버튼 · 창 설정)
- 포에버에서 빠진 것: 차단 · 쐐기 · 중요몹 · 주변 적 숫자 · NSRT · Smart Reminders · EXBoss · NaowhUI 연동 · 계정 달력 · 던전 검색 · 전투부대 은행 · 진단
- 목적지 안내: NaowhForever(QoL)가 켜져 있으면 웨이포인트 핀과 겹치므로 처음엔 꺼짐 · 화면 & 편의에서 켜고 끄기

[NSRT 메모 보관함 (2.7.2)]
- NSRT는 메모를 프로필마다 따로 저장합니다. 나오 프로필을 새로 받으면 빈 프로필로 바뀌어 메모가 안 보입니다 (지워진 것은 아님).
- NiniTools가 접속 · /reload 때 지금 NSRT 프로필의 개인 메모 · 공용 메모 사본을 NiniTools.lua(계정 공용)에 남깁니다.
- 지금 프로필에 없는 메모가 있으면 「NSRT 메모 넣기」 창이 뜹니다. 넣을 메모만 체크하고 「선택한 메모 넣기」.
- 같은 이름 메모는 덮어쓰지 않습니다 · 그 프로필에서 지운 메모는 보관함에서도 빠집니다 · 체크 해제한 메모는 그 프로필에서 다시 묻지 않습니다.
- NiniTools 「NSRT」 페이지 아래 「메모 고르기」로 언제든 열 수 있습니다.

[공대 메모 캡처 (2.5.3)]
- 기본은 꺼짐. /nini memo on 을 입력한 캐릭터만 저장합니다.
- 공대장이 보낸 NSRT 공유 메모를 받은 시각과, 보스를 풀 때마다 그때 켜져 있던 NSRT 공유 메모·MRT 메모를 NiniTools.lua(SavedVariables)에 남깁니다.
- 메모를 읽기만 하고 바꾸거나 다시 보내지 않습니다. 같은 메모는 한 번만 저장(최대 메모 80개 · 기록 600개).
- /nini memo (상태) · /nini memo on · /nini memo off · /nini memo clear
- 저장 파일은 게임 종료나 /reload 때 디스크에 써집니다.

[글꼴 (2.5.4)]
- SharedMedia에 NaowhKR(본문)·GothamNarrowUltraKR(숫자)가 있으면 자동으로 씁니다. 없으면 EllesmereUI 글꼴 → 게임 기본 글꼴.
- /nini font (지금 글꼴) · /nini font list · /nini font body <이름> · /nini font num <이름> · /nini font auto
- 글꼴 파일은 애드온에 들어 있지 않습니다.

[EXBoss · Nini_S2 (2.5.5)]
- 니니의 EXBoss 쐐기 프로필(Naowh 프로필 바탕, 음성만 EXBoss 음성팩으로 교체)을 고를 수 있습니다. 처음 접속 때 한 번 묻습니다.
- /nini exboss (창) · /nini exboss on · off · status · eng
- off 를 쓰면 쓰기 전 쐐기 선택과 음성팩으로 돌아갑니다. 예전 선택이 없던 역할은 EXBoss 설정에서 직접 골라 주세요.
- (2.5.7) 가져온 뒤 새로 생긴 Nini_S2를 이름으로 찾아 탱커·딜러·힐러 세 칸을 직접 맞추고 확인합니다. 이름이 Nini_S2가 아닌 프로필은 절대 이름을 바꾸지 않습니다.
- (2.5.7) 영어 음성팩(EXBOSS-ENG)이 애드온 목록에서 꺼져 있으면 바꾸지 않고 알려 줍니다.
- 한국어 클라이언트는 EXBoss 음성이 기본 중국어입니다. /nini exboss eng 로 영어로 바꿀 수 있습니다.

[/nui install (2.5.5 · 2.7.1 버튼 이름 변경)]
- NaowhUI를 설치한 사람은 「/nui install」 버튼 또는 /nini naowh 로 NaowhUI 설치기를 열어 프로필(EXBoss·BigWigs·Ellesmere·NSRT·Smart Reminders·편집 모드 등)을 적용할 수 있습니다.
- NiniTools에는 Naowh 프로필이 들어 있지 않습니다. NaowhUI(와 NaowhUI_Media)를 먼저 설치하세요.

[진단]
- /nini check
- /nini check copy
- /nini check cpu start [메모]
- /nini check cpu stop
- Enemy Count 암살 목조르기 커버리지: /nec garrote on | off
- 목조르기 커버리지 디버그: /nec garrote debug
