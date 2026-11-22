#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 16 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 연말 선물 12명, 60만원 — 작년이랑 같은 걸 또? (2026-11-22).

일정표 11-30(월) 06:30 칸. 돈 · 시간 다리 2주 시험(`../promo-youtube-stats.md`) — 첫 물음에 돈(12명 × 5만원 = 60만원).
사용자 결정(11-22): **사람 화면 중심** — 15편(메모 · 태그 · 찾기)과 겹치지 않게, 그 사람 화면의 기억할 것 · 타임라인 거르기 · 다음에 이야기할 것.
**0초 장면에 질문 글이 이미 다 떠 있다** (`README.md` 문안 규칙). 선물 칸은 없다 — 기록 · 태그 · 기억할 것으로 남긴다.
앱 문구 그대로 다시 그렸다:
- 사람 화면(`PersonDetailView`, screenshots/03 의 꼴) — 이름 · 소속 · 직함, 전구 아이콘 카드 = 기억할 것(`keyNote`), 생일 줄(선물 상자 아이콘).
  기억할 것 칸 안내 `좋아하는 것 · 가족 이름 · 피하는 음식처럼`(`PersonEditView`).
- 타임라인 거르기 칩(FR-013) — `전체` · 이 사람 기록에 쓰인 유형 · `#태그`. 고르면 머리가 `타임라인 · 기록 2 / 9건`.
  줄(`TimelineRow`) = 유형 아이콘 · 날짜 · 제목 · 메모 한 줄 · `#태그`.
- `다음에 이야기할 것 2`(`TalkItemsSection`) — 견본의 `하준이 입학 선물 물어보기`.
사람 · 기록은 모두 견본(`SampleData` — 김하늘의 기억할 것 · 다음에 이야기할 것은 견본 그대로)과 지어낸 것이다 (CLAUDE.md §2).
  python3 make_yeargift.py <repo> <out.mp4>          영상
  python3 make_yeargift.py <repo> <out.png> <초>     그 초의 한 장
