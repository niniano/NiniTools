"""NiniTools/CHANGELOG_<버전>.txt → GitHub 릴리스 설명(Markdown).

  첫 줄 「NiniTools x.y.z」        → 버림 (릴리스 제목이 대신함)
  [제목]                            → ### 제목
  - 항목 / 그 밑 들여쓴 줄           → 그대로 (Markdown 목록)
  끝에 설치 안내 한 줄을 붙인다.
"""
import re
import sys
from pathlib import Path

version = sys.argv[1]
src = Path("NiniTools") / f"CHANGELOG_{version}.txt"
if not src.is_file():
    print(f"::warning::{src} 가 없어 릴리스 설명을 자동으로 채우지 않음")
    sys.exit(0)

lines = src.read_text(encoding="utf-8-sig").splitlines()
if lines and lines[0].strip().startswith("NiniTools"):
    lines = lines[1:]
out = []
for line in lines:
    m = re.match(r"^\[(.+)\]\s*$", line)
    if m:
        if out and out[-1] != "":
            out.append("")
        out.append(f"### {m.group(1)}")
        continue
    # 들여쓴 「· 」 줄은 하위 목록으로
    m = re.match(r"^(\s+)·\s*(.*)$", line)
    if m:
        out.append(f"  - {m.group(2)}")
        continue
    out.append(line.replace("\\\\", "\\"))
while out and out[0] == "":
    out.pop(0)
body = "\n".join(out).strip()
if "### 업데이트" not in body:
    body += (
    f"\n\n---\n**설치**: 아래 `NiniTools_{version}.zip` 을 받아 게임 종료 후 "
    "`Interface\\AddOns` 에 `NiniTools` 폴더를 넣기 (WTF 는 지우지 마세요) · 본섭 · 포에버 같은 ZIP\n"
    )
Path("release_notes.md").write_text(body, encoding="utf-8")
print(body)
