#!/usr/bin/env python3
"""App Store Connect 에 올릴 스크린샷 · 앱 미리보기를 올리기 전에 검사한다 (2026-10-30 · 업로드 거부 막기).

  python3 Tools/store/check-assets.py            # screenshots/store/upload 전체

스크린샷 (칸마다 App Store Connect 안내의 크기):
  - 받는 크기 중 하나 · 세로 · PNG 또는 JPEG
  - **RGB (알파 · 투명 칸 없음)** — 시뮬레이터 원본은 RGBA 다
  - 칸마다 1~10장
앱 미리보기 (ffprobe 가 있으면):
  - 받는 크기 (아이폰 886 × 1920 · 아이패드 1200 × 1600, 세로)
  - H.264 · 초당 30장 이하 · 15~30초 · 500MB 이하
  - 소리 칸이 있다 (AAC 스테레오 · 44.1 또는 48kHz) — 소리 칸이 없으면 올리기가 거부된다는 보고가 있어 무음 칸을 넣는다
틀린 것이 하나라도 있으면 1 로 끝난다.
"""

from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
UPLOAD = ROOT / "screenshots" / "store" / "upload"

SCREENSHOT_SIZES = {
    "iphone-6.9": {(1320, 2868), (1290, 2796)},
    "iphone-6.3": {(1206, 2622), (1179, 2556)},
    "ipad-13": {(2064, 2752), (2048, 2732)},
}
PREVIEW_SIZES = {
    "preview-iphone": (886, 1920),
    "preview-ipad": (1200, 1600),
}

problems: list[str] = []


def bad(message: str) -> None:
    problems.append(message)
    print(f"  ✗ {message}")


def check_screenshots() -> None:
    for folder, sizes in SCREENSHOT_SIZES.items():
        files = sorted((UPLOAD / folder).glob("*.png")) + sorted((UPLOAD / folder).glob("*.jpg"))
        print(f"{folder}: {len(files)}장")
        if not 1 <= len(files) <= 10:
            bad(f"{folder}: 1~10장이어야 한다 ({len(files)}장)")
        for path in files:
            with Image.open(path) as image:
                if image.size not in sizes:
                    bad(f"{path.name}: 크기 {image.size} — 받는 크기 {sorted(sizes)}")
                if image.mode != "RGB":
                    bad(f"{path.name}: {image.mode} — 알파 없는 RGB 여야 한다")
                if "transparency" in image.info:
                    bad(f"{path.name}: 투명색 정보가 있다")
            if path.stat().st_size > 10 * 1024 * 1024:
                bad(f"{path.name}: {path.stat().st_size} 바이트 — 너무 크다")
            print(f"  ✓ {path.name}")


def probe(path: pathlib.Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def check_previews() -> None:
    if shutil.which("ffprobe") is None:
        print("ffprobe 가 없어 앱 미리보기는 건너뜁니다")
        return
    for stem, (width, height) in PREVIEW_SIZES.items():
        files = sorted(UPLOAD.glob(f"{stem}*.mp4")) + sorted(UPLOAD.glob(f"{stem}*.mov"))
        print(f"{stem}: {len(files)}개")
        if len(files) > 3:
            bad(f"{stem}: 3개까지")
        for path in files:
            info = probe(path)
            video = [s for s in info["streams"] if s["codec_type"] == "video"]
            audio = [s for s in info["streams"] if s["codec_type"] == "audio"]
            duration = float(info["format"]["duration"])
            if len(video) != 1:
                bad(f"{path.name}: 영상 칸이 {len(video)}개")
                continue
            v = video[0]
            if (v["width"], v["height"]) != (width, height):
                bad(f"{path.name}: {v['width']} × {v['height']} — {width} × {height} 여야 한다")
            if v["codec_name"] != "h264":
                bad(f"{path.name}: {v['codec_name']} — H.264 여야 한다")
            if v.get("pix_fmt") != "yuv420p":
                bad(f"{path.name}: {v.get('pix_fmt')} — yuv420p 여야 한다")
            num, den = (int(x) for x in v["avg_frame_rate"].split("/"))
            fps = num / den if den else 0
            if fps > 30.01:
                bad(f"{path.name}: 초당 {fps:.2f}장 — 30 이하")
            if not 15 <= duration <= 30:
                bad(f"{path.name}: {duration:.2f}초 — 15~30초")
            if path.stat().st_size > 500 * 1024 * 1024:
                bad(f"{path.name}: 500MB 를 넘는다")
            if len(audio) != 1:
                bad(f"{path.name}: 소리 칸이 {len(audio)}개 — 1개(무음이라도)")
            else:
                a = audio[0]
                if a["codec_name"] != "aac" or int(a.get("channels", 0)) != 2 or a.get("sample_rate") not in ("44100", "48000"):
                    bad(f"{path.name}: 소리 {a['codec_name']} · {a.get('channels')}ch · {a.get('sample_rate')}Hz — AAC 스테레오 44.1/48kHz")
            print(f"  ✓ {path.name} — {v['width']}×{v['height']} · {fps:.0f}fps · {duration:.1f}초 · "
                  f"{path.stat().st_size // 1024}KB")


def main() -> int:
    if not UPLOAD.exists():
        print(f"::error::{UPLOAD} 가 없다")
        return 1
    check_screenshots()
    check_previews()
    if problems:
        print(f"::error::올리기 전에 고칠 것 {len(problems)}개")
        return 1
    print("✅ 스토어 자산 — 올릴 수 있습니다")
    return 0


if __name__ == "__main__":
    sys.exit(main())
