#!/usr/bin/env python3
"""앱 아이콘을 그린다 — 글자 없이, 큰 색 덩어리로.

    python3 Tools/draw-icon.py

두 사람(두 원)이 느리게 겹쳐 가는 모양. 겹친 자리가 **인연**이다.
결과는 `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (1024×1024 · 알파 없음 — 알파가 있으면
App Store 가 반려한다). 모서리는 깎지 않는다 — iOS 가 알아서 깎는다.

글자를 넣지 않는 이유: 홈 화면에서 60pt 로 그려지면 한글은 읽히지 않고, 아이콘에 글자를 박아 두면
이름을 바꿀 때 서체가 필요하다 (느린 부자 교훈). 바꾸고 싶으면 이 스크립트를 고치고 다시 돌린다.

의존성: Pillow
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path("App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
SIZE = 1024
SCALE = 4  # 크게 그려 줄이면 가장자리가 부드럽다

BACKGROUND = (243, 239, 230)   # 종이색
LEFT = (47, 107, 94)           # 청록 — 앱의 강조색과 같다 (Palette.accent light)
RIGHT = (154, 99, 79)          # 따뜻한 갈색
OVERLAP = (232, 199, 120)      # 겹친 자리 — 인연


def main() -> None:
    big = SIZE * SCALE
    image = Image.new("RGB", (big, big), BACKGROUND)
    draw = ImageDraw.Draw(image, "RGBA")

    radius = int(big * 0.27)
    cy = int(big * 0.52)
    lx = int(big * 0.40)
    rx = int(big * 0.60)

    # 두 원. 겹친 자리는 반투명을 쌓지 않고 세 번째 색으로 또렷하게 칠한다.
    left = Image.new("L", (big, big), 0)
    right = Image.new("L", (big, big), 0)
    ImageDraw.Draw(left).ellipse((lx - radius, cy - radius, lx + radius, cy + radius), fill=255)
    ImageDraw.Draw(right).ellipse((rx - radius, cy - radius, rx + radius, cy + radius), fill=255)
    overlap = Image.composite(right, Image.new("L", (big, big), 0), left)

    image.paste(LEFT, mask=left)
    image.paste(RIGHT, mask=right)
    image.paste(OVERLAP, mask=overlap)

    # 아래쪽에 느린 시간의 가는 선 하나 — 시리즈의 공통 무늬.
    line_y = int(big * 0.86)
    draw.line((int(big * 0.22), line_y, int(big * 0.78), line_y), fill=(120, 112, 100, 255), width=int(big * 0.012))

    small = image.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    small.convert("RGB").save(OUT, optimize=True)
    print(f"{OUT} — {small.size}, mode {small.mode}")


if __name__ == "__main__":
    main()
