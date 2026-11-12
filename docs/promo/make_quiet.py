#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 10 (1080 × 1920 · 30fps · 약 27초) — 컨셉: 6개월째 연락 없는 사람, 몇 명인지 아세요? (2026-11-12).

조회수 1회차 분석(`../promo-youtube-stats.md`)대로 **숫자 하나 + 질문** 으로 연다. 앞 쇼츠가 다루지 않은 연락 주기와
돌아보기(최근 n개월 넘게 기록 없음)를 보인다. 1.1.9 까지 출시된 기능만 쓴다.

앞 쇼츠들(make_short.py · make_record.py · make_day.py)의 그리기 도구를 쓴다. 앱 화면은
- `18-network-overview.png` — 내 인맥 → 돌아보기(사람 8 · 최근 12개월 기록 있음 3 · `최근 6개월 넘게 기록 없음 3명`)
- 나머지는 앱 문구 그대로 다시 그렸다: `PersonEditView` 의 `연락 주기` 칸(없음 · 1 · 3 · 6 · 12개월과 바닥글),
  `ReminderPlanner` 의 연락 주기 알림(`○○ 님과 n개월 동안 기록이 없습니다` · `안부를 전하고 함께한 일을 남겨 보세요.`),
  설정 → 알림의 `연락 주기 (고른 사람만)`.
사람은 모두 견본(`SampleData`)의 지어낸 이름이다 (CLAUDE.md §2).
  python3 make_quiet.py <repo> <out.mp4>          영상
  python3 make_quiet.py <repo> <out.png> <초>     그 초의 한 장
