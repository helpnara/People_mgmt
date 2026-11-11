#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 7 (1080 × 1920 · 30fps · 약 30초) — 컨셉: 홈 화면에서 만나는 인연 (2026-11-07 · 1.1.9 위젯).

앞 쇼츠들(make_short.py · make_record.py · make_day.py)의 그리기 도구를 쓴다. 기록 화면은 **지금 브랜치의 CI 스크린샷**
(`48-briefing.png` · 견본 정유진의 커피 약속 · 만나기 전에 / `50-repeat-detail.png` · 견본 김하늘의 저녁 산책 · 매주 반복)이다.
위젯 · 잠금 화면 위젯은 CI 스크린샷이 없어 **위젯 코드(`Widget/SlowConnectionWidget.swift`)의 배치와 문구 그대로** 그린다 —
얼굴(사진이 없으면 첫 글자) · `D-3` 큰 글씨(색은 이것 하나) · 제목 · `3일 후 오전 10:00 · 정유진` · 알약 둘 · 오른쪽 위 잎 하나,
잠금 화면은 동그란 것(D-day + 그림) · 네모난 것(D-day · 시각 / 제목 / 사람) · 글 한 줄. 날 · 시각은 견본 예정 자료(`SampleData.seedPlanned`)
와 같다(커피 약속 3일 뒤 오전 10시 · 점심 약속 3일 뒤 12:30 · 저녁 산책 5일 뒤). 사람은 모두 지어낸 견본이다.
  python3 make_widget.py <repo> <out.mp4>          영상
  python3 make_widget.py <repo> <out.png> <초>     그 초의 한 장
