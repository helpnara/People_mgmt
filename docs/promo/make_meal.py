#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 18 (1080 × 1920 · 30fps) — 컨셉: 올해 부모님과 몇 번 밥 먹었나요? (2026-11-28).

일정표 12-07(월) 06:30 칸. 돈 · 시간 다리 시험 둘째 주 — 첫 물음에 시간(몇 번 · 앞으로 15년 60번).
7회차 분석 반영(`../promo-youtube-stats.md` 맨 아래): 06:30 공개 · 첫 물음은 추상 물음이 아니라 **구체적인 장면 한 줄**(부모님과 밥).
앱 문구 그대로 다시 그렸다:
- 사람 화면 타임라인(`PersonDetailView.timelineSection`) — 머리글 `타임라인 · 기록 14건` → 유형 칩 `식사` 를 누르면 `타임라인 · 기록 4 / 14건`
  (칩은 그 사람의 기록에 쓰인 유형이 둘 이상일 때만 · 유형 `식사` 는 Presets 의 `meal`).
- 타임라인 줄(`TimelineRow`) — 유형 아이콘 · 날짜 · 제목 · 메모 첫 줄.
앞으로 15년 × 올해 4번 = 60번은 **올해처럼 이어진다는 가정**이다(영상에 그렇게 적는다 · 파이썬 대조 4 * 15 = 60).
사람 · 기록은 모두 지어낸 것이다 (CLAUDE.md §2). **0초 장면에 질문 글이 이미 다 떠 있다.**
  python3 make_meal.py <repo> <out.mp4>          영상
  python3 make_meal.py <repo> <out.png> <초>     그 초의 한 장
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
import make_quiet as mq  # noqa: E402
import make_search as msr  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
CARD, RULE, MUTED, BODY, MINT, DARK_CARD = mq.CARD, mq.RULE, mq.MUTED, mq.BODY, mq.MINT, mq.DARK_CARD
CHIP_BG = (236, 240, 241)
card, tap_ring = mq.card, mq.tap_ring
chevron = msr.chevron
SHOWN = -1.0


CHIP_ON = MINT
MEALS = [("11월 20일", "아버지 생신 점심", "미역국 · 무릎 얘기"), ("9월 17일", "추석 저녁", "전 부치고 같이 먹음"),
         ("5월 8일", "어버이날 외식", "아버지 건강검진 결과"), ("2월 9일", "설날 아침", "떡국 · 올해 이사 계획")]
OTHERS = ["연락", "병원", "여행"]


