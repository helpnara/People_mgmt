#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 9 (1080 × 1920 · 30fps · 약 28초) — 컨셉: 명함 30장, 누가 누군지 기억나요? (2026-11-09).

조회수 1회차(`../promo-youtube-stats.md`)에서 가장 잘된 쇼츠 1(첫 인연 · 어떻게 알게 되었는지)의 주제를
**숫자 하나 + 질문** 으로 다시 연다. 1.1.9 의 명함 여러 장 등록(이슈 103)으로 이어 첫 인연 · 검색까지 간다.

앞 쇼츠들(make_short.py · make_record.py · make_brief.py)의 그리기 도구를 쓴다. 앱 화면은
- `52-card-batch.png` — 명함 여러 장 등록 (CI 의 `-cardBatch` 견본 명함 세 장: 한서연 · 오지훈 · 남궁별)
- 나머지는 앱 문구 그대로 다시 그렸다: `CardBatchView.commonSections`(모두에게 · 알게 된 경로 칩과 바닥글 · 처음 만난 날 넣기 ·
  `n명 저장`), `PersonDetailView.firstEncounterSection`(첫 인연 · 날짜 · 메모), `SearchMatcher`(`알게 된 경로 일치`).
사람 · 소속 · 행사는 모두 지어낸 견본이다 (CLAUDE.md §2).
  python3 make_cards.py <repo> <out.mp4>          영상
  python3 make_cards.py <repo> <out.png> <초>     그 초의 한 장
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
CHIP = (233, 236, 238)
MINT = (226, 240, 235)
PAPER = (250, 248, 243)

EVENT = "2026 북페어"
PEOPLE = [("한서연", "솔빛출판 · 편집장"), ("오지훈", "다올건축사무소 · 실장"), ("남궁별", "푸른숲협동조합 · 사무국장")]


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def card(c, box, a, radius=44):
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 20, x1, y1 + 20), radius=radius, fill=(20, 24, 29, round(50 * a)))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(28)))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=CARD + (round(255 * a),))
    c.alpha_composite(layer)


def tap_ring(c, cx, cy, t, t0):
    p = ease((t - t0) / 0.3)
    if 0 < p < 1:
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rr = 36 + 60 * p
        ImageDraw.Draw(ring).ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=ACCENT + (round(170 * (1 - p)),), width=8)
        c.alpha_composite(ring)


def chip(d, x, y, s, f, selected, al):
    w = d.textlength(s, font=f) + 64
    if selected:
        d.rounded_rectangle((x, y, x + w, y + 84), radius=42, fill=MINT + (al,), outline=ACCENT + (al,), width=4)
        d.text((x + w / 2, y + 42), s, font=f, fill=ACCENT + (al,), anchor="mm")
    else:
        d.rounded_rectangle((x, y, x + w, y + 84), radius=42, fill=CHIP + (al,))
        d.text((x + w / 2, y + 42), s, font=f, fill=BODY + (al,), anchor="mm")
    return w


def biz_card(size, name=None, org=None, role=None, phone=None):
    """명함 한 장 (지어낸 견본). 이름이 없으면 글 대신 회색 줄."""
    cw, ch = size
    im = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, cw - 1, ch - 1), radius=18, fill=PAPER + (255,), outline=(214, 218, 214, 255), width=2)
    d.rectangle((0, 18, 7, ch - 18), fill=ACCENT + (255,))
    s = cw / 600
    if name:
        d.text((40 * s, 34 * s), org, font=font(MED, round(24 * s)), fill=ACCENT + (255,))
        d.text((40 * s, 86 * s), name, font=font(BOLD, round(54 * s)), fill=INK + (255,))
        d.text((40 * s, 156 * s), role, font=font(MED, round(26 * s)), fill=MUTED + (255,))
        d.text((40 * s, ch - 70 * s), phone, font=font(MED, round(26 * s)), fill=BODY + (255,))
    else:
        for y, w in ((40, 140), (92, 230), (160, 120), (ch / s - 76, 200)):
            d.rounded_rectangle((40 * s, y * s, (40 + w) * s, (y + 22) * s), radius=round(10 * s), fill=(206, 210, 206, 255))
    return im


