#!/usr/bin/env python3
"""관계도 이름표 밀도 시뮬레이션 (이슈 73 · 2026-11-03 사용자) — 사람이 몇 명일 때부터 이름을 다 못 쓰는가.

앱과 같은 규칙으로 센다(숫자는 코드에서 옮겼다 — 바꾸면 여기도 고친다):
  · 자리 잡기 `Core.GraphLayout.layout` — k = 0.6·√(1/n), 끄는 힘 1.5, 당기는 힘 (min(1, 30/n))^0.75, 온도 0.08 → 0.002,
    반복 160(500명 넘으면 줄임), 0.02 ~ 0.98 안. 미는 힘은 사분 나무 대신 정확히 센다(차이 1% 안팎).
  · 화면에 펴기 `RelationGraphView.screenPoint` — 가장자리 36 · 34pt, 퍼진 거리로 칸을 채우되 한쪽 늘이기는 1.8배까지.
  · 이름표 `Core.LabelPlacement` — 점 반지름 5, 틈 2, 여덟 자리(아래 → 위 → 오른 → 왼 → 대각), 칸 밖 · 점 · 이름표 · 나 · 모임 이름과 안 겹치게.
    차례는 이름 순(여기서는 무작위 순서와 같다). 한 번에 150개.
  · 글자 11pt — 한글 한 자 폭 0.82em · 줄 높이 1.25em(아이패드 실기기 사진에서 잰 값). 이름은 2 ~ 4자(대부분 3자).
인맥은 지어낸 것이다 — 모임 4 ~ 13명이 여럿, 모임 안은 절반쯤 이어지고 모임 사이는 드문드문, 기록 없는 사람 5%.

  python3 Tools/label-density.py            # 표를 찍는다
"""
import math
import random
import sys

import numpy as np

FONT = 11.0
CHAR_W = 0.82 * FONT
LINE_H = 1.25 * FONT
RADIUS = 5.0
GAP = 2.0
EDGE_X, EDGE_Y, MAX_STRETCH = 36.0, 34.0, 1.8
LIMIT = 150
SCREENS = {
    "아이폰(관계도 칸 402×430)": (402.0, 430.0),
    "아이패드 가로(723×463)": (723.0, 463.0),
    "아이패드 세로(810×700)": (810.0, 700.0),
}


def make_network(n, rng):
    """모임 여럿 + 모임 사이 몇 줄 + 외톨이 몇. 반환: 링크 [(i, j, weight)], 모임 [[i...]]."""
    people = list(range(n))
    rng.shuffle(people)
    groups, k = [], 0
    alone = max(1, round(n * 0.05))
    while k < n - alone:
        size = min(rng.randint(4, 13), n - alone - k)
        groups.append(people[k:k + size])
        k += size
    links = {}
    for g in groups:
        for a in range(len(g)):
            for b in range(a + 1, len(g)):
                if rng.random() < 0.5:
                    links[(g[a], g[b])] = rng.randint(1, 4)
    for _ in range(max(1, len(groups) * 2)):
        g1, g2 = rng.sample(groups, 2) if len(groups) > 1 else (groups[0], groups[0])
        a, b = rng.choice(g1), rng.choice(g2)
        if a != b:
            links[(min(a, b), max(a, b))] = 1
    return [(a, b, 1 + math.log(1 + w)) for (a, b), w in links.items()], [g for g in groups if len(g) >= 4]