"""
import math
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
REPO = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
import make_short as ms  # noqa: E402  (같은 인자를 읽는다)
import make_record as mr  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
CARD = (255, 255, 255)
PALE = (228, 240, 236)        # Palette.accentSoft (라이트)
MUTED = (95, 107, 118)        # Palette.muted
FAINT = (152, 163, 172)       # Palette.faint
CHIP = (237, 241, 243)        # Palette.chip
ORANGE_INK = (157, 85, 11)    # Palette.clusterOrangeInk — 생일
ORANGE_SOFT = (251, 236, 222)


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def wallpaper(top, bottom):
    """홈 · 잠금 화면 바탕 — 위아래 그러데이션 위에 큰 빛 둘."""
    g = ms.gradient(top, bottom).convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((-260, 120, 760, 1140), fill=(124, 196, 178, 70))
    d.ellipse((420, 1000, 1400, 1980), fill=(178, 150, 220, 60))
    g.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    return g


HOME_BG = wallpaper((38, 52, 60), (70, 62, 96))
LOCK_BG = wallpaper((22, 30, 36), (52, 46, 74))


def shadow_box(c, box, radius, a, strength=70, blur=30, dy=20):
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + dy, x1, y1 + dy), radius=radius, fill=(10, 12, 16, round(strength * a)))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))


def leaf(d, cx, cy, s, color):
    """잎 하나 (SF Symbols `leaf.fill` 비슷하게) — 오른쪽 위 앱 표시."""
    pts = []
    for k in range(41):
        u = k / 40
        ang = math.pi * u
        pts.append((cx - s * 0.5 + s * u, cy - math.sin(ang) * s * 0.42 + (u - 0.5) * s * 0.35))
    for k in range(41):
        u = 1 - k / 40
        ang = math.pi * u
        pts.append((cx - s * 0.5 + s * u, cy + math.sin(ang) * s * 0.18 + (u - 0.5) * s * 0.35))
    d.polygon(pts, fill=color)


def face(layer, cx, cy, r, initial, ink, soft, a, ring=CARD):
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - r - 5, cy - r - 5, cx + r + 5, cy + r + 5), fill=ring + (round(255 * a),))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=soft + (round(255 * a),))
    d.text((cx, cy + 2), initial, font=font(BOLD, round(r * 0.82)), fill=ink + (round(255 * a),), anchor="mm")


# ── 위젯 (중간 크기) — 코드의 배치 그대로 ─────────────────────────────────────
HERO = dict(dday="D-3", title="커피 약속", detail="3일 후 오전 10:00 · 정유진", initial="정")
PILLS = [("D-3 점심 약속", ACCENT, PALE), ("D-5 저녁 산책", ACCENT, PALE)]


def widget(scale=1.0, a=1.0, glow=0.0):
    """중간 위젯 한 장(RGBA). 기준 크기 900 × 422 — 실제 위젯(338 × 158pt)의 비율."""
    w, h = round(900 * scale), round(422 * scale)
    s = scale
    layer = Image.new("RGBA", (w + 80, h + 80), (0, 0, 0, 0))
    ox, oy = 40, 40
    d = ImageDraw.Draw(layer)
    r = round(64 * s)
    d.rounded_rectangle((ox, oy, ox + w, oy + h), radius=r, fill=CARD + (round(255 * a),))
    if glow > 0:
        d.rounded_rectangle((ox - 6, oy - 6, ox + w + 6, oy + h + 6), radius=r + 6,
                            outline=ACCENT_SOFT + (round(200 * glow * a),), width=round(6 * s))
    pad = 44 * s
    # 잎 하나 — 글자는 두지 않는다
    leaf(d, ox + w - pad - 10 * s, oy + pad + 4 * s, 34 * s, FAINT + (round(255 * a),))
    # 얼굴 (52pt → 140)
    fr = 70 * s
    fcx, fcy = ox + pad + fr + 5 * s, oy + pad + 30 * s + fr
    face(layer, fcx, fcy, fr, HERO["initial"], ACCENT, PALE, a)
    d = ImageDraw.Draw(layer)
    tx = fcx + fr + 40 * s
    d.text((tx, oy + pad + 4 * s), HERO["dday"], font=font(BOLD, round(84 * s)), fill=ACCENT + (round(255 * a),), anchor="lt")
    d.text((tx, oy + pad + 112 * s), HERO["title"], font=font(BOLD, round(44 * s)), fill=INK + (round(255 * a),), anchor="lt")
    d.text((tx, oy + pad + 172 * s), HERO["detail"], font=font(MED, round(32 * s)), fill=MUTED + (round(255 * a),), anchor="lt")
    # 알약 둘 — 맨 아래
    px, py = ox + pad, oy + h - pad - 64 * s
    f = font(MED, round(31 * s))
    for label, ink, soft in PILLS:
        tw = d.textlength(label, font=f) + 52 * s
        d.rounded_rectangle((px, py, px + tw, py + 64 * s), radius=32 * s, fill=soft + (round(255 * a),))
        d.text((px + tw / 2, py + 32 * s), label, font=f, fill=ink + (round(255 * a),), anchor="mm")
        px += tw + 18 * s
    return layer


def app_grid(c, rows, top, a, skip=()):
    """홈 화면의 다른 앱 칸 — 이름 없는 흐린 유리 네모(다른 앱 이름 · 상표를 쓰지 않는다)."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    size, gap = 176, 64
    x0 = (W - (4 * size + 3 * gap)) / 2
    for r in range(rows):
        for k in range(4):
            if (r, k) in skip:
                continue
            x, y = x0 + k * (size + gap), top + r * (size + 90)
            d.rounded_rectangle((x, y, x + size, y + size), radius=44, fill=(255, 255, 255, round(38 * a)))
            d.rounded_rectangle((x + 44, y + size + 22, x + size - 44, y + size + 36), radius=7, fill=(255, 255, 255, round(40 * a)))
    c.alpha_composite(layer)


def status_bar(c, a, dark=True):
    d = ImageDraw.Draw(c)
    col = (255, 255, 255, round(240 * a)) if dark else INK + (round(255 * a),)
    d.text((150, 92), "9:41", font=font(BOLD, 44), fill=col, anchor="mm")
    d.rounded_rectangle((W - 170, 78, W - 104, 106), radius=9, outline=col, width=3)
    d.rounded_rectangle((W - 165, 83, W - 120, 101), radius=6, fill=col)


# ── 장면 ─────────────────────────────────────────────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "오늘 누구 만나더라?", 620, 64, GREY, t, 0.05, path=MED)
    text(c, "앱을 열기 전에", 780, 104, WHITE, t, 0.45)
    text(c, "홈 화면이 먼저", 920, 104, ACCENT_SOFT, t, 0.85)
    return c


def s_home(t):
    c = HOME_BG.copy()
    status_bar(c, 1.0)
    app_grid(c, 2, 260, 1.0)
    app_grid(c, 2, 1290, 1.0)
    a = ease((t - 0.35) / 0.5)
    if a > 0:
        sc = 0.92 + 0.08 * ease((t - 0.35) / 0.7)
        wg = widget(1.0 * sc, a)
        x = (W - wg.width) // 2
        y = round(760 - (1 - a) * 40 + (1 - sc) * 200)
        shadow_box(c, (x + 40, y + 40, x + wg.width - 40, y + wg.height - 40), 64, a, strength=110, blur=36)
        c.alpha_composite(wg, (x, y))
    # 글은 위젯 아래 · 흐린 띠 위에
    b = ease((t - 1.3) / 0.45)
    if b > 0:
        band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(band).rectangle((0, 1720, W, H), fill=(10, 12, 16, round(120 * b)))
        c.alpha_composite(band)
        text(c, "다음 만남이 홈 화면에", 1752, 64, WHITE, t, 1.3)
    return c