"""
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
chevron, search_bar = msr.chevron, msr.search_bar
SHOWN = -1.0



def gift_box(d, cx, cy, s, body, ribbon, a=255):
    """선물 상자 — 몸통 · 뚜껑 · 리본 (SF Symbols gift 꼴을 흉내)."""
    w = s
    d.rounded_rectangle((cx - w / 2, cy - w * 0.15, cx + w / 2, cy + w / 2), radius=8, fill=body + (a,))
    d.rounded_rectangle((cx - w * 0.56, cy - w * 0.36, cx + w * 0.56, cy - w * 0.12), radius=8, fill=body + (a,))
    d.rectangle((cx - w * 0.07, cy - w * 0.36, cx + w * 0.07, cy + w / 2), fill=ribbon + (a,))
    d.ellipse((cx - w * 0.34, cy - w * 0.62, cx - w * 0.02, cy - w * 0.34), outline=ribbon + (a,), width=max(3, round(w * 0.06)))
    d.ellipse((cx + w * 0.02, cy - w * 0.62, cx + w * 0.34, cy - w * 0.34), outline=ribbon + (a,), width=max(3, round(w * 0.06)))


def gift_outline(d, cx, cy, s, col):
    """선 그림 선물 상자 (gift 아이콘 꼴) — 줄 아이콘 자리."""
    w = 4
    d.rectangle((cx - s / 2, cy - s * 0.1, cx + s / 2, cy + s / 2), outline=col, width=w)
    d.rectangle((cx - s * 0.58, cy - s * 0.32, cx + s * 0.58, cy - s * 0.1), outline=col, width=w)
    d.line((cx, cy - s * 0.32, cx, cy + s / 2), fill=col, width=w)
    d.arc((cx - s * 0.42, cy - s * 0.62, cx, cy - s * 0.22), 180, 360, fill=col, width=w)
    d.arc((cx, cy - s * 0.62, cx + s * 0.42, cy - s * 0.22), 180, 360, fill=col, width=w)


def bulb(d, cx, cy, col):
    d.ellipse((cx - 22, cy - 34, cx + 22, cy + 10), outline=col, width=5)
    d.line((cx - 10, cy + 18, cx + 10, cy + 18), fill=col, width=5)
    d.line((cx - 8, cy + 30, cx + 8, cy + 30), fill=col, width=5)


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 상자 열두 개, 위에 물음표 ─────────────────
def s_hook(t):
    import math
    c = DARK_BG.convert("RGBA")
    text(c, "연말 선물 12명, 60만원", 300, 66, GREY, t, SHOWN, path=MED)
    text(c, "작년이랑\n같은 걸 또?", 420, 110, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s, gx, gy = 116, 160, 220
    x0 = (W - 5 * gx) / 2
    for k in range(12):
        r, col = divmod(k, 6)
        cx, cy = x0 + col * gx, 1000 + r * gy
        a = round(255 * (0.55 + 0.3 * (0.5 + 0.5 * math.sin(t * 3.0 + k * 0.6))))
        gift_box(d, cx, cy, s, DARK_CARD, (110, 120, 128), a)
        d.text((cx, cy + 24), "?", font=font(BOLD, 54), fill=(232, 236, 238, a), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "누구에게 뭘 줬더라?", 560, 84, WHITE, t, 0.1)
    text(c, "누가 뭘 좋아했더라?", 690, 84, ACCENT_SOFT, t, 0.55)
    text(c, "선물 고를 때마다 처음부터 다시 고민해요", 900, 50, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "그 사람 화면에 다 모여 있습니다", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 사람 화면 — 기억할 것(전구 카드) · 생일 (PersonDetailView · screenshots/03) ──────────
def s_person(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "선물 고르기 전,\n그 사람 화면부터", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 540
    card(c, (x0, y0, x1, y0 + 760), a)
    d = ImageDraw.Draw(c)
    d.ellipse((x0 + 50, y0 + 50, x0 + 200, y0 + 200), fill=MINT + (fa,))
    d.ellipse((x0 + 100, y0 + 80, x0 + 150, y0 + 130), fill=ACCENT + (fa,))
    d.chord((x0 + 75, y0 + 140, x0 + 175, y0 + 240), 180, 360, fill=ACCENT + (fa,))
    d.rectangle((x0 + 50, y0 + 200, x0 + 200, y0 + 240), fill=CARD + (fa,))
    d.text((x0 + 240, y0 + 125), "김하늘", font=font(BOLD, 72), fill=INK + (fa,), anchor="lm")
    d.text((x0 + 50, y0 + 290), "청림소프트 · 팀장", font=font(MED, 42), fill=BODY + (fa,), anchor="lm")
    # 기억할 것 — 전구 카드
    ky = y0 + 350
    d.rounded_rectangle((x0 + 40, ky, x1 - 40, ky + 190), radius=30, fill=MINT + (fa,))
    bulb(d, x0 + 105, ky + 92, ACCENT + (fa,))
    d.text((x0 + 170, ky + 62), "커피는 디카페인. 첫째 하준이는", font=font(MED, 42), fill=INK + (fa,), anchor="lm")
    d.text((x0 + 170, ky + 128), "내년 봄에 초등학교 입학.", font=font(MED, 42), fill=INK + (fa,), anchor="lm")
    # 생일 줄
    gy = ky + 290
    gift_outline(d, x0 + 80, gy, 44, ACCENT + (fa,))
    d.text((x0 + 140, gy), "생일 5월 21일", font=font(MED, 44), fill=INK + (fa,), anchor="lm")
    if t > 1.2:
        ring_a = ease((t - 1.2) / 0.35)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.rounded_rectangle((x0 + 28, ky - 12, x1 - 28, ky + 202), radius=38, outline=ACCENT + (round(255 * ring_a),), width=8)
        c.alpha_composite(layer)
    text(c, "기억할 것 — 좋아하는 것 · 가족 이름 · 피하는 음식", 1420, 42, MUTED, t, 1.8, path=MED)
    text(c, "만나기 전에 꼭 볼 짧은 글을 맨 위에", 1490, 42, MUTED, t, 2.2, path=MED)
    return c


# ── 5 타임라인 거르기 — #선물 (FR-013 · TimelineRow) ─────────────────────────────────
ROWS = [("2025년 12월 19일", "연말 선물 — 디카페인 원두", "드립백 세트, 아주 좋아했음"),
        ("2024년 12월 20일", "연말 선물 — 머그컵", "하준이 그림 들어간 머그")]


def s_timeline(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "작년에 준 것은\n타임라인에서 #선물", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    on = t > 1.2
    d = ImageDraw.Draw(c)
    # 칩 줄
    x, cy = x0 + 10, 560
    for s_, sel in (("전체", not on), ("식사", False), ("기타", False), ("#선물", on)):
        w = d.textlength(s_, font=font(MED, 40)) + 60
        if sel:
            d.rounded_rectangle((x, cy - 40, x + w, cy + 40), radius=40, fill=MINT + (fa,), outline=ACCENT + (fa,), width=3)
        else:
            d.rounded_rectangle((x, cy - 40, x + w, cy + 40), radius=40, fill=CHIP_BG + (fa,))
        d.text((x + w / 2, cy), s_, font=font(MED, 40), fill=(ACCENT if sel else BODY) + (fa,), anchor="mm")
        if s_ == "#선물":
            tap_x = x + w / 2
        x += w + 16
    tap_ring(c, tap_x, cy, t, 0.8)
    d = ImageDraw.Draw(c)
    head = "타임라인 · 기록 2 / 9건" if on else "타임라인 · 기록 9건"
    d.text((x0 + 36, 700), head, font=font(MED, 40), fill=MUTED + (fa,), anchor="ls")
    b = ease((t - 1.35) / 0.35) * a if on else 0
    if b > 0:
        fb = round(255 * b)
        y0 = 730
        card(c, (x0, y0, x1, y0 + 2 * 310), b)
        d = ImageDraw.Draw(c)
        for k, (date, title, memo) in enumerate(ROWS):
            y = y0 + k * 310 + 20
            d.ellipse((x0 + 44, y + 44, x0 + 84, y + 84), outline=ACCENT + (fb,), width=4)
            d.text((x0 + 64, y + 64), "…", font=font(BOLD, 26), fill=ACCENT + (fb,), anchor="mm")
            d.text((x0 + 120, y + 64), date, font=font(MED, 36), fill=MUTED + (fb,), anchor="lm")
            d.text((x0 + 120, y + 128), title, font=font(BOLD, 46), fill=INK + (fb,), anchor="lm")
            d.text((x0 + 120, y + 194), memo, font=font(MED, 38), fill=BODY + (fb,), anchor="lm")
            d.text((x0 + 120, y + 252), "#선물", font=font(MED, 34), fill=ACCENT + (fb,), anchor="lm")
            chevron(d, x1 - 60, y + 130, MUTED + (fb,))
            if k == 0:
                d.line((x0 + 120, y + 290, x1, y + 290), fill=RULE + (fb,), width=2)
    text(c, "이 사람에게 쓰인 유형 · 태그만 칩으로 뜹니다", 1480, 42, MUTED, t, 2.4, path=MED)
    return c


# ── 6 다음에 이야기할 것 (TalkItemsSection · 견본 그대로) ──────────────────────────────
def s_talk(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "올해 물어볼 것도\n적어 두고", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 640
    d = ImageDraw.Draw(c)
    d.text((x0 + 36, y0 - 30), "다음에 이야기할 것 2", font=font(MED, 44), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 2 * 170), a)
    d = ImageDraw.Draw(c)
    for k, s_ in enumerate(["하준이 입학 선물 물어보기", "다음 분기 멘토링 주제 정하기"]):
        y = y0 + k * 170 + 85
        d.ellipse((x0 + 50, y - 28, x0 + 106, y + 28), outline=MUTED + (fa,), width=4)
        d.text((x0 + 140, y), s_, font=font(MED, 46), fill=INK + (fa,), anchor="lm")
        if k == 0:
            d.line((x0 + 140, y + 84, x1, y + 84), fill=RULE + (fa,), width=2)
    if t > 0.9:
        r = ease((t - 0.9) / 0.35)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle((x0 + 18, y0 + 8, x1 - 18, y0 + 162), radius=34, outline=ACCENT + (round(255 * r),), width=8)
        c.alpha_composite(layer)
    text(c, "만나면 묻고, 고르면 기록 한 줄", 1200, 50, ACCENT, t, 1.6, path=MED)
    return c


def s_msg(t):
    c = DARK_BG.convert("RGBA")
    text(c, "값보다 오래 남는 건", 620, 84, WHITE, t, 0.1)
    text(c, "기억해 준 마음", 750, 96, ACCENT_SOFT, t, 0.55)
    text(c, "작년과 다른, 그 사람에게 맞는 선물", 960, 52, GREY, t, 1.2, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "선물 고르기 전,\n그 사람 화면 한 번", 280, 66, INK, t, 0.1)
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
    return [
        (3.6, s_hook),
        (3.2, s_why),
        (2.4, s_reveal),
        (4.6, s_person),
        (4.8, s_timeline),
        (3.8, s_talk),
        (3.2, s_msg),
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