def layout(n_people, links):
    """`GraphLayout.layout` — 사람 n + 나(가운데 고정)."""
    n = n_people + 1
    center = n_people
    golden = 2.399963229728653
    idx = np.arange(n)
    r = 0.45 * np.sqrt((idx + 0.5) / n)
    pos = np.stack([0.5 + r * np.cos(idx * golden), 0.5 + r * np.sin(idx * golden)], axis=1)
    pos[center] = (0.5, 0.5)
    k = math.sqrt(1.0 / n) * 0.6
    k2 = k * k
    attraction = min(1, 30.0 / n) ** 0.75
    rounds = 160 if n <= 500 else max(25, 160 * 500 // n)
    li = np.array([a for a, _, _ in links], dtype=int)
    lj = np.array([b for _, b, _ in links], dtype=int)
    lw = np.array([w for _, _, w in links])
    for it in range(rounds):
        temp = 0.08 * (1 - it / rounds) + 0.002
        d = pos[:, None, :] - pos[None, :, :]
        dist = np.sqrt((d ** 2).sum(-1))
        np.fill_diagonal(dist, np.inf)
        dist = np.maximum(dist, 1e-4)
        force = k2 / dist
        disp = (d / dist[..., None] * force[..., None]).sum(1)
        if len(li):
            dd = pos[li] - pos[lj]
            dl = np.maximum(np.sqrt((dd ** 2).sum(-1)), 1e-4)
            f = (dl * dl / k * lw * attraction)[:, None] * dd / dl[:, None]
            np.add.at(disp, li, -f)
            np.add.at(disp, lj, f)
        disp -= (pos - 0.5) * 1.5
        length = np.sqrt((disp ** 2).sum(-1))
        step = np.minimum(length, temp)
        move = np.where(length[:, None] > 0, disp / np.maximum(length, 1e-12)[:, None] * step[:, None], 0)
        move[center] = 0
        pos = np.clip(pos + move, 0.02, 0.98)
    return pos


def to_screen(pos, w, h, scale=1.0):
    reach_x = max(0.05, np.abs(pos[:, 0] - 0.5).max())
    reach_y = max(0.05, np.abs(pos[:, 1] - 0.5).max())
    ux = max(w / 2 - EDGE_X, 20) / reach_x
    uy = max(h / 2 - EDGE_Y, 20) / reach_y
    even = min(ux, uy)
    ux, uy = min(ux, even * MAX_STRETCH), min(uy, even * MAX_STRETCH)
    return np.stack([w / 2 + (pos[:, 0] - 0.5) * ux * scale, h / 2 + (pos[:, 1] - 0.5) * uy * scale], axis=1)


def overlaps(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def place(requests, obstacles, bounds):
    """`LabelPlacement.place` — 격자 대신 전부 견준다(결과는 같다)."""
    taken = list(obstacles)
    placed = 0
    for ax, ay, w, h in requests:
        reach = RADIUS + GAP
        centers = [(ax, ay + reach + h / 2), (ax, ay - reach - h / 2), (ax + reach + w / 2, ay), (ax - reach - w / 2, ay),
                   (ax + reach + w / 2, ay + reach + h / 2), (ax - reach - w / 2, ay + reach + h / 2),
                   (ax + reach + w / 2, ay - reach - h / 2), (ax - reach - w / 2, ay - reach - h / 2)]
        for cx, cy in centers:
            box = (cx - w / 2, cy - h / 2, w, h)
            if not (box[0] >= bounds[0] and box[1] >= bounds[1] and box[0] + w <= bounds[2] and box[1] + h <= bounds[3]):
                continue
            padded = (box[0] - GAP / 2, box[1] - GAP / 2, w + GAP, h + GAP)
            if any(overlaps(padded, o) for o in taken):
                continue
            taken.append(box)
            placed += 1
            break
    return placed


def name_length(rng):
    return rng.choices([2, 3, 4], weights=[5, 88, 7])[0]


def measure(n, w, h, seed, scale=1.0):
    rng = random.Random(seed)
    links, groups = make_network(n, rng)
    pos = layout(n, links)
    pts = to_screen(pos, w, h, scale)
    visible = [i for i in range(n) if -20 < pts[i, 0] < w + 20 and -20 < pts[i, 1] < h + 20]
    me = pts[n]
    obstacles = [(pts[i, 0] - RADIUS, pts[i, 1] - RADIUS, 2 * RADIUS, 2 * RADIUS) for i in visible]
    obstacles.append((me[0] - 12, me[1] - 12, 24, 24))
    obstacles.append((me[0] - 18, me[1] + 22 - LINE_H / 2, 36, LINE_H))          # 나의 이름
    for g in groups:                                                              # 모임 이름(맨 위 점 20pt 위 · 5자쯤)
        top = min(g, key=lambda i: pts[i, 1])
        cx = float(np.mean(pts[g, 0]))
        obstacles.append((cx - 2.5 * CHAR_W, pts[top, 1] - 20 - LINE_H / 2, 5 * CHAR_W, LINE_H))
    order = visible[:]
    rng.shuffle(order)                                                            # 이름 순 = 자리와 상관없는 차례
    order = order[:LIMIT]
    reqs = [(pts[i, 0], pts[i, 1], name_length(rng) * CHAR_W, LINE_H) for i in order]
    placed = place(reqs, obstacles, (0, 0, w, h))
    return placed, len(visible)


def main():
    sizes = [20, 30, 40, 50, 60, 80, 100, 120, 150, 200, 300]
    seeds = range(5)
    for title, (w, h) in SCREENS.items():
        print(f"\n## {title} — 11pt · 처음 크기(1배) / 2배로 키웠을 때")
        print("| 사람 | 이름 쓴 비율(1배) | 못 쓴 이름(1배) | 2배일 때 보이는 사람 중 이름 쓴 비율 |")
        print("|---:|---:|---:|---:|")
        for n in sizes:
            ratios, missing, zoom = [], [], []
            for s in seeds:
                placed, vis = measure(n, w, h, 1000 * n + s)
                ratios.append(placed / max(vis, 1))
                missing.append(vis - placed)
                p2, v2 = measure(n, w, h, 1000 * n + s, scale=2.0)
                zoom.append(p2 / max(v2, 1))
            print(f"| {n} | {np.mean(ratios) * 100:.0f}% | {np.mean(missing):.1f}명 | {np.mean(zoom) * 100:.0f}% |")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
