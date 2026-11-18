#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 14 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 작년 그 냉면집, 누구랑 갔더라? (2026-11-18).

11-18 2회차 조회수 분석(`../promo-youtube-stats.md`)을 따른다 — 사람에 대한 질문 · 같은 이야기를 되풀이하지 않는다
(일정표 후보 `3년 만에 온 연락` 은 쇼츠 1 · 13 과 같은 이야기라, 아직 다루지 않은 **기록까지 찾는 검색** 으로 · 사용자 11-18).
**0초 장면에 질문 글이 이미 다 떠 있다** (`README.md` 문안 규칙).

앱 문구 그대로 다시 그렸다 (CI 스크린샷 `05-search.png` · `09-record-detail.png` 의 꼴):
- 사람 목록 아래 찾기 칸 — 안내 `이름 · 소속 · 메모 · 태그 · 초성`(`PeopleSearch.prompt`).
- 결과 줄의 근거 — `기록 '여름 냉면' 장소 일치`(`Core.SearchMatcher` — 기록의 제목 · 메모 · 장소 · 태그를 본다).
  빈칸으로 나눈 낱말은 **모두** 있어야 하고 낱말마다 다른 칸이어도 된다(`SearchQuery`). 초성은 모든 칸에서 된다(FR-036).
- 결과를 누르면 그 사람을 거쳐 **그 기록이 바로 열린다**(`PeopleListView.open(_:recordID:)` · FR-034).
- 기록 상세 — `식사 · 2025년 7월 12일` · 제목 · 장소 핀 · `함께한 사람` · `메모`(`RecordDetailView`) · 기록 유형 `식사`(`Presets`).
- 기록 쓰기의 `장소` 칸(`RecordEditView`).
사람은 모두 견본(`SampleData`)의 지어낸 이름이다 (CLAUDE.md §2).
  python3 make_search.py <repo> <out.mp4>          영상
  python3 make_search.py <repo> <out.png> <초>     그 초의 한 장
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
from PIL import Image, ImageDraw  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
CARD, RULE, MUTED, BODY, MINT, DARK_CARD = mq.CARD, mq.RULE, mq.MUTED, mq.BODY, mq.MINT, mq.DARK_CARD
CHIP_BG = (236, 240, 241)
card, tap_ring = mq.card, mq.tap_ring
SHOWN = -1.0   # 이미 지난 시각 — 0초부터 다 떠 있는 글


def chevron(d, x, y, color):
    d.line((x - 8, y - 14, x + 6, y, x - 8, y + 14), fill=color, width=5)


def magnifier(d, x, y, color, s=1.0):
    r = 20 * s
    d.ellipse((x - r, y - r, x + r, y + r), outline=color, width=round(5 * s))
    d.line((x + r * 0.7, y + r * 0.7, x + r * 1.6, y + r * 1.6), fill=color, width=round(6 * s))


def pin(d, x, y, color):
    d.ellipse((x - 11, y - 30, x + 11, y - 8), fill=color)
    d.line((x, y - 10, x, y + 26), fill=color, width=5)


