#!/usr/bin/env python3
"""글자 색이 바탕과 4.5:1 을 넘는지 센다 (요구사항 8.6 · 이슈 4). 느린 여백의 `Tools/contrast.py` 를 본떴다.

    python3 Tools/contrast.py

`App/DesignSystem/Palette.swift` 의 `Color(light: 0x…, dark: 0x…)` 토큰을 읽어 글자 토큰 × 바탕 토큰의
대비를 라이트 · 다크에서 각각 잰다. 시스템 바탕(`systemGroupedBackground` 등)은 iOS 기본값을 적어 둔다.
`faint` 는 장식용이라 안 센다. 하나라도 못 미치면 1 로 끝난다 — core-test.yml 이 돌린다.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PALETTE = ROOT / "App" / "DesignSystem" / "Palette.swift"
MINIMUM = 4.5

# iOS 시스템 색 (라이트, 다크) — 코드에는 이름만 있어 값을 여기 적는다.
SYSTEM = {
    "ground": (0xF2F2F7, 0x000000),   # systemGroupedBackground
    "raised": (0xFFFFFF, 0x1C1C1E),   # secondarySystemGroupedBackground
}

# (글자 토큰, 바탕 토큰) — 실제로 그렇게 쓰는 짝만.
PAIRS = [
    ("ink", "raised"), ("ink", "ground"),
    ("bodyText", "raised"), ("bodyText", "ground"),
    ("muted", "raised"), ("muted", "ground"),
    ("accent", "raised"), ("accent", "ground"), ("accent", "accentSoft"),
    ("chipInk", "chip"),
    ("danger", "raised"),
]


def luminance(hex_value: int) -> float:
    def channel(v: int) -> float:
        c = v / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (hex_value >> 16) & 0xFF, (hex_value >> 8) & 0xFF, hex_value & 0xFF
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(a: int, b: int) -> float:
    la, lb = luminance(a), luminance(b)
    light, dark = max(la, lb), min(la, lb)
    return (light + 0.05) / (dark + 0.05)


def read_tokens() -> dict[str, tuple[int, int]]:
    text = PALETTE.read_text(encoding="utf-8")
    tokens = dict(SYSTEM)
    for name, light, dark in re.findall(r"static let (\w+) = Color\(light: 0x([0-9A-Fa-f]{6}), dark: 0x([0-9A-Fa-f]{6})\)", text):
        tokens[name] = (int(light, 16), int(dark, 16))
    return tokens


def main() -> int:
    tokens = read_tokens()
    failed = False
    for fg, bg in PAIRS:
        if fg not in tokens or bg not in tokens:
            print(f"::error::토큰을 못 찾았습니다: {fg} 또는 {bg}")
            failed = True
            continue
        for mode, index in (("라이트", 0), ("다크", 1)):
            ratio = contrast(tokens[fg][index], tokens[bg][index])
            mark = "OK " if ratio >= MINIMUM else "낮음"
            print(f"{mark} {mode} {fg} on {bg}: {ratio:.2f}")
            if ratio < MINIMUM:
                failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
