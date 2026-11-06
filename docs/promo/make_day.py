#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 6 (1080 × 1920 · 30fps · 약 30초) — 컨셉: 그날을 잊지 않게 (2026-11-06 · 1.1.7 기념일).

첫 쇼츠(make_short.py) · 셋째(make_record.py) · 다섯째(make_plan.py)의 그리기 도구를 쓴다. 사람 화면의 기념일 줄은
**지금 브랜치의 CI 스크린샷**(`03-person-detail.png` · 견본 김하늘의 결혼기념일)이다. 기념일 편집 칸 · 설정의 알림 칸 ·
알림은 CI 스크린샷이 없어 **앱의 문구 그대로** 그린다 — 칩 다섯(`PersonEditView.SpecialDayEditor.presets`) · 칸 이름
(`날짜` · `해` · `알림` · `기념일 더하기`) · 설정 토글(`SettingsView`) · 알림 제목과 본문(`Core.ReminderPlanner`).
사람은 모두 지어낸 견본이다.
  python3 make_day.py <repo> <out.mp4>          영상
  python3 make_day.py <repo> <out.png> <초>     그 초의 한 장
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
CHIP = (237, 241, 243)        # Palette.chip
CHIP_INK = (78, 94, 107)      # Palette.chipInk
PALE = (228, 240, 236)        # Palette.accentSoft
RULE = (226, 230, 232)
SWITCH_ON = (52, 199, 89)
MUTED = (120, 128, 135)


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def card(c, box, a, radius=44):
    """흰 카드 + 그림자."""
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 20, x1, y1 + 20), radius=radius, fill=(20, 24, 29, round(50 * a)))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(28)))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=CARD + (round(255 * a),))
    c.alpha_composite(layer)


def switch(d, x, y, on, a):
    """시스템 스위치 모양 (오른쪽 끝이 x)."""
    w, h = 102, 62
    d.rounded_rectangle((x - w, y - h / 2, x, y + h / 2), radius=h / 2,
                        fill=(SWITCH_ON if on else (220, 222, 225)) + (round(255 * a),))
    cx = x - h / 2 if on else x - w + h / 2
    d.ellipse((cx - 27, y - 27, cx + 27, y + 27), fill=(255, 255, 255, round(255 * a)))


# ── 1. 첫 장면 — 챙겨야 할 날들 ─────────────────────────────────────────────
DAYS = [("결혼기념일", "10.12"), ("입사일", "3.2"), ("기일", "7.15"), ("자녀 생일", "9.8")]


def day_cards(t, t0, cy=1020):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h, gap = 220, 250, 24
    x0 = (W - (w * len(DAYS) + gap * (len(DAYS) - 1))) / 2
    for k, (label, date) in enumerate(DAYS):
        a = ease((t - t0 - k * 0.18) / 0.35)
        if a <= 0:
            continue
        x = x0 + k * (w + gap)
        y = cy - h / 2 + (1 - a) * 40
        d.rounded_rectangle((x, y, x + w, y + h), radius=30, fill=(255, 255, 255, round(26 * a)))
        d.rounded_rectangle((x, y, x + w, y + 54), radius=30, fill=ACCENT_SOFT + (round(200 * a),))
        d.rectangle((x, y + 30, x + w, y + 54), fill=ACCENT_SOFT + (round(200 * a),))
        d.text((x + w / 2, y + 140), date, font=font(BOLD, 64), fill=WHITE + (round(255 * a),), anchor="mm")
        d.text((x + w / 2, y + 210), label, font=font(MED, 32), fill=GREY + (round(255 * a),), anchor="mm")
    return layer


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "결혼기념일, 입사일, 기일…", 250, 60, GREY, t, 0.05, path=MED)
    text(c, "챙겨야 할 날은", 380, 104, WHITE, t, 0.4)
    text(c, "생일만이 아니죠", 510, 104, ACCENT_SOFT, t, 0.75)
    c.alpha_composite(day_cards(t, 1.1))
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "그날을\n잊지 않게", 1040, 72, ACCENT, t, 0.8, path=MED)
    return c


# ── 3. 기념일 칸 (사람 수정의 생일 아래) ──────────────────────────────────────
PRESETS = ["결혼기념일", "입사일", "기일", "자녀 생일", "개업일"]


