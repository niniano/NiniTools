# NiniTools 다음 버전 (2.7.1) 할 일

배포 ZIP에는 안 들어가는 메모입니다 (`NiniTools/` 폴더 밖).

## 요청 (2026-11-05)
1. **Navi 마우스 커서: 「커서 링」 · 「반짝임 효과」 토글 없애고 항상 켜기**
   - `UI.lua` 2422 · 2424 `Toggle(... "naviCursorRingEnabled" / "naviCursorGlowEnabled")` 줄 삭제 → 아래 줄(크기 슬라이더 등) 위치 당기기 · 섹션 높이 줄이기
   - 저장값이 false 로 남은 사람도 켜지게: 불러올 때 `naviCursorRingEnabled = true` · `naviCursorGlowEnabled = true` 로 덮기 (Core 기본값 + 로드 시 강제)
   - `SetNaviCursorRingEnabled` · `SetNaviCursorGlowEnabled` 는 남겨도 됨 (호출만 안 함) · `/nini check` 에 링/반짝임 줄이 있으면 정리
2. **「나오 프로필 전부」 → 「/nui install」로 이름 변경**
   - 버튼: `UI.lua` 2828 · 안내 문구: `Modules/Naowh/NaowhUILink.lua` 57 (「…를 쓰려면 설치 필요」) · 주석 4줄 · `README_KO.txt` 103~104
   - 동작은 그대로 (각자 설치한 NaowhUI 설치기 열기 · 나오 프로필 파일은 넣지 않음)
3. **「Naowh 그래픽 적용」 → 「그래픽 최적화」로 이름 변경**
   - 버튼: `UI.lua` 2578 · 결과 메시지: `Modules/Kick/Core.lua` 675 「Naowh 그래픽 최적화 적용」 → 「그래픽 최적화 적용」
   - 상태 줄 「최근: Naowh 그래픽 최적화 적용」, 섹션 설명 「Naowh 기준 그래픽」도 같이 정리

## 같이 고칠 것 (스크린샷에서 발견 · 글자가 □ 로 나옴)
게임 글꼴에 없는 기호라 네모(□)로 보임 → 텍스처로 바꾸기
- **Gold History 검색칸 돋보기** `⌕` (U+2315) · `UI.lua` 2122 → `Interface\Common\UI-Searchbox-Icon` 텍스처
- **Navi 미리보기 가운데 커서** `✥` (U+2725) · `UI.lua` 2477 → 마우스 커서 텍스처 (`Interface\Cursor\Point`)
- 확인 필요 (같은 종류 기호): 드롭다운 화살표 `⌄` (U+2304) · `UI.lua` 678 / NSRT 메모 결과 `✓` `✕` · `UI.lua` 1495
  - 게임에서 □ 로 보이면 `▼` · 체크/엑스 텍스처로

## 버전
- TOC / Core 2.7.1 · CHANGELOG_2.7.1 · README_KO
