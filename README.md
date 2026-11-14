# NiniTools

WoW 애드온 NiniTools · 차단 알림(NiniKick) · 브리핑 · 골드 장부 · 계정 달력 · NSRT 메모 가져오기 · 사운드 모듈 통합판.

## 설치
1. [Releases](../../releases)에서 최신 `NiniTools_x.y.z.zip`을 받습니다.
2. 게임을 끄고 `World of Warcraft\_retail_\Interface\AddOns\NiniTools` 폴더를 통째로 교체합니다.
3. 기존 설정(`WTF` 폴더의 NiniToolsDB)은 지우지 마세요.

## 폴더
- `NiniTools/` : 애드온 폴더 그대로 (AddOns 밑에 이 폴더를 넣으면 됨)
- 버전별 변경 내역: `NiniTools/CHANGELOG_x.y.z.txt` (2.8.3 이전은 `docs/changelog/`) · 태그 `vx.y.z`

## 버전 기록
2.5.4부터 2.6.8까지 배포한 zip을 버전마다 커밋 하나로 옮겨 왔습니다 (`git log`, 태그로 버전별 비교 가능).

> 기본 차단 소리 파일은 `Media/Sounds/Kick.ogg`입니다. 저장소의 예전 버전 커밋(v2.5.4~v2.6.8)도 이 이름으로 맞춰 두었고,
> 그때 배포한 zip과는 이 파일 이름과 경로 두 줄(`Modules/Kick/Core.lua`, `Modules/Media/Media.lua`)만 다릅니다.