def fork_knife(d, x, y, color):
    """SF Symbols `fork.knife` 를 선으로."""
    d.line((x - 12, y - 20, x - 12, y + 20), fill=color, width=4)
    for dx in (-20, -12, -4):
        d.line((x + dx, y - 20, x + dx, y - 6), fill=color, width=3)
    d.line((x - 20, y - 6, x - 4, y - 6), fill=color, width=3)
    d.line((x + 12, y - 20, x + 12, y + 20), fill=color, width=4)
    d.pieslice((x + 4, y - 22, x + 20, y + 2), 270, 90, fill=color)


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 흐린 기억 카드 ─────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "작년 그 냉면집,", 300, 70, GREY, t, SHOWN, path=MED)
    text(c, "누구랑\n갔더라?", 420, 120, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pulse = 0.55 + 0.25 * (0.5 + 0.5 * __import__("math").sin(t * 3.2))
    x0, x1, y = 150, W - 150, 960
    d.rounded_rectangle((x0, y, x1, y + 420), radius=48, fill=DARK_CARD + (255,))
    fork_knife(d, x0 + 80, y + 90, ACCENT_SOFT + (255,))
    d.text((x0 + 130, y + 90), "을지로 냉면집", font=font(BOLD, 52), fill=(232, 236, 238, 255), anchor="lm")
    d.text((x0 + 130, y + 160), "작년 여름", font=font(MED, 40), fill=(150, 158, 165, 255), anchor="lm")
    a = round(255 * pulse)
    for k in range(3):
        cx = x0 + 120 + k * 150
        d.ellipse((cx - 55, y + 245, cx + 55, y + 355), outline=(150, 158, 165, a), width=4)
        d.text((cx, y + 300), "?", font=font(BOLD, 56), fill=(170, 178, 184, a), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "장소는 또렷한데", 560, 84, WHITE, t, 0.1)
    text(c, "함께한 사람이 흐려져요", 700, 88, ACCENT_SOFT, t, 0.55)
    text(c, "사진첩을 한참 넘기다 포기한 적, 있죠", 900, 52, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "사람뿐 아니라 기록까지 찾습니다", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 찾기 — 사람 목록 아래 찾기 칸 (PeopleListView · SearchMatcher 문구 그대로) ───────────
HITS = [("박", "박서연", "마루디자인 · 대표"), ("정", "정유진", "청림소프트 · 주니어 개발자")]


def search_bar(c, t, query, a, y=1640):
    fa = round(255 * a)
    x0, x1 = 90, W - 90
    card(c, (x0, y, x1, y + 130), a, radius=65)
    d = ImageDraw.Draw(c)
    magnifier(d, x0 + 70, y + 60, INK + (fa,), 1.0)
    if query:
        d.text((x0 + 130, y + 65), query, font=font(MED, 50), fill=INK + (fa,), anchor="lm")
        w = d.textlength(query, font=font(MED, 50))
        if int(t * 2.2) % 2 == 0:
            d.line((x0 + 136 + w, y + 35, x0 + 136 + w, y + 95), fill=ACCENT + (fa,), width=4)
        d.ellipse((x1 - 95, y + 40, x1 - 45, y + 90), fill=INK + (fa,))
        d.text((x1 - 70, y + 64), "×", font=font(BOLD, 36), fill=(255, 255, 255, fa), anchor="mm")
    else:
        d.text((x0 + 130, y + 65), "이름 · 소속 · 메모 · 태그 · 초성", font=font(MED, 44), fill=MUTED + (fa,), anchor="lm")


def result_rows(c, t, a, evidence, t0, y0=560):
    x0, x1 = 60, W - 60
    b = ease((t - t0) / 0.35) * a
    if b <= 0:
        return
    fb = round(255 * b)
    d = ImageDraw.Draw(c)
    d.text((x0 + 36, y0 - 26), f"{len(HITS)}명", font=font(MED, 44), fill=MUTED + (fb,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 2 * 220), b)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (initial, name, sub) in enumerate(HITS):
        y = y0 + k * 220
        d.ellipse((x0 + 40, y + 60, x0 + 140, y + 160), fill=MINT + (fb,))
        d.text((x0 + 90, y + 110), initial, font=font(BOLD, 44), fill=ACCENT + (fb,), anchor="mm")
        d.text((x0 + 175, y + 56), name, font=font(BOLD, 50), fill=INK + (fb,), anchor="lm")
        d.text((x0 + 175, y + 112), sub, font=font(MED, 38), fill=MUTED + (fb,), anchor="lm")
        d.text((x0 + 175, y + 166), evidence, font=font(MED, 38), fill=ACCENT + (fb,), anchor="lm")
        chevron(d, x1 - 60, y + 110, MUTED + (fb,))
        if k == 0:
            d.line((x0 + 175, y + 219, x1, y + 219), fill=RULE + (fb,), width=2)
    c.alpha_composite(layer)


def s_search(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "장소만 쳐도", 150, 96, INK, t, 0.05)
    a = ease((t - 0.2) / 0.35)
    if a <= 0:
        return c
    query = "을지로"[:max(0, min(3, round((t - 0.7) * 6)))]
    search_bar(c, t, query, a)
    result_rows(c, t, a, "기록 '여름 냉면' 장소 일치", 1.35)
    text(c, "그날 함께한 사람이 나옵니다", 1110, 54, ACCENT, t, 1.8, path=MED)
    text(c, "제목 · 메모 · 장소 · 태그 · 초성까지", 1220, 46, MUTED, t, 2.3, path=MED)
    return c


# ── 5 누르면 그 기록으로 바로 (RecordDetailView 꼴 그대로) ─────────────────────────────
def s_open(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "누르면 그 기록으로\n바로 갑니다", 130, 84, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 560
    card(c, (x0, y0, x1, y0 + 300), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fork_knife(d, x0 + 70, y0 + 70, ACCENT + (fa,))
    d.text((x0 + 110, y0 + 70), "식사", font=font(MED, 40), fill=ACCENT + (fa,), anchor="lm")
    d.text((x0 + 210, y0 + 70), "·  2025년 7월 12일", font=font(MED, 40), fill=MUTED + (fa,), anchor="lm")
    d.text((x0 + 44, y0 + 155), "여름 냉면", font=font(BOLD, 64), fill=INK + (fa,), anchor="lm")
    pin(d, x0 + 64, y0 + 240, INK + (fa,))
    d.text((x0 + 120, y0 + 240), "을지로 3가", font=font(MED, 44), fill=BODY + (fa,), anchor="lm")
    c.alpha_composite(layer)
    b = ease((t - 0.9) / 0.35)
    if b > 0:
        fb = round(255 * b)
        y1 = y0 + 400
        d = ImageDraw.Draw(c)
        d.text((x0 + 36, y1 - 24), "함께한 사람", font=font(MED, 40), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y1, x1, y1 + 360), b)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for k, (_, name, sub) in enumerate(HITS):
            y = y1 + k * 180
            d.text((x0 + 44, y + 64), name, font=font(BOLD, 50), fill=INK + (fb,), anchor="lm")
            d.text((x0 + 44, y + 122), sub, font=font(MED, 38), fill=MUTED + (fb,), anchor="lm")
            chevron(d, x1 - 60, y + 90, MUTED + (fb,))
            if k == 0:
                d.line((x0 + 44, y + 179, x1, y + 179), fill=RULE + (fb,), width=2)
        c.alpha_composite(layer)
    e = ease((t - 1.6) / 0.35)
    if e > 0:
        fe = round(255 * e)
        y2 = y0 + 860
        d = ImageDraw.Draw(c)
        d.text((x0 + 36, y2 - 24), "메모", font=font(MED, 40), fill=MUTED + (fe,), anchor="ls")
        card(c, (x0, y2, x1, y2 + 130), e)
        d = ImageDraw.Draw(c)
        d.text((x0 + 44, y2 + 65), "다음엔 수육도. 서연 님 단골집", font=font(MED, 46), fill=INK + (fe,), anchor="lm")
    return c


# ── 6 낱말을 더하면 더 좁게 — 초성도 ────────────────────────────────────────────────
def s_more(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "낱말을 더하면 더 좁게,\n초성만 쳐도", 150, 80, INK, t, 0.05)
    a = ease((t - 0.2) / 0.35)
    if a <= 0:
        return c
    rows = [("을지로 냉면", "장소 · 제목 — 둘 다 있는 기록만"), ("ㅇㅈㄹ", "초성은 모든 칸에서")]
    for k, (q, note) in enumerate(rows):
        b = ease((t - 0.4 - k * 0.9) / 0.35) * a
        if b <= 0:
            continue
        y = 640 + k * 380
        search_bar(c, t if k == 1 else 0.5, q, b, y=y)
        d = ImageDraw.Draw(c)
        d.text((W / 2, y + 210), note, font=font(MED, 46), fill=ACCENT + (round(255 * b),), anchor="mm")
    return c


# ── 7 기록할 때 장소 한 칸 (RecordEditView) ────────────────────────────────────────
def s_tip(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "기록할 때\n장소 한 칸만", 150, 92, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 640
    d = ImageDraw.Draw(c)
    d.text((x0 + 36, y0 - 24), "장소", font=font(MED, 40), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 130), a)
    d = ImageDraw.Draw(c)
    typed = "을지로 3가"[:max(0, min(6, round((t - 0.8) * 7)))]
    d.text((x0 + 44, y0 + 65), typed or "장소", font=font(MED, 48), fill=(INK if typed else MUTED) + (fa,), anchor="lm")
    text(c, "몇 년 뒤의 나에게 남기는 단서", 1000, 56, ACCENT, t, 1.7, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "그날 누구와 있었는지,\n찾으면 나오는 인연 기록", 280, 70, INK, t, 0.1)
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
        (4.6, s_search),
        (4.0, s_open),
        (3.6, s_more),
        (3.4, s_tip),
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
