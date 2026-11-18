#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 13 (1080 × 1920 · 30fps · 약 33초) — 컨셉: 가까운 사람 10명, 처음 만난 날 다 기억하나요? (2026-11-18).

11-18 2회차 조회수 분석(`../promo-youtube-stats.md`)을 따른다 — 사람에 대한 질문 + 숫자 · 같은 이야기를 되풀이하지 않는다
(그래서 4편 `한 해 돌아보기` 와 겹치는 `올해 처음 만난 사람` 대신, 가장 잘된 쇼츠 1 의 결인 **처음 만남** 을 새 장면으로).
**0초 장면에 질문 글이 이미 다 떠 있다** (쇼츠 11 이 0초 빈 화면으로 5시간에 1회 · `README.md` 문안 규칙).

앱 화면은
- `20-network-readiness.png` — 내 인맥 → 입력 상태의 `올해 처음 만남` 칸 (처음 만난 날을 적은 사람 5명 / 8명 · 처음 만난 날이 빈 사람 3명)
- `31-fill-first-met.png` — 처음 만난 날이 빈 사람 (누르면 바로 편집 · `처음 만난 날 채우기`)
- 나머지는 앱 문구 그대로 다시 그렸다:
  `PersonEditView` 의 `첫 인연` 칸(`처음 만난 날짜` · 정밀도 `날짜까지 · 월까지 · 연도만` · `어떤 계기로 알게 되었나요?`),
  `PersonDetailView` 타임라인 맨 아래의 깃발 줄(`2019년 3월` · `시작점 — 처음 만남`),
  `SettingsView` 의 알림 칸(차례 그대로), `Core.ReminderPlanner` 의 n주년 알림(`○○ 님과 알게 된 지 n년이 되었습니다` ·
  `처음 만난 날 2019년 3월 14일`) — n주년은 **날짜까지 적은 사람만** 온다(`Reminders.knowsFirstMetDay`). 알림 기본 시각 오전 9:00.
사람은 모두 견본(`SampleData`)의 지어낸 이름이다 (CLAUDE.md §2).
  python3 make_firstmet.py <repo> <out.mp4>          영상
  python3 make_firstmet.py <repo> <out.png> <초>     그 초의 한 장
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
import make_quiet as mq  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
CARD, RULE, MUTED, BODY, MINT, DARK_CARD = mq.CARD, mq.RULE, mq.MUTED, mq.BODY, mq.MINT, mq.DARK_CARD
CHIP_BG = (236, 240, 241)
SWITCH_ON = (52, 199, 89)
card, tap_ring = mq.card, mq.tap_ring
SHOWN = -1.0   # 이미 지난 시각 — 0초부터 다 떠 있는 글


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def switch(d, x, y, on, a):
    """시스템 스위치 모양 (오른쪽 끝이 x)."""
    w, h = 102, 62
    d.rounded_rectangle((x - w, y - h / 2, x, y + h / 2), radius=h / 2,
                        fill=(SWITCH_ON if on else (220, 222, 225)) + (round(255 * a),))
    cx = x - h / 2 if on else x - w + h / 2
    d.ellipse((cx - 27, y - 27, cx + 27, y + 27), fill=(255, 255, 255, round(255 * a)))