def fork(d, cx, cy, col, s=1.0, w=4):
    """식사 아이콘(fork.knife 꼴) — 타임라인 · 칩 모두 같은 그림."""
    for dx in (-14, -5, 4):
        d.line((cx + (dx - 4) * s, cy - 24 * s, cx + (dx - 4) * s, cy - 6 * s), fill=col, width=w)
    d.arc((cx - 22 * s, cy - 24 * s, cx + 0 * s, cy - 2 * s), 0, 180, fill=col, width=w)
    d.line((cx - 11 * s, cy - 2 * s, cx - 11 * s, cy + 26 * s), fill=col, width=w)
    d.line((cx + 16 * s, cy - 24 * s, cx + 16 * s, cy + 26 * s), fill=col, width=w)
    d.arc((cx + 8 * s, cy - 24 * s, cx + 24 * s, cy - 2 * s), 270, 90, fill=col, width=w)


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 열두 달 ───────────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "올해 한 해", 250, 54, GREY, t, SHOWN, path=MED)
    text(c, "부모님과\n몇 번 밥\n먹었나요?", 350, 112, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    gx, gy = 250, 170
    x0 = (W - 3 * gx) / 2
    for k in range(12):
        r, col = divmod(k, 4)
        cx, cy = x0 + col * gx, 1230 + r * gy
        a = round(255 * (0.55 + 0.3 * (0.5 + 0.5 * math.sin(t * 3.0 + k * 0.6))))
        d.ellipse((cx - 46, cy - 46, cx + 46, cy + 46), fill=(70, 80, 88, a))
        d.text((cx, cy), f"{k + 1}월", font=font(MED, 38), fill=(232, 236, 238, a), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "만날 때마다 다음에 또", 560, 80, WHITE, t, 0.1)
    text(c, "세어 보면 생각보다 적어요", 690, 70, ACCENT_SOFT, t, 0.55)
    text(c, "기억은 한두 번뿐인데, 한 해는 열두 달", 900, 46, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "식사만 거르면 횟수가 보입니다", 1040, 52, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 타임라인 거르기 — 식사 칩 (PersonDetailView.timelineFilter · FR-013) ─────────────────
def chip(c, x, y, label, sel, a, w=None):
    d = ImageDraw.Draw(c)
    f = font(MED, 38)
    w = w or d.textlength(label, font=f) + 64
    fa = round(255 * a)
    d.rounded_rectangle((x, y, x + w, y + 76), radius=38, fill=(CHIP_ON if sel else CHIP_BG) + (fa,),
                        outline=(ACCENT + (fa,)) if sel else None, width=3)
    d.text((x + w / 2, y + 38), label, font=f, fill=(ACCENT if sel else BODY) + (fa,), anchor="mm")
    return w


def s_filter(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "어머니 화면에서\n식사만 거르면", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    picked = t > 1.6
    x0, x1 = 60, W - 60
    d = ImageDraw.Draw(c)
    head = "타임라인 · 기록 4 / 14건" if picked else "타임라인 · 기록 14건"
    d.text((x0 + 30, 520), head, font=font(MED, 40), fill=MUTED + (fa,), anchor="ls")
    x = x0 + 30
    for k, lab in enumerate(["전체", "식사"] + OTHERS):
        sel = (k == 1) if picked else (k == 0)
        x += chip(c, x, 560, lab, sel, a) + 16
    tap_ring(c, x0 + 30 + 40 + 64 + 16 + 70, 598, t, 1.3)
    rows = MEALS if picked else [("12월 14일", "병원 모시고 감", "검사 결과 들음")] + MEALS[:3]
    y0 = 680
    card(c, (x0, y0, x1, y0 + 4 * 170 + 10), a)
    d = ImageDraw.Draw(c)
    for k, (dt_, ti, me) in enumerate(rows):
        y = y0 + 20 + k * 170
        if picked:
            b = ease((t - 1.8 - k * 0.12) / 0.3)
        else:
            b = 1
        fb = round(255 * min(a, b))
        if ti == "병원 모시고 감":
            d.ellipse((x0 + 40, y + 30, x0 + 84, y + 74), outline=ACCENT + (fb,), width=4)
            d.line((x0 + 62, y + 40, x0 + 62, y + 64), fill=ACCENT + (fb,), width=4)
            d.line((x0 + 50, y + 52, x0 + 74, y + 52), fill=ACCENT + (fb,), width=4)
        else:
            fork(d, x0 + 62, y + 52, ACCENT + (fb,), 0.8)
        d.text((x0 + 120, y + 26), dt_, font=font(MED, 34), fill=MUTED + (fb,), anchor="lm")
        d.text((x0 + 120, y + 80), ti, font=font(BOLD, 46), fill=INK + (fb,), anchor="lm")
        d.text((x0 + 120, y + 132), me, font=font(MED, 36), fill=BODY + (fb,), anchor="lm")
        if k < 3:
            d.line((x0 + 46, y + 160, x1, y + 160), fill=RULE + (fb,), width=2)
    text(c, "올해 식사 4번 — 기록을 거르면 바로 셉니다", 1560, 44, ACCENT, t, 2.6, path=MED)
    return c


def s_math(t):
    c = DARK_BG.convert("RGBA")
    text(c, "올해 4번", 480, 110, WHITE, t, 0.1)
    text(c, "이대로 앞으로 15년이면", 680, 62, GREY, t, 0.7, path=MED)
    text(c, "60번", 830, 200, ACCENT_SOFT, t, 1.3)
    text(c, "올해처럼 이어진다는 가정 · 4번 × 15년", 1180, 42, GREY, t, 2.0, path=MED)
    return c


def s_msg(t):
    c = DARK_BG.convert("RGBA")
    text(c, "오늘 식사도 한 줄", 620, 84, WHITE, t, 0.1)
    text(c, "연말에 바로 셉니다", 750, 96, ACCENT_SOFT, t, 0.55)
    text(c, "먼저 연락할 날을 앞당기는 건 내 몫이에요", 960, 46, GREY, t, 1.2, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "올해가 가기 전에\n부모님과 한 끼 더", 280, 66, INK, t, 0.1)
    ms.icon_at(c, 220, 790, ease((t - 0.6) / 0.5), scale=0.9 + 0.1 * ease((t - 0.6) / 0.6))
    text(c, "느린 인연", 930, 100, INK, t, 0.8)
    a = ease((t - 1.3) / 0.45)
    if a > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = font(BOLD, 46)
        chips = ["무료", "회원가입 없음", "광고 없음"]
        widths = [d.textlength(s_, font=f) + 70 for s_ in chips]
        x = (W - (sum(widths) + 24 * (len(chips) - 1))) / 2
        y = 1090 + (1 - a) * 30
        for s_, w in zip(chips, widths):
            d.rounded_rectangle((x, y, x + w, y + 92), radius=46, fill=ACCENT + (round(255 * a),))
            d.text((x + w / 2, y + 46), s_, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
            x += w + 24
        c.alpha_composite(layer)
    text(c, "App Store 에서\n느린 인연 검색", 1250, 72, ACCENT, t, 1.9)
    return c


def scenes():
    return [(3.6, s_hook), (3.2, s_why), (2.4, s_reveal), (5.0, s_filter), (4.4, s_math), (3.2, s_msg), (5.0, s_end)]


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