"""
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
RULE = (226, 230, 232)
MUTED = (120, 128, 135)
FAINT = (152, 163, 172)
BODY = (51, 65, 79)
MINT = (226, 240, 235)
DARK_CARD = (44, 51, 60)


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def card(c, box, a, radius=44, fill=CARD):
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 20, x1, y1 + 20), radius=radius, fill=(20, 24, 29, round(50 * a)))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(28)))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=fill + (round(255 * a),))
    c.alpha_composite(layer)


def tap_ring(c, cx, cy, t, t0):
    p = ease((t - t0) / 0.3)
    if 0 < p < 1:
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rr = 36 + 60 * p
        ImageDraw.Draw(ring).ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=ACCENT + (round(170 * (1 - p)),), width=8)
        c.alpha_composite(ring)


# ── 1 첫 장면 — 숫자 하나 + 질문, 흐려지는 이름 줄 ─────────────────────────────
FADING = [("이도윤", "8개월 전"), ("박서연", "1년 전"), ("최민준", "7개월 전")]


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "마지막으로 연락한 게", 300, 58, GREY, t, 0.05, path=MED)
    text(c, "6개월 전", 400, 200, ACCENT_SOFT, t, 0.35)
    text(c, "그런 사람,\n몇 명인지 아세요?", 720, 100, WHITE, t, 0.95)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (name, ago) in enumerate(FADING):
        a = ease((t - 0.6 - k * 0.15) / 0.4)
        if a <= 0:
            continue
        # 줄마다 점점 옅어진다 — 잊혀 가는 이름
        fade = a * (1.0 - 0.25 * k) * (1.0 - 0.35 * ease((t - 2.2) / 0.9))
        al = round(255 * fade)
        y = 1120 + k * 150 + round((1 - a) * 30)
        d.rounded_rectangle((120, y, W - 120, y + 120), radius=34, fill=DARK_CARD + (al,))
        d.ellipse((150, y + 20, 230, y + 100), fill=(70, 80, 90, al))
        d.text((190, y + 60), name[0], font=font(BOLD, 40), fill=(200, 206, 210, al), anchor="mm")
        d.text((260, y + 60), name, font=font(BOLD, 46), fill=(225, 230, 232, al), anchor="lm")
        d.text((W - 150, y + 60), f"마지막 연락 · {ago}", font=font(MED, 36), fill=(150, 158, 165, al), anchor="rm")
    c.alpha_composite(layer)
    return c


def s_problem(t):
    c = DARK_BG.convert("RGBA")
    text(c, "미워서가 아니라", 560, 96, WHITE, t, 0.1)
    text(c, "잊어서 멀어집니다", 700, 96, ACCENT_SOFT, t, 0.55)
    text(c, "연락처는 언제 마지막으로\n만났는지 알려 주지 않아요", 920, 54, GREY, t, 1.1, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "멀어지기 전에 먼저 알려 줍니다", 1040, 60, ACCENT, t, 0.8, path=MED)
    return c


# ── 5 연락 주기 — PersonEditView 의 칸 · 바닥글 그대로 ──────────────────────────
CHOICES = ["없음", "1개월", "3개월", "6개월", "12개월"]


def s_cadence(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "사람마다\n연락 주기를 정하면", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 520
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "연락 주기", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    picked = t > 1.6
    card(c, (x0, y0, x1, y0 + 130), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((x0 + 50, y0 + 65), "연락 주기", font=font(MED, 46), fill=INK + (fa,), anchor="lm")
    value = "3개월" if picked else "없음"
    d.text((x1 - 100, y0 + 65), value, font=font(MED, 46), fill=(ACCENT if picked else MUTED) + (fa,), anchor="rm")
    cx, cy = x1 - 66, y0 + 65   # 위아래 꺾쇠 (글꼴에 없는 기호라 선으로)
    d.line((cx - 12, cy - 6, cx, cy - 18, cx + 12, cy - 6), fill=MUTED + (fa,), width=4)
    d.line((cx - 12, cy + 6, cx, cy + 18, cx + 12, cy + 6), fill=MUTED + (fa,), width=4)
    c.alpha_composite(layer)
    tap_ring(c, x1 - 160, y0 + 65, t, 0.6)
    # 고르는 차림표 — 0.8 ~ 1.7 초
    m = ease((t - 0.8) / 0.25) * (1 - ease((t - 1.7) / 0.25))
    if m > 0:
        fm = round(255 * m)
        mx0, mx1, my0 = x1 - 420, x1 - 20, y0 + 150
        card(c, (mx0, my0, mx1, my0 + 110 * len(CHOICES)), m, radius=34)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for k, s in enumerate(CHOICES):
            yy = my0 + 55 + k * 110
            chosen = (s == "3개월" and t > 1.3) or (s == "없음" and t <= 1.3)
            if chosen:
                d.line((mx0 + 40, yy, mx0 + 52, yy + 12, mx0 + 74, yy - 12), fill=ACCENT + (fm,), width=6)
            d.text((mx0 + 100, yy), s, font=font(MED, 44), fill=INK + (fm,), anchor="lm")
            if k < len(CHOICES) - 1:
                d.line((mx0 + 100, yy + 55, mx1, yy + 55), fill=RULE + (fm,), width=2)
        c.alpha_composite(layer)
        tap_ring(c, mx0 + 160, my0 + 55 + 2 * 110, t, 1.15)
    text(c, "고른 사람만, 마지막 기록에서 이만큼 지나면\n한 번 알립니다. 설정 → 알림에서\n연락 주기를 켰을 때만 옵니다.",
         y0 + 170, 36, MUTED, t, 2.0, path=MED, rise=0)
    b = ease((t - 2.4) / 0.35)
    if b > 0:
        y2 = 1080
        fb = round(255 * b)
        d = ImageDraw.Draw(c)
        d.text((x0 + 30, y2 - 22), "설정 → 알림", font=font(MED, 38), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y2, x1, y2 + 130), b)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.text((x0 + 50, y2 + 65), "연락 주기 (고른 사람만)", font=font(MED, 46), fill=INK + (fb,), anchor="lm")
        tx = x1 - 50 - 130
        on = ease((t - 2.9) / 0.25)
        track = tuple(round(a1 + (a2 - a1) * on) for a1, a2 in zip((220, 224, 227), ACCENT))
        d.rounded_rectangle((tx, y2 + 25, tx + 130, y2 + 105), radius=40, fill=track + (fb,))
        kx = tx + 6 + round(62 * on)
        d.ellipse((kx, y2 + 31, kx + 68, y2 + 99), fill=(255, 255, 255, fb))
        c.alpha_composite(layer)
        tap_ring(c, tx + 65, y2 + 65, t, 2.75)
    return c


# ── 6 알림 — ReminderPlanner 의 연락 주기 문구 그대로 ──────────────────────────
def notification(t, t0, y=820):
    a = ease((t - t0) / 0.45)
    if a <= 0:
        return None
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1 = 70, W - 70
    yy = y + (1 - a) * 40
    d.rounded_rectangle((x0, yy, x1, yy + 250), radius=44, fill=(250, 251, 250, round(240 * a)))
    s = 78
    icon = ms.ICON.resize((s, s), Image.LANCZOS)
    icon.putalpha(ms.rounded_mask((s, s), round(s * 0.225)).point(lambda v: round(v * a)))
    layer.alpha_composite(icon, (x0 + 34, round(yy + 34)))
    d.text((x0 + 132, yy + 46), "느린 인연", font=font(MED, 34), fill=(110, 118, 125, round(255 * a)), anchor="lm")
    d.text((x1 - 34, yy + 46), "오전 9:00", font=font(MED, 32), fill=(140, 147, 153, round(255 * a)), anchor="rm")
    d.text((x0 + 132, yy + 106), "김하늘 님과 3개월 동안 기록이 없습니다", font=font(BOLD, 40), fill=INK + (round(255 * a),), anchor="lm")
    d.text((x0 + 132, yy + 168), "안부를 전하고 함께한 일을 남겨 보세요.", font=font(MED, 38), fill=(60, 66, 72, round(255 * a)), anchor="lm")
    return layer


def s_notify(t):
    c = DARK_BG.convert("RGBA")
    text(c, "그만큼 지나면,", 300, 96, WHITE, t, 0.05)
    text(c, "안부 알림 한 번", 430, 90, ACCENT_SOFT, t, 0.35)
    n = notification(t, 0.8)
    if n is not None:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((70, 850, W - 70, 1100), radius=44,
                                             fill=(0, 0, 0, round(90 * ease((t - 0.8) / 0.45))))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(n)
    text(c, "기록을 남기면\n다음 알림은 그만큼 뒤로", 1250, 52, GREY, t, 1.6, path=MED)
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "점수가 아니라", 700, 104, WHITE, t, 0.1)
    text(c, "안부를 위해", 840, 104, ACCENT_SOFT, t, 0.45)
    text(c, "사람을 줄 세우지 않습니다\n기록은 내 기기와 내 iCloud 에만", 1060, 54, GREY, t, 0.9, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "잊기 전에,\n안부 한 번", 300, 88, INK, t, 0.1)
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


OVERVIEW = shot("18-network-overview.png")


def scenes():
    return [
        (3.6, s_hook),
        (3.0, s_problem),
        (2.4, s_reveal),
        # 내 인맥 → 돌아보기 — 사람 8 · 최근 12개월 기록 있음 3 · 최근 6개월 넘게 기록 없음 3명 (스크린샷 18)
        (3.8, mr.card_closeup(OVERVIEW, "6개월 넘게 기록 없는\n사람이 한눈에", 0.355, 0.752)),
        (4.4, s_cadence),
        (3.6, s_notify),
        (3.0, s_promise),
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