def flag(d, x, y, color, s=1.0):
    """SF Symbols `flag` 를 선으로 — 깃대와 깃발."""
    d.line((x, y - 24 * s, x, y + 26 * s), fill=color, width=round(5 * s))
    d.polygon([(x, y - 24 * s), (x + 34 * s, y - 16 * s), (x, y - 2 * s)], outline=color, fill=None, width=round(5 * s))


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 열 사람 중 일곱은 물음표 ─────────────────────
FACES = [("김", "2019.3"), ("박", "?"), ("이", "?"), ("최", "2021"), ("정", "?"),
         ("윤", "?"), ("한", "2018.5"), ("오", "?"), ("서", "?"), ("강", "?")]


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "가까운 사람 10명,", 300, 66, GREY, t, SHOWN, path=MED)
    text(c, "처음 만난 날,\n다 기억하나요?", 420, 108, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pulse = 0.55 + 0.25 * (0.5 + 0.5 * __import__("math").sin(t * 3.2))
    size, gap = 150, 40
    x_start = (W - (5 * size + 4 * gap)) / 2
    for k, (initial, when) in enumerate(FACES):
        x = x_start + (k % 5) * (size + gap)
        y = 960 + (k // 5) * 290
        known = when != "?"
        if known:
            d.ellipse((x, y, x + size, y + size), fill=DARK_CARD + (255,))
            d.text((x + size / 2, y + size / 2), initial, font=font(BOLD, 56), fill=(232, 236, 238, 255), anchor="mm")
            d.text((x + size / 2, y + size + 46), when, font=font(MED, 34), fill=ACCENT_SOFT + (255,), anchor="mm")
        else:
            alpha = round(255 * pulse)
            d.ellipse((x, y, x + size, y + size), outline=(150, 158, 165, alpha), width=4)
            d.text((x + size / 2, y + size / 2), initial, font=font(BOLD, 56), fill=(150, 158, 165, alpha), anchor="mm")
            d.text((x + size / 2, y + size + 46), "?", font=font(BOLD, 40), fill=(170, 178, 184, alpha), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "생일은 달력이 알려 주지만", 560, 76, WHITE, t, 0.1)
    text(c, "처음 만난 날은\n아무도 안 알려 줘요", 700, 92, ACCENT_SOFT, t, 0.55)
    text(c, "우리 이야기가 시작된 날인데", 1030, 56, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "처음 만난 날부터 적는 인연 기록", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 사람 수정 → 첫 인연 (PersonEditView 그대로) ─────────────────────────────────
PRECISIONS = ["날짜까지", "월까지", "연도만"]


def s_edit(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "정확히 몰라도\n괜찮아요", 130, 88, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 600
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "첫 인연", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 600), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 처음 만난 날짜 — 켜져 있다
    y = y0 + 75
    d.text((x0 + 40, y), "처음 만난 날짜", font=font(MED, 46), fill=INK + (fa,), anchor="lm")
    switch(d, x1 - 40, y, True, a)
    d.line((x0 + 40, y0 + 150, x1, y0 + 150), fill=RULE + (fa,), width=2)
    # 정밀도 — 날짜까지 → 월까지 로 옮겨 간다
    pick = 1 if t > 1.25 else 0
    sy0, sy1 = y0 + 185, y0 + 275
    sx0, sx1 = x0 + 40, x1 - 40
    d.rounded_rectangle((sx0, sy0, sx1, sy1), radius=24, fill=CHIP_BG + (fa,))
    seg = (sx1 - sx0) / 3
    d.rounded_rectangle((sx0 + seg * pick + 6, sy0 + 6, sx0 + seg * (pick + 1) - 6, sy1 - 6), radius=20, fill=(255, 255, 255, fa))
    spots = []
    for k, s in enumerate(PRECISIONS):
        cx = sx0 + seg * (k + 0.5)
        d.text((cx, (sy0 + sy1) / 2), s, font=font(BOLD if k == pick else MED, 40),
               fill=(INK if k == pick else BODY) + (fa,), anchor="mm")
        spots.append((cx, (sy0 + sy1) / 2))
    d.line((x0 + 40, y0 + 310, x1, y0 + 310), fill=RULE + (fa,), width=2)
    # 날짜 — 2019년 3월
    y = y0 + 385
    d.text((x0 + 40, y), "날짜", font=font(MED, 46), fill=INK + (fa,), anchor="lm")
    when = "2019년 3월" if pick == 1 else "2019년 3월 14일"
    w = d.textlength(when, font=font(MED, 42)) + 50
    d.rounded_rectangle((x1 - 40 - w, y - 40, x1 - 40, y + 40), radius=18, fill=CHIP_BG + (fa,))
    d.text((x1 - 40 - w / 2, y), when, font=font(MED, 42), fill=INK + (fa,), anchor="mm")
    d.line((x0 + 40, y0 + 460, x1, y0 + 460), fill=RULE + (fa,), width=2)
    # 어떤 계기로 알게 되었나요? — 한 줄이 적힌다
    note = "회사 워크숍에서 같은 조"
    typed = note[:max(0, min(len(note), round((t - 2.0) * 14)))]
    d.text((x0 + 40, y0 + 530), typed or "어떤 계기로 알게 되었나요?", font=font(MED, 44),
           fill=(INK if typed else MUTED) + (fa,), anchor="lm")
    c.alpha_composite(layer)
    tap_ring(c, *spots[1], t, 0.95)
    text(c, "월까지, 연도만 적어도 됩니다", 1300, 54, ACCENT, t, 1.5, path=MED)
    return c


# ── 5 사람 화면 — 타임라인 맨 아래의 시작점 (PersonDetailView 그대로) ─────────────────────
RECORDS = [("2026년 10월 2일", "저녁 · 이직 축하"), ("2025년 6월 14일", "결혼식")]


def s_start(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "타임라인 맨 아래,\n우리 이야기의 시작점", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 620
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "타임라인 · 기록 2건", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 540), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (day, what) in enumerate(RECORDS):
        y = y0 + 40 + k * 170
        d.text((x0 + 104, y + 36), day, font=font(MED, 36), fill=MUTED + (fa,), anchor="lm")
        d.text((x0 + 104, y + 92), what, font=font(MED, 46), fill=INK + (fa,), anchor="lm")
        d.ellipse((x0 + 44, y + 52, x0 + 72, y + 80), fill=MINT + (fa,))
        d.line((x0 + 40, y + 160, x1, y + 160), fill=RULE + (fa,), width=2)
    # 시작점 — 깃발과 함께 늦게 떠오른다
    b = ease((t - 1.0) / 0.4)
    if b > 0:
        fb = round(255 * min(a, b))
        y = y0 + 40 + 2 * 170
        d.rounded_rectangle((x0 + 16, y - 6, x1 - 16, y + 150), radius=28, fill=MINT + (round(fb * 0.55),))
        flag(d, x0 + 58, y + 72, ACCENT + (fb,), 1.15)
        d.text((x0 + 104, y + 36), "2019년 3월", font=font(MED, 36), fill=MUTED + (fb,), anchor="lm")
        d.text((x0 + 104, y + 92), "시작점 — 처음 만남", font=font(BOLD, 48), fill=INK + (fb,), anchor="lm")
    c.alpha_composite(layer)
    text(c, "그 뒤의 만남이 위로 쌓입니다", 1300, 52, MUTED, t, 1.8, path=MED)
    return c


# ── 8 설정 → 알림 (SettingsView 차례 그대로) ────────────────────────────────────────
def s_settings(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "설정 → 알림에서\n알게 된 지 n주년 켜기", 170, 84, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    x0, x1, y0 = 60, W - 60, 600
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 20), "알림", font=font(MED, 36), fill=MUTED + (round(255 * a),), anchor="ls")
    rows = ["생일 당일", "기념일 당일", "알게 된 지 n주년", "연락 주기 (고른 사람만)", "약속 당일"]
    card(c, (x0, y0, x1, y0 + 120 * len(rows)), a)
    d = ImageDraw.Draw(c)
    flip = ease((t - 1.3) / 0.3)
    for k, name in enumerate(rows):
        y = y0 + 60 + k * 120
        if k:
            d.line((x0 + 40, y - 60, x1, y - 60), fill=RULE + (round(255 * a),), width=2)
        hi = k == 2
        d.text((x0 + 40, y), name, font=font(BOLD if hi else MED, 44), fill=INK + (round(255 * a),), anchor="lm")
        switch(d, x1 - 40, y, hi and flip > 0.5, a)
    tap_ring(c, x1 - 91, y0 + 60 + 2 * 120, t, 1.15)
    text(c, "기본은 꺼져 있어요", 1300, 52, MUTED, t, 1.8, path=MED)
    return c


# ── 9 그날의 알림 (Core.ReminderPlanner 문구 그대로) ─────────────────────────────────
def notification(t, t0, y=820):
    a = ease((t - t0) / 0.45)
    if a <= 0:
        return None
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1 = 60, W - 60
    yy = y + (1 - a) * 40
    d.rounded_rectangle((x0, yy, x1, yy + 250), radius=44, fill=(250, 251, 250, round(240 * a)))
    s = 78
    icon = ms.ICON.resize((s, s), Image.LANCZOS)
    icon.putalpha(ms.rounded_mask((s, s), round(s * 0.225)).point(lambda v: round(v * a)))
    layer.alpha_composite(icon, (x0 + 34, round(yy + 34)))
    d.text((x0 + 132, yy + 46), "느린 인연", font=font(MED, 34), fill=(110, 118, 125, round(255 * a)), anchor="lm")
    d.text((x1 - 34, yy + 46), "오전 9:00", font=font(MED, 32), fill=(140, 147, 153, round(255 * a)), anchor="rm")
    d.text((x0 + 132, yy + 106), "김하늘 님과 알게 된 지 7년이 되었습니다", font=font(BOLD, 36), fill=INK + (round(255 * a),), anchor="lm")
    d.text((x0 + 132, yy + 168), "처음 만난 날 2019년 3월 14일", font=font(MED, 36), fill=(60, 66, 72, round(255 * a)), anchor="lm")
    return layer


def s_notify(t):
    c = DARK_BG.convert("RGBA")
    text(c, "날짜까지 적었다면,", 300, 76, WHITE, t, 0.05)
    text(c, "그날 알림 한 번", 430, 96, ACCENT_SOFT, t, 0.35)
    n = notification(t, 0.8)
    if n is not None:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((60, 850, W - 60, 1100), radius=44,
                                             fill=(0, 0, 0, round(90 * ease((t - 0.8) / 0.45))))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(n)
    text(c, "안부 한마디 건네기 좋은 날", 1250, 56, GREY, t, 1.6, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "처음 만난 날부터,\n우리 이야기를 남기는 법", 280, 70, INK, t, 0.1)
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


READINESS = shot("20-network-readiness.png")
FILL = shot("31-fill-first-met.png")


def scenes():
    return [
        (3.6, s_hook),
        (3.2, s_why),
        (2.4, s_reveal),
        (4.4, s_edit),
        (3.8, s_start),
        # 내 인맥 → 입력 상태 — 올해 처음 만남 칸 (스크린샷 20)
        (3.2, mr.card_closeup(READINESS, "아직 비어 있는 사람도\n세어 둡니다", 0.632, 0.85)),
        # 처음 만난 날이 빈 사람 — 누르면 바로 편집 (스크린샷 31)
        (3.2, mr.card_closeup(FILL, "누르면 바로\n채웁니다", 0.07, 0.465)),
        (3.4, s_settings),
        (3.6, s_notify),
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
