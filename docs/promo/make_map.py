#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 2 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 내 인맥을 지도로.

첫 쇼츠(make_short.py)의 그리기 도구를 그대로 쓴다. 앱 화면은 CI 스크린샷(모두 지어낸 견본 · 1.0 에 있는 화면만).
  python3 make_map.py <repo> <out.mp4>
"""
import math
import pathlib
import random
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
REPO = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
import make_short as ms  # noqa: E402  (같은 인자를 읽는다)
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
SHOTS = REPO / "screenshots"

# ── 그려지는 인맥 (어두운 바탕) ─────────────────────────────────────────────
# 가운데 나, 둘레에 모임 셋. 점이 하나씩 나타나고 선이 이어진다. 모두 지어낸 그림이다.
rng = random.Random(20261103)
CENTER = (540, 1180)
CLUSTERS = [((300, 960), 6), ((800, 930), 5), ((560, 1520), 7)]
NODES = [CENTER]
GROUP = [-1]
for gi, ((cx, cy), n) in enumerate(CLUSTERS):
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.3, 0.3)
        r = rng.uniform(70, 150)
        NODES.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        GROUP.append(gi)
EDGES = []
for i in range(1, len(NODES)):
    for j in range(i + 1, len(NODES)):
        if GROUP[i] == GROUP[j] and rng.random() < 0.55:
            EDGES.append((i, j))
for gi in range(3):
    members = [i for i in range(1, len(NODES)) if GROUP[i] == gi]
    EDGES.append((0, members[0]))
    EDGES.append((0, members[2]))
EDGES.append((3, 9))
EDGES.append((12, 17))
# 나타나는 차례 — 가운데에서 가까운 점부터.
ORDER = sorted(range(1, len(NODES)), key=lambda i: math.dist(NODES[i], CENTER))
APPEAR = {0: 0.0}
for k, i in enumerate(ORDER):
    APPEAR[i] = 0.25 + k * 0.09
SS = 2  # 선을 매끄럽게 — 두 배로 그려 줄인다


def network_layer(t, glow=0.0):
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, j in EDGES:
        start = max(APPEAR[i], APPEAR[j]) + 0.15
        a = ease((t - start) / 0.5)
        if a <= 0:
            continue
        (x1, y1), (x2, y2) = NODES[i], NODES[j]
        xe, ye = x1 + (x2 - x1) * a, y1 + (y2 - y1) * a
        d.line([(x1 * SS, y1 * SS), (xe * SS, ye * SS)], fill=ACCENT_SOFT + (110,), width=3 * SS)
    # 모임 테두리 — 두 번째 장면에서 은은하게.
    if glow > 0:
        for gi, ((cx, cy), _) in enumerate(CLUSTERS):
            r = 200
            d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
                      fill=ACCENT_SOFT + (round(28 * glow),), outline=ACCENT_SOFT + (round(120 * glow),), width=2 * SS)
    for i, (x, y) in enumerate(NODES):
        a = ease((t - APPEAR[i]) / 0.3)
        if a <= 0:
            continue
        r = (22 if i == 0 else 12) * (0.6 + 0.4 * a)
        color = WHITE if i == 0 else ACCENT_SOFT
        d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=color + (round(255 * a),))
    return layer.resize((W, H), Image.LANCZOS)


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    c.alpha_composite(network_layer(t + 0.0))
    text(c, "내 인맥,", 260, 112, WHITE, t, 0.1)
    text(c, "한 장으로 본 적 있나요?", 410, 84, ACCENT_SOFT, t, 0.6)
    return c


def s_meaning(t):
    c = DARK_BG.convert("RGBA")
    c.alpha_composite(network_layer(t + 3.05, glow=ease((t - 1.0) / 0.8)))
    text(c, "점 하나는 한 사람,", 260, 84, WHITE, t, 0.1)
    text(c, "선은 함께한 시간", 390, 84, ACCENT_SOFT, t, 0.6)
    text(c, "자주 함께하면 하나의 모임으로", 540, 46, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "기록이 쌓이면\n내 인맥이 그려집니다", 1040, 64, ACCENT, t, 0.8, path=MED)
    return c


def phone_still(path, caption, zoom_to=1.05):
    shot = Image.open(path).convert("RGB")

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        ms.PHONE.place(c, shot, alpha=ease(t / 0.3), zoom=1.0 + (zoom_to - 1.0) * ease(t / 3.8))
        return c
    return frame


def graph_closeup(path, caption):
    """관계도 부분만 크게 — 카드처럼 띄워 천천히 당긴다."""
    shot = Image.open(path).convert("RGB")
    w, h = shot.size
    crop = shot.crop((0, round(h * 0.325), w, round(h * 0.615)))   # 관계도 그림 칸 (위 칩 · 스위치와 아래 시점 막대는 빼고)
    card_w = 980
    base = crop.resize((card_w, round(crop.height * card_w / crop.width)), Image.LANCZOS)
    radius = 40
    mask = ms.rounded_mask(base.size, radius)

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        z = 1.0 + 0.12 * ease(t / 3.8)
        cw, ch = base.width / z, base.height / z
        x0 = (base.width - cw) * 0.45
        y0 = (base.height - ch) * 0.5
        img = base.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch))).resize(base.size, Image.LANCZOS).convert("RGBA")
        a = ease(t / 0.35)
        img.putalpha(mask.point(lambda v: round(v * a)))
        x = (W - base.width) // 2
        y = 520
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((x, y + 24, x + base.width, y + base.height + 24), radius=radius,
                                             fill=(20, 24, 29, round(60 * a)))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(img, (x, y))
        return c
    return frame


class Tablet(ms.Phone):
    """아이패드 화면 — 세로 3 : 4."""

    def __init__(self, width=900, y=470):
        self.w = width
        self.h = round(width * 2752 / 2064)
        self.x = (W - width) // 2
        self.y = y
        self.r = 46
        self.mask = ms.rounded_mask((self.w, self.h), self.r)
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((self.x, self.y + 22, self.x + self.w, self.y + self.h + 22),
                                             radius=self.r, fill=(20, 24, 29, 70))
        self.shadow = sh.filter(ImageFilter.GaussianBlur(30))
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle((self.x, self.y, self.x + self.w - 1, self.y + self.h - 1),
                                               radius=self.r, outline=ms.RULE + (255,), width=3)
        self.ring = ring


TABLET = Tablet()


def tablet_still(path, caption):
    shot = Image.open(path).convert("RGB")

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        TABLET.place(c, shot, alpha=ease(t / 0.3), zoom=1.0)
        return c
    return frame


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "점수도 순위도 없이\n내 인연을 천천히", 300, 84, INK, t, 0.1)
    ms.icon_at(c, 220, 760, ease((t - 0.6) / 0.5), scale=0.9 + 0.1 * ease((t - 0.6) / 0.6))
    text(c, "느린 인연", 900, 100, INK, t, 0.8)
    a = ease((t - 1.3) / 0.45)
    if a > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = font(BOLD, 46)
        chips = ["무료", "회원가입 없음", "광고 없음"]
        widths = [d.textlength(s, font=f) + 70 for s in chips]
        x = (W - (sum(widths) + 24 * (len(chips) - 1))) / 2
        y = 1060 + (1 - a) * 30
        for s, w in zip(chips, widths):
            d.rounded_rectangle((x, y, x + w, y + 92), radius=46, fill=ACCENT + (round(255 * a),))
            d.text((x + w / 2, y + 46), s, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
            x += w + 24
        c.alpha_composite(layer)
    text(c, "App Store 에서\n느린 인연 검색", 1220, 72, ACCENT, t, 1.9)
    return c


def scenes():
    return [
        (3.4, s_hook),
        (3.6, s_meaning),
        (2.6, s_reveal),
        (4.2, phone_still(SHOTS / "store/raw/iphone/04-network-graph.png", "함께 기록한 사람끼리\n선으로 이어지고")),
        (4.0, graph_closeup(SHOTS / "store/raw/iphone/04-network-graph.png", "자주 함께하는 사람은\n모임으로 묶여요")),
        (4.0, phone_still(SHOTS / "store/raw/iphone/05-timeline.png", "해마다 모임이\n어떻게 달라졌는지")),
        (3.8, phone_still(SHOTS / "23-network-changes.png", "새로 생긴 모임,\n줄어든 모임까지")),
        (3.6, tablet_still(SHOTS / "store/raw/ipad/02-graph-card.png", "아이패드에선 점을 누르면\n그 사람의 요약이")),
        (5.0, s_end),
    ]


def main():
    sc = scenes()
    total = sum(d for d, _ in sc) - XF * (len(sc) - 1)
    n = round(total * FPS)
    starts, acc = [], 0.0
    for d, _ in sc:
        starts.append(acc)
        acc += d - XF
    enc = subprocess.Popen([
        "ffmpeg", "-v", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-map", "0:v", "-map", "1:a", "-shortest",
        "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(OUT)], stdin=subprocess.PIPE)
    for k in range(n):
        t = k / FPS
        live = [(i, t - s) for i, s in enumerate(starts) if 0 <= t - s < sc[i][0]]
        i, lt = live[-1]
        img = sc[i][1](lt).convert("RGB")
        if len(live) > 1:
            j, jt = live[-2]
            img = Image.blend(sc[j][1](jt).convert("RGB"), img, ease(lt / XF))
        enc.stdin.write(img.tobytes())
    enc.stdin.close()
    enc.wait()
    print(f"{OUT} — {total:.1f}초 · {n}장")


if __name__ == "__main__":
    main()
