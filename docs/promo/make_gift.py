#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 15 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 올해 축의금 · 조의금, 누구에게 얼마 냈는지 기억나요? (2026-11-21).

11-20 결정 — 채널 하나 유지 · 여백 · 인연에 **돈 · 시간 다리** 2주 시험(`../promo-youtube-stats.md`). 첫 물음에 돈.
**0초 장면에 질문 글이 이미 다 떠 있다** (`README.md` 문안 규칙).

**금액 칸은 없다** — 기록 메모에 한 줄 적고 태그로 모아 찾는 것까지만 보인다(없는 기능을 팔지 않는다 · CLAUDE.md §7).
앱 문구 그대로 다시 그렸다:
- 기록 쓰기(`RecordEditView`) — 기록 유형 칩(`기타` · Presets) · `제목` · `함께한 일이나 나눈 이야기`(메모) · `태그`.
- 찾기 칸 안내 `이름 · 소속 · 메모 · 태그 · 초성`(`PeopleSearch.prompt`) · `#경조사` 처럼 `#` 을 붙이면 태그만 본다(`SearchQuery`).
- 결과 줄 근거 `기록 '박서연 결혼식' 태그 #경조사 일치`(`Core.SearchMatcher`) · 누르면 그 기록(`PeopleListView.open(_:recordID:)`).
- 기록 상세 — 유형 · 날짜 · 제목 · `함께한 사람` · `메모` · `태그`(`RecordDetailView`, screenshots/09 의 꼴).
사람은 모두 견본(`SampleData`)의 지어낸 이름이다 (CLAUDE.md §2).
  python3 make_gift.py <repo> <out.mp4>          영상
  python3 make_gift.py <repo> <out.png> <초>     그 초의 한 장
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


def envelope(d, x, y, w, h, fill, line, label, amount, a=255):
    d.rounded_rectangle((x, y, x + w, y + h), radius=22, fill=fill + (a,))
    d.line((x + 10, y + 12, x + w / 2, y + h * 0.42, x + w - 10, y + 12), fill=line + (a,), width=4)
    d.text((x + w / 2, y + h * 0.66), label, font=font(BOLD, 34), fill=(232, 236, 238, a), anchor="mm")
    d.text((x + w / 2, y + h + 46), amount, font=font(BOLD, 40), fill=(170, 178, 184, a), anchor="mm")


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 봉투 셋, 금액은 물음표 ─────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "올해 축의금 · 조의금,", 300, 66, GREY, t, SHOWN, path=MED)
    text(c, "누구에게 얼마\n냈는지 기억나요?", 420, 104, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pulse = 0.55 + 0.25 * (0.5 + 0.5 * __import__("math").sin(t * 3.2))
    a = round(255 * pulse)
    w, h, gap = 250, 170, 50
    x0 = (W - (3 * w + 2 * gap)) / 2
    for k, label in enumerate(["결혼식", "조문", "돌잔치"]):
        x = x0 + k * (w + gap)
        envelope(d, x, 1000, w, h, DARK_CARD, (110, 120, 128), label, "?", a if k != 1 else round(a * 0.9))
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "받을 때가 되면", 560, 84, WHITE, t, 0.1)
    text(c, "그때 얼마였더라?", 690, 92, ACCENT_SOFT, t, 0.55)
    text(c, "주고받은 마음, 금액까지 기억하긴 어려워요", 900, 50, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "그 자리에 한 줄, 태그로 모아 둡니다", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 기록 쓰기 — 메모에 한 줄 · 태그 #경조사 (RecordEditView 그대로) ─────────────────
def s_write(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "기록 메모에 한 줄,\n태그는 #경조사", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    # 기록 유형 — 기타
    y0 = 560
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "기록 유형", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 120), a)
    d = ImageDraw.Draw(c)
    x = x0 + 40
    for s, on in (("대화", False), ("식사", False), ("친목", False), ("기타", True)):
        w = d.textlength(s, font=font(MED, 40)) + 60
        if on:
            d.rounded_rectangle((x, y0 + 20, x + w, y0 + 100), radius=40, fill=MINT + (fa,), outline=ACCENT + (fa,), width=3)
        else:
            d.rounded_rectangle((x, y0 + 20, x + w, y0 + 100), radius=40, fill=CHIP_BG + (fa,))
        d.text((x + w / 2, y0 + 60), s, font=font(MED, 40), fill=(ACCENT if on else BODY) + (fa,), anchor="mm")
        x += w + 16
    # 제목 · 메모
    y1 = y0 + 190
    card(c, (x0, y1, x1, y1 + 260), a)
    d = ImageDraw.Draw(c)
    d.text((x0 + 44, y1 + 65), "박서연 결혼식", font=font(BOLD, 48), fill=INK + (fa,), anchor="lm")
    d.line((x0 + 44, y1 + 130, x1, y1 + 130), fill=RULE + (fa,), width=2)
    memo = "축의 10만원 · 식사까지 함께"
    typed = memo[:max(0, min(len(memo), round((t - 0.9) * 12)))]
    d.text((x0 + 44, y1 + 195), typed or "함께한 일이나 나눈 이야기", font=font(MED, 46),
           fill=(INK if typed else MUTED) + (fa,), anchor="lm")
    # 태그
    y2 = y1 + 340
    d.text((x0 + 30, y2 - 22), "태그", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y2, x1, y2 + 120), a)
    b = ease((t - 2.6) / 0.3)
    if b > 0:
        fb = round(255 * min(a, b))
        d = ImageDraw.Draw(c)
        w = d.textlength("#경조사", font=font(BOLD, 42)) + 60
        d.rounded_rectangle((x0 + 40, y2 + 20, x0 + 40 + w, y2 + 100), radius=40, fill=MINT + (fb,))
        d.text((x0 + 40 + w / 2, y2 + 60), "#경조사", font=font(BOLD, 42), fill=ACCENT + (fb,), anchor="mm")
    text(c, "금액 칸은 없어요 — 메모 한 줄이면 충분합니다", 1500, 46, MUTED, t, 3.0, path=MED)
    return c