# ── 1 첫 장면 — 숫자 하나 + 질문 ───────────────────────────────────────────────
BLANK = biz_card((420, 250))
FAN = [(-16, -250, 40), (-7, -120, 10), (3, 0, 0), (11, 130, 20), (19, 255, 50)]


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "지난 행사에서 받은 명함", 300, 58, GREY, t, 0.05, path=MED)
    text(c, "30장", 400, 230, ACCENT_SOFT, t, 0.35)
    text(c, "누가 누군지\n기억나요?", 780, 104, WHITE, t, 0.95)
    for k, (deg, dx, dy) in enumerate(FAN):
        a = ease((t - 0.5 - k * 0.12) / 0.4)
        if a <= 0:
            continue
        im = BLANK.rotate(-deg, resample=Image.BICUBIC, expand=True)
        im.putalpha(im.getchannel("A").point(lambda v: round(v * a)))
        x = W // 2 + dx - im.width // 2
        y = 1300 + dy + round((1 - a) * 60) - im.height // 2
        c.alpha_composite(im, (x, y))
    return c


SAMPLE = biz_card((600, 340), "한서연", "솔빛출판", "편집장", "M. 010-5555-0101")
QUESTIONS = ["어디서 만났더라?", "무슨 이야기를 나눴지?", "왜 연락하려 했더라?"]