def anchors(s):
    """위젯(widget(s)) 안의 짚을 자리 — 얼굴 위 · D-day 위 · 첫 알약 아래 (layer 좌표)."""
    pad, fr = 44 * s, 70 * s
    fcx, fcy = 40 + pad + fr + 5 * s, 40 + pad + 30 * s + fr
    tx = fcx + fr + 40 * s
    h = round(422 * s)
    return [
        ("만날 사람의 얼굴", fcx, fcy - fr - 6, False, 0.05),
        ("D-day 하나만 색으로", tx + 80 * s, 40 + pad + 4 * s, False, 0.75),
        ("그다음 약속은 알약으로", 40 + pad + 120 * s, 40 + h - pad + 2, True, 1.45),
    ]


def s_zoom(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "얼굴과 한 문장,\n그것뿐", 170, 86, INK, t, 0.05)
    wg = widget(1.08, 1.0)
    x, y = (W - wg.width) // 2, 640
    shadow_box(c, (x + 40, y + 40, x + wg.width - 40, y + wg.height - 40), 64, 1.0, strength=60)
    c.alpha_composite(wg, (x, y))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (label, ax, ay, below, t0) in enumerate(anchors(1.08)):
        a = ease((t - 0.6 - t0) / 0.35)
        if a <= 0:
            continue
        px, py = x + ax, y + ay
        ty = py + 220 if below else py - (130 if k == 0 else 250)
        d.line((px, py, px, ty + (-30 if below else 30)), fill=ACCENT + (round(255 * a),), width=4)
        d.ellipse((px - 10, py - 10, px + 10, py + 10), fill=ACCENT + (round(255 * a),))
        f = font(BOLD, 42)
        tw = d.textlength(label, font=f) + 56
        # 얼굴 꼬리표는 왼쪽 끝에 붙여 D-day 선과 겹치지 않게, 나머지는 점 위 가운데.
        bx = 40 if k == 0 else min(max(px - tw / 2, 40), W - 40 - tw)
        d.rounded_rectangle((bx, ty - 34, bx + tw, ty + 34), radius=34, fill=ACCENT + (round(255 * a),))
        d.text((bx + tw / 2, ty), label, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_lock(t):
    c = LOCK_BG.copy()
    d = ImageDraw.Draw(c)
    a0 = ease(t / 0.35)
    # 글 한 줄 위젯 — 날짜 자리
    d.text((W / 2, 300), "목 11월 6일  ·  3일 후 오전 10:00 · 커피 약속", font=font(MED, 38),
           fill=(255, 255, 255, round(225 * a0)), anchor="mm")
    d.text((W / 2, 470), "9:41", font=font(BOLD, 250), fill=(255, 255, 255, round(240 * a0)), anchor="mm")
    a = ease((t - 0.45) / 0.45)
    if a > 0:
        y = 700 + (1 - a) * 30
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        # 동그란 것
        cx, cy, r = 270, y + 95, 95
        ld.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, round(60 * a)))
        ld.text((cx, cy - 18), "D-3", font=font(BOLD, 58), fill=(255, 255, 255, round(255 * a)), anchor="mm")
        ld.text((cx, cy + 46), "약속", font=font(MED, 26), fill=(255, 255, 255, round(220 * a)), anchor="mm")
        # 네모난 것
        x0, x1 = 420, 880
        ld.rounded_rectangle((x0, y, x1, y + 190), radius=34, fill=(255, 255, 255, round(36 * a)))
        ld.text((x0 + 32, y + 42), "D-3 · 오전 10:00", font=font(BOLD, 34), fill=(255, 255, 255, round(240 * a)), anchor="lm")
        ld.text((x0 + 32, y + 98), "커피 약속", font=font(BOLD, 42), fill=(255, 255, 255, round(255 * a)), anchor="lm")
        ld.text((x0 + 32, y + 150), "정유진", font=font(MED, 34), fill=(255, 255, 255, round(220 * a)), anchor="lm")
        c.alpha_composite(layer)
    text(c, "잠금 화면에서도", 1360, 92, WHITE, t, 0.9)
    text(c, "동그란 것 · 네모난 것 · 글 한 줄", 1500, 50, GREY, t, 1.2, path=MED)
    return c