# ── 5 #경조사 로 모아 찾기 (SearchMatcher 근거 그대로) ────────────────────────────────
HITS = [("박", "박서연", "기록 '박서연 결혼식' 태그 #경조사 일치"),
        ("이", "이도윤", "기록 '이도윤 님 조문' 태그 #경조사 일치"),
        ("정", "정유진", "기록 '정유진 님 아이 돌잔치' 태그 #경조사 일치")]


def s_find(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "#경조사 하나로\n올해의 자리가 모입니다", 150, 82, INK, t, 0.05)
    a = ease((t - 0.2) / 0.35)
    if a <= 0:
        return c
    q = "#경조사"[:max(0, min(4, round((t - 0.7) * 6)))]
    search_bar(c, t, q, a)
    b = ease((t - 1.5) / 0.35) * a
    if b > 0:
        fb = round(255 * b)
        x0, x1, y0 = 60, W - 60, 620
        d = ImageDraw.Draw(c)
        d.text((x0 + 36, y0 - 26), f"{len(HITS)}명", font=font(MED, 44), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y0, x1, y0 + 3 * 210), b)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for k, (initial, name, ev) in enumerate(HITS):
            y = y0 + k * 210
            d.ellipse((x0 + 40, y + 55, x0 + 140, y + 155), fill=MINT + (fb,))
            d.text((x0 + 90, y + 105), initial, font=font(BOLD, 44), fill=ACCENT + (fb,), anchor="mm")
            d.text((x0 + 175, y + 70), name, font=font(BOLD, 50), fill=INK + (fb,), anchor="lm")
            d.text((x0 + 175, y + 140), ev, font=font(MED, 36), fill=ACCENT + (fb,), anchor="lm")
            chevron(d, x1 - 60, y + 105, MUTED + (fb,))
            if k < 2:
                d.line((x0 + 175, y + 209, x1, y + 209), fill=RULE + (fb,), width=2)
        c.alpha_composite(layer)
        tap_ring(c, 400, y0 + 105, t, 3.2)
    return c