def s_problem(t):
    c = DARK_BG.convert("RGBA")
    text(c, "명함엔\n이름과 번호뿐", 260, 100, WHITE, t, 0.1)
    a = ease((t - 0.3) / 0.4)
    if a > 0:
        im = SAMPLE.copy()
        im.putalpha(im.getchannel("A").point(lambda v: round(v * a)))
        c.alpha_composite(im, ((W - im.width) // 2, 640 + round((1 - a) * 40)))
    for i, q in enumerate(QUESTIONS):
        text(c, q, 1150 + i * 96, 54, GREY, t, 0.8 + i * 0.5, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "명함 대신, 인연을 남깁니다", 1040, 64, ACCENT, t, 0.8, path=MED)
    return c


# ── 5 모두에게 한 번에 — CardBatchView.commonSections 문구 그대로 ─────────────
PATHS = ["직장", "프로젝트", "행사·교육", "학교", "온라인", "가족·친척", "동호회·모임"]


def s_common(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "어디서 만났는지,\n세 명에게 한 번에", 110, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    picked = t > 1.05
    typed = EVENT[:max(0, min(len(EVENT), int((t - 1.25) / 0.09)))] if picked else ""
    # 알게 된 경로
    y0 = 470
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "모두에게 · 알게 된 경로", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    field_h = 120 if picked else 0
    card(c, (x0, y0, x1, y0 + 370 + field_h), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(MED, 40)
    x, y = x0 + 40, y0 + 40
    custom_at = None
    for s in PATHS + ["직접 입력"]:
        w = d.textlength(s, font=f) + 64
        if x + w > x1 - 40:
            x, y = x0 + 40, y + 104
        if s == "직접 입력":
            custom_at = (x + w / 2, y + 42)
        chip(d, x, y, s, f, s == "직접 입력" and picked, fa)
        x += w + 20
    if picked:
        fy = y + 140
        d.text((x0 + 50, fy), typed if typed else "직접 입력", font=font(MED, 46),
               fill=(INK if typed else FAINT) + (fa,), anchor="lm")
        if len(typed) < len(EVENT) or (t * 2) % 1 < 0.6:   # 쓰는 동안은 늘, 다 쓰면 깜빡
            cx = x0 + 52 + d.textlength(typed, font=font(MED, 46))
            d.line((cx, fy - 30, cx, fy + 30), fill=ACCENT + (fa,), width=4)
        d.line((x0 + 50, fy + 50, x1 - 50, fy + 50), fill=RULE + (fa,), width=2)
    c.alpha_composite(layer)
    tap_ring(c, custom_at[0], custom_at[1], t, 0.85)
    yb = y0 + 370 + field_h + 30
    text(c, "행사 · 모임 이름을 직접 적어 두면 나중에\n같은 자리에서 만난 사람을 함께 찾을 수 있습니다.",
         yb, 33, MUTED, t, 0.4, path=MED, rise=0)
    # 처음 만난 날
    b = ease((t - 2.3) / 0.35)
    if b > 0:
        y2 = yb + 180
        fb = round(255 * b)
        d = ImageDraw.Draw(c)
        d.text((x0 + 30, y2 - 22), "모두에게 · 처음 만난 날", font=font(MED, 38), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y2, x1, y2 + 250), b)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.text((x0 + 50, y2 + 64), "처음 만난 날 넣기", font=font(MED, 46), fill=INK + (fb,), anchor="lm")
        tx = x1 - 50 - 130
        d.rounded_rectangle((tx, y2 + 24, tx + 130, y2 + 104), radius=40, fill=ACCENT + (fb,))
        d.ellipse((tx + 56, y2 + 30, tx + 124, y2 + 98), fill=(255, 255, 255, fb))
        d.line((x0 + 50, y2 + 128, x1, y2 + 128), fill=RULE + (fb,), width=2)
        d.text((x0 + 50, y2 + 190), "처음 만난 날", font=font(MED, 46), fill=INK + (fb,), anchor="lm")
        dv = "2026년 10월 24일"
        dw = d.textlength(dv, font=font(MED, 42)) + 50
        d.rounded_rectangle((x1 - 50 - dw, y2 + 150, x1 - 50, y2 + 230), radius=20, fill=CHIP + (fb,))
        d.text((x1 - 50 - dw / 2, y2 + 190), dv, font=font(MED, 42), fill=INK + (fb,), anchor="mm")
        c.alpha_composite(layer)
    # n명 저장
    e = ease((t - 3.0) / 0.35)
    if e > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        by = 1460 + round((1 - e) * 30)
        d.rounded_rectangle((x0, by, x1, by + 150), radius=75, fill=ACCENT + (round(255 * e),))
        d.text((W / 2, by + 75), "3명 저장", font=font(BOLD, 56), fill=(255, 255, 255, round(255 * e)), anchor="mm")
        c.alpha_composite(layer)
        tap_ring(c, W / 2, 1535, t, 3.7)
    return c


# ── 6 첫 인연 — PersonDetailView 의 머리 · 첫 인연 칸 ───────────────────────────
NOTE = "북페어 점심 줄에서 같은 세션을\n들은 걸 알고 말을 텄다. 다음 책\n표지 이야기를 나누기로."


def s_first(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "몇 년이 지나도\n어떻게 알게 되었는지", 150, 84, INK, t, 0.05)
    a = ease((t - 0.2) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 500
    card(c, (x0, y0, x1, y0 + 400), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((x0 + 44, y0 + 44, x0 + 194, y0 + 194), fill=MINT + (fa,))
    d.text((x0 + 119, y0 + 119), "한", font=font(BOLD, 64), fill=ACCENT + (fa,), anchor="mm")
    d.text((x0 + 230, y0 + 119), "한서연", font=font(BOLD, 72), fill=INK + (fa,), anchor="lm")
    d.text((x0 + 44, y0 + 250), "솔빛출판 · 편집장", font=font(MED, 42), fill=BODY + (fa,), anchor="lm")
    f = font(MED, 40)
    w = chip(d, x0 + 44, y0 + 296, "협력사", f, True, fa)
    chip(d, x0 + 64 + w, y0 + 296, EVENT, f, False, fa)
    c.alpha_composite(layer)
    # 첫 인연 칸 — 조금 늦게 떠오르며 테두리로 눈길
    b = ease((t - 0.9) / 0.4)
    if b > 0:
        fb = round(255 * b)
        y2 = 1010 + round((1 - b) * 30)
        d = ImageDraw.Draw(c)
        d.text((x0 + 30, y2 - 22), "첫 인연", font=font(MED, 40), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y2, x1, y2 + 400), b)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle((x0, y2, x1, y2 + 400), radius=44, outline=ACCENT + (round(fb * ease((t - 1.5) / 0.4)),), width=5)
        d.text((x0 + 50, y2 + 50), "2026년 10월 24일", font=font(MED, 40), fill=MUTED + (fb,))
        d.multiline_text((x0 + 50, y2 + 120), NOTE, font=font(MED, 48), fill=INK + (fb,), spacing=16)
        c.alpha_composite(layer)
    return c


# ── 7 한 단어로 찾기 — SearchMatcher 의 근거 문구 그대로 ────────────────────────
def s_search(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "한 단어만 기억나도", 150, 86, INK, t, 0.05)
    a = ease((t - 0.2) / 0.3)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    word = "북페어"
    typed = word[:max(0, min(len(word), int((t - 0.45) / 0.18) + 1))] if t > 0.45 else ""
    # 찾기 칸
    sy = 330
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x0, sy, x1, sy + 130), radius=65, fill=CARD + (fa,), outline=RULE + (fa,), width=2)
    d.ellipse((x0 + 50, sy + 38, x0 + 92, sy + 80), outline=INK + (fa,), width=6)
    d.line((x0 + 86, sy + 74, x0 + 108, sy + 96), fill=INK + (fa,), width=7)
    d.text((x0 + 140, sy + 65), typed if typed else "찾기", font=font(MED, 52),
           fill=(INK if typed else FAINT) + (fa,), anchor="lm")
    c.alpha_composite(layer)
    b = ease((t - 1.1) / 0.3)
    if b <= 0:
        return c
    y0 = 590
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "3명", font=font(BOLD, 42), fill=MUTED + (round(255 * b),), anchor="ls")
    row_h = 240
    card(c, (x0, y0, x1, y0 + row_h * 3), b)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (name, org) in enumerate(PEOPLE):
        r = ease((t - 1.2 - k * 0.2) / 0.3)
        if r <= 0:
            continue
        ra = round(255 * r)
        y = y0 + k * row_h
        cy = y + row_h / 2
        d.ellipse((x0 + 40, cy - 60, x0 + 160, cy + 60), fill=MINT + (ra,))
        d.text((x0 + 100, cy), name[0], font=font(BOLD, 52), fill=ACCENT + (ra,), anchor="mm")
        d.text((x0 + 200, cy - 62), name, font=font(BOLD, 52), fill=INK + (ra,), anchor="lm")
        d.text((x0 + 200, cy + 2), org, font=font(MED, 40), fill=MUTED + (ra,), anchor="lm")
        d.text((x0 + 200, cy + 62), "알게 된 경로 일치", font=font(MED, 40), fill=ACCENT + (ra,), anchor="lm")
        d.line((x1 - 70, cy - 22, x1 - 48, cy, x1 - 70, cy + 22), fill=FAINT + (ra,), width=5)
        if k < 2:
            d.line((x0 + 200, y + row_h, x1, y + row_h), fill=RULE + (ra,), width=2)
    c.alpha_composite(layer)
    text(c, "그날 만난 세 사람이 함께", 1400, 56, ACCENT, t, 2.0, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "명함은 서랍에,\n인연은 여기에", 300, 88, INK, t, 0.1)
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


BATCH = shot("52-card-batch.png")


def scenes():
    return [
        (3.4, s_hook),
        (3.0, s_problem),
        (2.4, s_reveal),
        # 명함 여러 장 등록 — 사진첩에서 고르기 · 명함 3장 줄 (스크린샷 52)
        (3.6, mr.card_closeup(BATCH, "명함 여러 장,\n한 번에 읽고", 0.19, 0.60)),
        (4.6, s_common),
        (3.8, s_first),
        (3.8, s_search),
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
