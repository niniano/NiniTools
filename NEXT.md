# NiniTools 다음 버전 할 일

배포 ZIP에는 안 들어가는 메모입니다 (`NiniTools/` 폴더 밖).

## 2.8.5 (예약)
- 포에버 인던 네임드 킬 → 「뜌미 승리」 소리 (사용자 요청 · 2.8.4 의 「인던 관련」 한 가지가 이것)
  · 본섭은 이미 됨: 니니툴은 LSM 에 「뜌미 승리」만 등록하고, 소리는 BigWigs 승리 소리 설정이 냄 → 본섭은 건드리지 않음
  · 포에버 먼저 확인: BigWigs 옵션 승리 소리를 「뜌미 승리」로 고르면 되는지 (니니툴이 포에버에서도 등록함)
  · 인던 보스 모듈(LittleWigs)이 없어 BigWigs 가 안 울리면 → 니니툴 Camelot 전용으로 ENCOUNTER_END 성공 + 던전(party)일 때 재생
  · BigWigs 가 이미 울린 킬은 건너뛰어 두 번 안 나게 · 켜고 끄는 스위치

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