# ── 6 누르면 그 기록 — 얼마였는지까지 (RecordDetailView 꼴) ────────────────────────────
def s_open(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "누르면 그 기록으로 —\n얼마였는지까지", 130, 84, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 560
    card(c, (x0, y0, x1, y0 + 240), a)
    d = ImageDraw.Draw(c)
    d.ellipse((x0 + 44, y0 + 50, x0 + 84, y0 + 90), outline=ACCENT + (fa,), width=4)
    d.text((x0 + 64, y0 + 70), "…", font=font(BOLD, 26), fill=ACCENT + (fa,), anchor="mm")
    d.text((x0 + 104, y0 + 70), "기타", font=font(MED, 40), fill=ACCENT + (fa,), anchor="lm")
    d.text((x0 + 200, y0 + 70), "·  2026년 5월 16일", font=font(MED, 40), fill=MUTED + (fa,), anchor="lm")
    d.text((x0 + 44, y0 + 165), "박서연 결혼식", font=font(BOLD, 64), fill=INK + (fa,), anchor="lm")
    b = ease((t - 0.8) / 0.35)
    if b > 0:
        fb = round(255 * b)
        y1 = y0 + 340
        d = ImageDraw.Draw(c)
        d.text((x0 + 36, y1 - 24), "함께한 사람", font=font(MED, 40), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y1, x1, y1 + 180), b)
        d = ImageDraw.Draw(c)
        d.text((x0 + 44, y1 + 64), "박서연", font=font(BOLD, 50), fill=INK + (fb,), anchor="lm")
        d.text((x0 + 44, y1 + 122), "마루디자인 · 대표", font=font(MED, 38), fill=MUTED + (fb,), anchor="lm")
        chevron(d, x1 - 60, y1 + 90, MUTED + (fb,))
    e = ease((t - 1.4) / 0.35)
    if e > 0:
        fe = round(255 * e)
        y2 = y0 + 620
        d = ImageDraw.Draw(c)
        d.text((x0 + 36, y2 - 24), "메모", font=font(MED, 40), fill=MUTED + (fe,), anchor="ls")
        card(c, (x0, y2, x1, y2 + 130), e)
        d = ImageDraw.Draw(c)
        d.text((x0 + 44, y2 + 65), "축의 10만원 · 식사까지 함께", font=font(BOLD, 48), fill=INK + (fe,), anchor="lm")
        y3 = y2 + 230
        d.text((x0 + 36, y3 - 24), "태그", font=font(MED, 40), fill=MUTED + (fe,), anchor="ls")
        card(c, (x0, y3, x1, y3 + 120), e)
        d = ImageDraw.Draw(c)
        w = d.textlength("#경조사", font=font(MED, 40)) + 56
        d.rounded_rectangle((x0 + 40, y3 + 22, x0 + 40 + w, y3 + 98), radius=38, fill=CHIP_BG + (fe,))
        d.text((x0 + 40 + w / 2, y3 + 60), "#경조사", font=font(MED, 40), fill=BODY + (fe,), anchor="mm")
    return c


def s_msg(t):
    c = DARK_BG.convert("RGBA")
    text(c, "주고받은 마음을", 620, 84, WHITE, t, 0.1)
    text(c, "잊지 않게 적어 두는 일", 750, 88, ACCENT_SOFT, t, 0.55)
    text(c, "다음에 받을 때도, 다음에 건넬 때도", 960, 52, GREY, t, 1.2, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "그 자리에 한 줄,\n주고받은 마음까지 기억하는 법", 280, 66, INK, t, 0.1)
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
    return [
        (3.6, s_hook),
        (3.2, s_why),
        (2.4, s_reveal),
        (4.6, s_write),
        (4.4, s_find),
        (3.8, s_open),
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
