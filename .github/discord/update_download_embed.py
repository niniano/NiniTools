#!/usr/bin/env python3
"""디스코드 고정 「NiniTools · NiniAnalyzer 다운로드」 임베드를 최신 버전 · 받은 횟수로 고친다.

GitHub Actions (.github/workflows/discord-download.yml) 가 4시간마다 · 릴리스 Publish 때 실행.
- 웹훅 주소: 저장소 Secret  DISCORD_DOWNLOAD_WEBHOOK   (공개 안 됨)
- 고칠 메시지: 저장소 Variable DOWNLOAD_MESSAGE_ID      (메시지 번호 · 공개돼도 상관없음)
새 메시지는 만들지 않고, 그 웹훅이 올린 고정 메시지만 고친다.
DRY_RUN=1 이면 보내지 않고 임베드만 출력.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
KST = timezone(timedelta(hours=9))
UA = "NiniDownloadEmbed"
NT_REPO, NA_REPO = "niniano/NiniTools", "niniano/NiniAnalyzer-BLUE"


def gh(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/vnd.github+json"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def releases(repo: str):
    return [r for r in gh(f"https://api.github.com/repos/{repo}/releases?per_page=100") if not r.get("draft")]


def asset(rel, suffix: str):
    for a in rel.get("assets") or []:
        if a["name"].endswith(suffix):
            return a
    return None


def count(rels, suffixes) -> int:
    return sum(int(a.get("download_count") or 0) for r in rels for a in (r.get("assets") or [])
               if any(a["name"].endswith(s) for s in suffixes))


def day(rel) -> str:
    try:
        return datetime.fromisoformat(rel["published_at"].replace("Z", "+00:00")).astimezone(KST).strftime("%Y-%m-%d")
    except Exception:
        return ""


def build_embed():
    nt_all = releases(NT_REPO)
    nt = next(r for r in nt_all if not r.get("prerelease") and asset(r, ".zip") and asset(r, ".zip")["name"].startswith("NiniTools_"))
    na_all = releases(NA_REPO)
    na = next(r for r in na_all if asset(r, "_Setup_Windows_x64.exe"))
    nt_zip = asset(nt, ".zip")["browser_download_url"]
    na_setup = asset(na, "_Setup_Windows_x64.exe")["browser_download_url"]
    na_zip_a = asset(na, "_SAFE_FOLDER.zip")
    na_zip = na_zip_a["browser_download_url"] if na_zip_a else na_setup
    nt_pat, na_pat = (".zip",), ("_Setup_Windows_x64.exe", "_SAFE_FOLDER.zip")
    nt_now, nt_tot = count([nt], nt_pat), count(nt_all, nt_pat)
    na_now, na_tot = count([na], na_pat), count(na_all, na_pat)
    nt_ver, na_ver = nt["tag_name"].lstrip("v"), na["tag_name"].lstrip("v")

    nt_lines = "\n".join([
        f"> **[ZIP 받기]({nt_zip})** · {day(nt)}",
        "> 게임을 끄고 압축을 풀어 `Interface\\AddOns\\NiniTools` 폴더를 통째로 교체",
        "> 설정·기록(NiniToolsDB) 그대로 · WTF 폴더는 지우지 마세요",
        "> 지난 버전: [GitHub Releases](https://github.com/niniano/NiniTools/releases)",
        f"> 받은 횟수: 이번 버전 **{nt_now}회** · 전체 {nt_tot}회",
    ])
    na_lines = "\n".join([
        f"> **[설치 파일 받기]({na_setup})** · [설치 없이 쓰기 (ZIP)]({na_zip}) · {day(na)}",
        "> Windows 64비트 · 「Windows의 PC 보호」 창이 뜨면 「추가 정보 → 실행」",
        "> 새 버전은 새 설치 파일로 덮어 설치",
        "> 지난 버전: [GitHub Releases](https://github.com/niniano/NiniAnalyzer-BLUE/releases)",
        f"> 받은 횟수: 이번 버전 **{na_now}회** · 전체 {na_tot}회",
    ])
    na_title = f"NiniAnalyzer_Public {na_ver} · 레이드 로그 분석기" + (" (시험판)" if na.get("prerelease") else "")
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    embed = {
        "title": "NiniTools · NiniAnalyzer 다운로드",
        "description": "항상 최신 버전 링크 · 새 버전이 나오면 이 메시지가 바뀝니다",
        "color": 0xFEF77B,
        "fields": [
            {"name": f"NiniTools {nt_ver} · WoW 애드온", "value": nt_lines, "inline": False},
            {"name": na_title, "value": na_lines, "inline": False},
        ],
        "image": {"url": "attachment://nini_download_banner.png"},
        "thumbnail": {"url": "attachment://nini_icon_256.png"},
        "footer": {"text": f"마지막 갱신 {now} · 받은 횟수는 4시간마다 바뀝니다"},
    }
    for f in embed["fields"]:
        assert len(f["value"]) <= 1024, f["name"]
    summary = f"NiniTools {nt_ver} ({nt_now}/{nt_tot}) · NiniAnalyzer {na_ver} ({na_now}/{na_tot})"
    return embed, summary


def multipart(payload: dict, files):
    boundary = "----nini" + uuid.uuid4().hex
    out = bytearray()
    def part(headers: str, body: bytes):
        out.extend(f"--{boundary}\r\n{headers}\r\n\r\n".encode())
        out.extend(body)
        out.extend(b"\r\n")
    part('Content-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json',
         json.dumps(payload, ensure_ascii=False).encode("utf-8"))
    for i, (name, data) in enumerate(files):
        part(f'Content-Disposition: form-data; name="files[{i}]"; filename="{name}"\r\nContent-Type: image/png', data)
    out.extend(f"--{boundary}--\r\n".encode())
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def main() -> int:
    embed, summary = build_embed()
    print(summary)
    if os.environ.get("DRY_RUN") == "1":
        print(json.dumps(embed, ensure_ascii=False, indent=2))
        return 0
    hook = (os.environ.get("DISCORD_DOWNLOAD_WEBHOOK") or "").strip()
    msg = (os.environ.get("DOWNLOAD_MESSAGE_ID") or "").strip().rstrip("/").split("/")[-1]
    if not hook.startswith(("https://discord.com/api/webhooks/", "https://discordapp.com/api/webhooks/")):
        print("::error::Secret DISCORD_DOWNLOAD_WEBHOOK 이 비었거나 디스코드 웹훅 주소가 아닙니다.")
        return 1
    if not msg.isdigit():
        print("::error::Variable DOWNLOAD_MESSAGE_ID 에 고정 메시지 번호(또는 메시지 링크)를 넣어 주세요.")
        return 1
    base, _, query = hook.partition("?")
    url = f"{base}/messages/{msg}" + (f"?{query}" if query else "")
    files = [("nini_download_banner.png", (HERE / "nini_download_banner.png").read_bytes()),
             ("nini_icon_256.png", (HERE / "nini_icon_256.png").read_bytes())]
    payload = {"embeds": [embed], "allowed_mentions": {"parse": []},
               "attachments": [{"id": i, "filename": n} for i, (n, _) in enumerate(files)]}
    body, ctype = multipart(payload, files)
    req = urllib.request.Request(url, data=body, method="PATCH", headers={"Content-Type": ctype, "User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print("고침:", json.load(r).get("id"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        if e.code == 404:
            print("::error::메시지를 못 찾았습니다. 그 메시지를 올린 웹훅과 같은 웹훅이어야 고칠 수 있습니다 (메시지 번호 · 웹훅 확인).")
        print(f"::error::Discord HTTP {e.code}: {detail[:300]}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