def s_tap(t):
    """위젯을 누르면 → 그 약속의 기록(만나기 전에)."""
    c = LIGHT_BG.convert("RGBA")
    text(c, "누르면 그 약속으로", 170, 86, INK, t, 0.05)
    text(c, "만나기 전에 볼 것이 한 장에", 290, 50, ACCENT, t, 0.3, path=MED)
    phase = ease((t - 1.0) / 0.55)
    if phase < 1:
        wg = widget(1.0, 1 - phase, glow=ease((t - 0.45) / 0.25) * (1 - phase))
        x, y = (W - wg.width) // 2, 760
        c.alpha_composite(wg, (x, y))
        # 손가락 누름
        p = ease((t - 0.45) / 0.3)
        if p > 0 and phase < 0.6:
            ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            rd = ImageDraw.Draw(ring)
            cx, cy = x + 300, y + 210
            rr = 40 + 70 * p
            rd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=ACCENT + (round(180 * (1 - p)),), width=8)
            rd.ellipse((cx - 38, cy - 38, cx + 38, cy + 38), fill=(20, 24, 29, round(70 * (1 - phase))))
            c.alpha_composite(ring)
    if phase > 0:
        ms.PHONE.place(c, BRIEFING, alpha=phase, zoom=1.0 + 0.04 * ease((t - 1.6) / 2.4))
    return c


def s_more(t):
    c = DARK_BG.convert("RGBA")
    text(c, "1.1.9 에 함께 온 것", 330, 84, WHITE, t, 0.05)
    items = ["매주 · 매달 반복 약속", "명함 여러 장 한 번에", "기록 틀", "다른 앱에서 공유로 담기", "기간 · 장소로 찾기", "약속 당일 알림"]
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, s in enumerate(items):
        a = ease((t - 0.45 - k * 0.16) / 0.35)
        if a <= 0:
            continue
        y = 560 + k * 150 + (1 - a) * 30
        f = font(BOLD, 52)
        tw = d.textlength(s, font=f) + 100
        x = (W - tw) / 2
        d.rounded_rectangle((x, y, x + tw, y + 104), radius=52, fill=(255, 255, 255, round(24 * a)))
        d.ellipse((x + 34, y + 44, x + 50, y + 60), fill=ACCENT_SOFT + (round(255 * a),))
        d.text((x + tw / 2 + 16, y + 52), s, font=f, fill=WHITE + (round(255 * a),), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "다음 만남을\n가장 먼저 보는 곳", 300, 88, INK, t, 0.1)
    ms.icon_at(c, 220, 790, ease((t - 0.6) / 0.5), scale=0.9 + 0.1 * ease((t - 0.6) / 0.6))
    text(c, "느린 인연", 930, 100, INK, t, 0.8)
    a = ease((t - 1.3) / 0.45)
    if a > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = font(BOLD, 46)
        chips = ["무료", "회원가입 없음", "광고 없음"]
        widths = [d.textlength(s, font=f) + 70 for s in chips]
        x = (W - (sum(widths) + 24 * (len(chips) - 1))) / 2
        y = 1090 + (1 - a) * 30
        for s, w in zip(chips, widths):
            d.rounded_rectangle((x, y, x + w, y + 92), radius=46, fill=ACCENT + (round(255 * a),))
            d.text((x + w / 2, y + 46), s, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
            x += w + 24
        c.alpha_composite(layer)
    text(c, "App Store 에서\n느린 인연 검색", 1250, 72, ACCENT, t, 1.9)
    return c


BRIEFING = shot("48-briefing.png")


def scenes():
    repeat = shot("50-repeat-detail.png")
    return [
        (3.4, s_hook),
        (4.2, s_home),
        (4.0, s_zoom),
        (3.6, s_lock),
        (4.6, s_tap),
        (3.4, mr.card_closeup(repeat, "매주 만나는 약속은\n다음 회차까지 알아서", 0.27, 0.45)),
        (3.4, s_more),
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
    if len(sys.argv) > 3:
        t = float(sys.argv[3])
        live = [(i, t - s) for i, s in enumerate(starts) if 0 <= t - s < sc[i][0]]
        i, lt = live[-1]
        sc[i][1](lt).convert("RGB").save(OUT)
        return
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
