#!/usr/bin/env python3
"""두 스크린샷이 **같은 화면인가** — 다른 화면을 열라고 했는데 홈이 찍힌 것을 잡는다 (이슈 125).

CI 46-choices 가 선택지 화면이 아니라 홈으로 네 번 중 세 번 찍혔는데, 크기 · 빈 화면 검사를 모두 통과했다
(홈도 글이 가득하다). 그래서 홈(02-people)과 견준다.

재는 것: **글자 화소의 겹침** — 두 그림에서 바탕과 다른 화소(글자 · 그림)를 모아, 둘 다 글자인 곳 ÷ 어느 한쪽이라도 글자인 곳.
바뀐 화소 비율은 쓰지 않는다 — 바탕이 넓은 밝은 화면끼리는 다른 화면이어도 몇 % 밖에 안 달라 갈리지 않았다.
2026-11-25 저장소 스크린샷으로 잰 값: 들어간 화면(30 · 31 · 32 · 37 · 40 · 03) 0.02 ~ 0.04 · 홈이 찍힌 46 0.26 ~ 0.49
(날짜 글이 바뀌어도) · 같은 홈 갈래(05 검색 0.25 · 33 거르기 0.30 · 41 약속 0.67). 문턱 0.15.

  python3 Tools/ci/same-as.py 찍은.png 홈.png [문턱=0.15]
  끝 코드 0 = 같은 화면(홈이 찍혔다) · 1 = 다른 화면 · 2 = 견줄 수 없음(크기가 다름 · 파일 없음)
"""
from __future__ import annotations

import sys

try:
    from PIL import Image, ImageChops
except ImportError:  # pragma: no cover
    print("::warning::pillow 가 없습니다 — 홈 견주기를 건너뜁니다")
    sys.exit(1)

# 위 상태 바 · 아래 홈 표시줄은 어느 화면이나 같다 — 빼고 본다 (0~1 비율).
TOP, BOTTOM = 0.12, 0.88
# 바탕과 이만큼(0~255) 다르면 글자 · 그림으로 본다.
INK_DELTA = 40


def overlap(a_path: str, b_path: str) -> float | None:
    a = Image.open(a_path).convert("L")
    b = Image.open(b_path).convert("L")
    if a.size != b.size:
        return None
    w, h = a.size
    box = (0, int(h * TOP), w, int(h * BOTTOM))
    a, b = a.crop(box), b.crop(box)
    hist = a.histogram()
    ground = max(range(256), key=lambda v: hist[v])

    def ink(img):
        return img.point(lambda v: 255 if abs(v - ground) > INK_DELTA else 0)

    ia, ib = ink(a), ink(b)
    union = ImageChops.lighter(ia, ib).histogram()[255]
    both = ImageChops.darker(ia, ib).histogram()[255]
    return both / union if union else 1.0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    limit = float(argv[3]) if len(argv) > 3 else 0.15
    try:
        value = overlap(argv[1], argv[2])
    except OSError as error:
        print(f"견줄 수 없음: {error}")
        return 2
    if value is None:
        print("견줄 수 없음: 크기가 다르다")
        return 2
    same = value >= limit
    print(f"글자 겹침 {value:.2f} (문턱 {limit:.2f}) — {'같은 화면' if same else '다른 화면'}")
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