def s_editor(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "생일 아래에\n기념일을 여러 개", 170, 86, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    x0, x1, y0 = 60, W - 60, 520
    # 칩 — 차례로 눌리고 마지막엔 결혼기념일로 돌아온다. 종류 칸 · 칸 제목이 고른 칩을 따른다.
    pick = min(len(PRESETS) - 1, int(max(0.0, t - 1.0) / 0.45)) if t > 1.0 else 0
    pick = 0 if t > 3.3 else pick
    label = PRESETS[pick]
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 20), label, font=font(MED, 36), fill=MUTED + (round(255 * a),), anchor="ls")
    card(c, (x0, y0, x1, y0 + 720), a)
    d = ImageDraw.Draw(c)
    fa = round(255 * a)
    d.text((x0 + 40, y0 + 70), label, font=font(MED, 44), fill=INK + (fa,), anchor="lm")
    d.line((x0 + 40, y0 + 130, x1, y0 + 130), fill=RULE + (fa,), width=2)
    cx, cy = x0 + 40, y0 + 175
    for k, p in enumerate(PRESETS):
        f = font(MED, 36)
        w = d.textlength(p, font=f) + 56
        if cx + w > x1 - 40:
            cx, cy = x0 + 40, cy + 84
        sel = k == pick
        d.rounded_rectangle((cx, cy - 32, cx + w, cy + 32), radius=32,
                            fill=(PALE if sel else CHIP) + (fa,), outline=(ACCENT + (fa,)) if sel else None, width=3)
        d.text((cx + w / 2, cy), p, font=f, fill=(ACCENT if sel else CHIP_INK) + (fa,), anchor="mm")
        cx += w + 18
    rows = [("날짜", "10월 12일"), ("해", "2018년")]
    ry = y0 + 380
    for name, value in rows:
        d.line((x0 + 40, ry - 50, x1, ry - 50), fill=RULE + (fa,), width=2)
        d.text((x0 + 40, ry), name, font=font(MED, 44), fill=INK + (fa,), anchor="lm")
        f = font(MED, 42)
        w = d.textlength(value, font=f) + 48
        d.rounded_rectangle((x1 - 40 - w, ry - 34, x1 - 40, ry + 34), radius=16, fill=CHIP + (fa,))
        d.text((x1 - 40 - w / 2, ry), value, font=f, fill=ACCENT + (fa,), anchor="mm")
        ry += 110
    d.line((x0 + 40, ry - 50, x1, ry - 50), fill=RULE + (fa,), width=2)
    d.text((x0 + 40, ry), "알림", font=font(MED, 44), fill=INK + (fa,), anchor="lm")
    switch(d, x1 - 40, ry, True, a)
    # 아래 단추
    b = ease((t - 1.6) / 0.35)
    if b > 0:
        y = y0 + 790
        card(c, (x0, y, x1, y + 110), b, radius=36)
        d = ImageDraw.Draw(c)
        d.text((x0 + 40, y + 55), "⊕  기념일 더하기", font=font(MED, 44), fill=ACCENT + (round(255 * b),), anchor="lm")
    return c


# ── 5. 설정 → 알림 ────────────────────────────────────────────────────────────
def s_settings(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "설정 → 알림에서\n기념일 당일 켜기", 170, 86, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    x0, x1, y0 = 60, W - 60, 560
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 20), "알림", font=font(MED, 36), fill=MUTED + (round(255 * a),), anchor="ls")
    rows = ["생일 당일", "기념일 당일", "알게 된 지 n주년", "연락 주기 (고른 사람만)", "만난 뒤 결과 적기"]
    card(c, (x0, y0, x1, y0 + 120 * len(rows)), a)
    d = ImageDraw.Draw(c)
    flip = ease((t - 1.3) / 0.3)
    for k, name in enumerate(rows):
        y = y0 + 60 + k * 120
        if k:
            d.line((x0 + 40, y - 60, x1, y - 60), fill=RULE + (round(255 * a),), width=2)
        hi = k == 1
        d.text((x0 + 40, y), name, font=font(BOLD if hi else MED, 44), fill=INK + (round(255 * a),), anchor="lm")
        on = k == 0 or (k == 1 and flip > 0.5)
        switch(d, x1 - 40, y, on, a)
    return c


# ── 6. 그날의 알림 ────────────────────────────────────────────────────────────
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
    d.text((x1 - 34, yy + 46), "오전 8:00", font=font(MED, 32), fill=(140, 147, 153, round(255 * a)), anchor="rm")
    d.text((x0 + 132, yy + 106), "오늘은 김하늘 님의 결혼기념일입니다", font=font(BOLD, 40), fill=INK + (round(255 * a),), anchor="lm")
    d.text((x0 + 132, yy + 168), "8주년 · 2018년 10월 12일", font=font(MED, 38), fill=(60, 66, 72, round(255 * a)), anchor="lm")
    return layer


def s_notify(t):
    c = DARK_BG.convert("RGBA")
    text(c, "그날,", 300, 96, WHITE, t, 0.05)
    text(c, "고른 시각에 알림 한 번", 430, 90, ACCENT_SOFT, t, 0.35)
    n = notification(t, 0.8)
    if n is not None:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((70, 850, W - 70, 1100), radius=44,
                                             fill=(0, 0, 0, round(90 * ease((t - 0.8) / 0.45))))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(n)
    text(c, "기념일마다 · 사람마다\n알림을 따로 끌 수 있어요", 1250, 52, GREY, t, 1.6, path=MED)
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "챙길 날은", 740, 104, WHITE, t, 0.1)
    text(c, "앱이 기억할게요", 880, 104, ACCENT_SOFT, t, 0.45)
    text(c, "기념일은 내 기기와 내 iCloud 에만\n백업 · 동기화에도 함께", 1080, 54, GREY, t, 0.9, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "소중한 사람의\n소중한 날까지", 300, 88, INK, t, 0.1)
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


def scenes():
    detail = shot("03-person-detail.png")
    return [
        (3.8, s_hook),
        (2.6, s_reveal),
        (4.4, s_editor),
        (3.4, mr.card_closeup(detail, "해를 적으면\n몇 주년인지", 0.495, 0.6)),
        (3.2, s_settings),
        (4.2, s_notify),
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
