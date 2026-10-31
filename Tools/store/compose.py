#!/usr/bin/env python3
"""App Store 스크린샷 합성 — 위에 한 줄 설명, 아래에 앱 화면 (2026-10-30 사용자 결정).

CI 가 찍은 원본(`screenshots/store/raw/<기기>/NN-이름.png`)을 받아, App Store Connect 칸마다 받는 크기로
`screenshots/store/upload/<칸>/NN-이름.png` 를 만든다. **알파(투명) 칸 없는 RGB PNG** 로 쓴다 —
시뮬레이터 스크린샷은 RGBA 라 그대로 올리면 거부될 수 있다.

  python3 Tools/store/compose.py                    # CI (macOS — Apple SD Gothic Neo)
  python3 Tools/store/compose.py --font /path.ttc   # 다른 글꼴로 미리 보기

칸 (App Store Connect 의 안내 그대로):
  iphone-6.9  1320 × 2868   (6.9형 — 필수 칸. 원본: Pro Max 시뮬레이터)
  iphone-6.3  1206 × 2622   (15.5cm · 15.9cm — 같은 원본을 줄인다. 가로세로 비가 거의 같다)
  ipad-13     2064 × 2752   (32.8cm · 33.0cm — 필수 칸. 원본: iPad Pro 13 시뮬레이터)

사람은 모두 지어낸 견본이다 (CLAUDE.md §2). 설명 글에 곧은 큰따옴표를 쓰지 않는다.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "screenshots" / "store" / "raw"
OUT = ROOT / "screenshots" / "store" / "upload"

# 원본 기기 → 만들 칸들 (이름, 가로, 세로)
TARGETS = {
    "iphone": [("iphone-6.9", 1320, 2868), ("iphone-6.3", 1206, 2622)],
    "ipad": [("ipad-13", 2064, 2752)],
}

# 파일 이름의 뒷부분 → 설명 (두 줄까지). 원본에 없는 것은 건너뛴다.
CAPTIONS = {
    "people": "연락처가 아니라\n인연을 기록합니다",
    "person-detail": "어떻게 알게 되었고\n무엇을 함께했는지",
    "add-record": "만난 날 바로\n짧게 남겨 두세요",
    "network-graph": "내 인맥이\n관계도로 보입니다",
    "graph-card": "점을 누르면\n그 사람의 요약이",
    "timeline": "해마다 달라진\n모임을 돌아봅니다",
    "overview": "한동안 못 본 사람을\n잊지 않게",
}

# 색 — 앱의 Palette 밝은 값 (accentSoft · ink · rule).
BACKGROUND_TOP = (228, 240, 236)
BACKGROUND_BOTTOM = (244, 247, 246)
INK = (20, 24, 29)
RULE = (214, 222, 219)

MAC_FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def bold_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    """.ttc 안에서 굵은 얼굴을 찾는다 (Bold → SemiBold → ExtraBold → 첫 얼굴)."""
    faces = {}
    for index in range(32):
        try:
            face = ImageFont.truetype(path, size, index=index)
        except (OSError, ValueError):
            break
        faces.setdefault(face.getname()[1], index)
    for style in ("Bold", "SemiBold", "ExtraBold", "Heavy"):
        if style in faces:
            return ImageFont.truetype(path, size, index=faces[style])
    return ImageFont.truetype(path, size, index=0)


def gradient(width: int, height: int) -> Image.Image:
    top = Image.new("RGB", (1, 2))
    top.putpixel((0, 0), BACKGROUND_TOP)
    top.putpixel((0, 1), BACKGROUND_BOTTOM)
    return top.resize((width, height), Image.BILINEAR)


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(raw: Image.Image, caption: str, width: int, height: int, font_path: str, tablet: bool) -> Image.Image:
    canvas = gradient(width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # 설명 — 위 칸 가운데. 글자 크기는 칸 너비를 따른다.
    size = round(width * (0.046 if tablet else 0.068))
    font = bold_font(font_path, size)
    spacing = round(size * 0.28)
    box = draw.multiline_textbbox((0, 0), caption, font=font, spacing=spacing, align="center")
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    top = round(height * (0.055 if tablet else 0.06))
    draw.multiline_text(((width - text_w) / 2 - box[0], top - box[1]), caption, font=font, fill=INK,
                        spacing=spacing, align="center")

    # 앱 화면 — 설명 아래, 둥근 모서리 · 옅은 그림자. 아래는 칸 밖으로 조금 넘쳐도 된다(스토어에서 흔한 꼴).
    shot_w = round(width * (0.80 if tablet else 0.82))
    shot_h = round(raw.height * shot_w / raw.width)
    shot = raw.convert("RGB").resize((shot_w, shot_h), Image.LANCZOS)
    radius = round(shot_w * (0.035 if tablet else 0.075))
    shot = rounded(shot, radius)
    x = (width - shot_w) // 2
    y = top + text_h + round(height * 0.045)

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 18, x + shot_w, y + shot_h + 18), radius=radius,
                                             fill=(20, 24, 29, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(shot, (x, y))
    ImageDraw.Draw(canvas).rounded_rectangle((x, y, x + shot_w - 1, y + shot_h - 1), radius=radius,
                                             outline=RULE, width=2)
    # **알파 없는 RGB 로** — App Store Connect 는 투명 칸이 있는 이미지를 거부할 수 있다.
    return canvas.convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--font", default=MAC_FONT)
    args = parser.parse_args()
    if not pathlib.Path(args.font).exists():
        print(f"::error::글꼴이 없습니다: {args.font}")
        return 1

    made = 0
    for device, targets in TARGETS.items():
        sources = sorted((RAW / device).glob("*.png"))
        if not sources:
            print(f"::warning::원본이 없습니다: {RAW / device}")
            continue
        for name, width, height in targets:
            folder = OUT / name
            folder.mkdir(parents=True, exist_ok=True)
            for old in folder.glob("*.png"):
                old.unlink()
            for source in sources:
                key = source.stem.split("-", 1)[1] if "-" in source.stem else source.stem
                caption = CAPTIONS.get(key)
                if caption is None:
                    print(f"::warning::설명이 없는 원본은 건너뜁니다: {source.name}")
                    continue
                with Image.open(source) as raw:
                    image = compose(raw, caption, width, height, args.font, tablet=device == "ipad")
                target = folder / source.name
                image.save(target, "PNG", optimize=True)
                made += 1
                print(f"만듦: {target.relative_to(ROOT)} {image.size} {image.mode}")
    if made == 0:
        print("::error::만든 이미지가 없습니다")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
