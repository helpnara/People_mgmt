#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 12 (1080 × 1920 · 30fps · 약 33초) — 컨셉: 지금 가까운 그 사람, 처음엔 누구 소개였나요? (2026-11-17).

가장 잘된 쇼츠 1(어떻게 알게 되었는지)과 같은 결의 질문으로 연다. **0초 장면에 질문 글이 이미 다 떠 있다**
(2026-11-17 사용자 · `README.md` 문안 규칙). 1.1.12 까지 출시된 기능만 쓴다 — 알게 된 경로 `소개` · 소개한 사람 ·
사람 화면의 `○○의 소개로` · 소개해 준 사람의 `소개한 인연 n명` · 아는 사이 후보(같은 사람이 소개) · 관계도.

통찰: 그라노베터의 1973년 연구(약한 연결의 힘) — 아는 사람을 통해 일자리를 찾은 이들에게 그 소식을 준 사람은
자주 보는 사람보다 가끔 · 드물게 보는 사람인 경우가 더 많았다.

앱 화면은
- `30-suggestions.png` — 아는 사이 후보(박서연 · 정유진 · 둘 다 김하늘 님이 소개)
- `16-network-graph.png` — 관계도(김하늘 — 박서연 · 정유진이 이어져 있다)
- 나머지는 앱 문구 그대로 다시 그렸다: `PersonEditView` 의 `알게 된 경로` 칩(`Presets.metThroughOptions`) · `소개한 사람`,
  `PersonDetailView` 의 `○○의 소개로` · `소개한 인연 n명`.
사람은 모두 견본(`SampleData`)의 지어낸 이름이다 (CLAUDE.md §2).
  python3 make_intro.py <repo> <out.mp4>          영상
  python3 make_intro.py <repo> <out.png> <초>     그 초의 한 장
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


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def arrow_down(d, x, y0, y1, color, width=6):
    d.line((x, y0, x, y1), fill=color, width=width)
    d.line((x - 18, y1 - 22, x, y1, x + 18, y1 - 22), fill=color, width=width)


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 이어 준 사람(물음표) ──────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "지금 가까운 그 사람,", 300, 62, GREY, t, SHOWN, path=MED)
    text(c, "처음엔\n누구 소개였나요?", 420, 108, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 위: 이어 준 사람 — 흐린 물음표 카드(천천히 숨 쉬듯), 아래: 지금 가까운 사람 — 또렷한 카드
    pulse = 0.55 + 0.25 * (0.5 + 0.5 * __import__("math").sin(t * 3.2))
    x0, x1 = 250, W - 250
    y = 980
    d.rounded_rectangle((x0, y, x1, y + 150), radius=40, outline=(150, 158, 165, round(255 * pulse)), width=4)
    d.text((W / 2, y + 75), "?", font=font(BOLD, 72), fill=(170, 178, 184, round(255 * pulse)), anchor="mm")
    arrow_down(d, W // 2, y + 170, y + 300, (124, 196, 178, 220))
    y2 = y + 320
    d.rounded_rectangle((x0, y2, x1, y2 + 150), radius=40, fill=DARK_CARD + (255,))
    d.ellipse((x0 + 34, y2 + 35, x0 + 114, y2 + 115), fill=(70, 80, 90, 255))
    d.text((x0 + 74, y2 + 75), "박", font=font(BOLD, 40), fill=(200, 206, 210, 255), anchor="mm")
    d.text((x0 + 140, y2 + 75), "가까운 동료", font=font(BOLD, 48), fill=(232, 236, 238, 255), anchor="lm")
    c.alpha_composite(layer)
    return c


def s_forget(t):
    c = DARK_BG.convert("RGBA")
    text(c, "가까워진 사람은 기억해도", 560, 84, WHITE, t, 0.1)
    text(c, "이어 준 사람은 잊혀요", 690, 92, ACCENT_SOFT, t, 0.55)
    text(c, "고마움도 함께", 900, 56, GREY, t, 1.1, path=MED)
    return c


# ── 3 통찰 — 약한 연결의 힘 ─────────────────────────────────────────────────
def s_insight(t):
    c = DARK_BG.convert("RGBA")
    text(c, "아는 사람을 통해 일자리를 찾은 이들,\n그 소식을 준 사람은", 300, 56, GREY, t, 0.05, path=MED)
    text(c, "자주 보는 친구보다", 600, 84, WHITE, t, 0.8)
    text(c, "가끔 보는 지인인 경우가\n더 많았습니다", 760, 92, ACCENT_SOFT, t, 1.5)
    text(c, "그라노베터 · 약한 연결의 힘 (1973)", 1130, 40, GREY, t, 2.2, path=MED)
    text(c, "인연은 소개로 넓어집니다", 1330, 60, WHITE, t, 2.7)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "누가 이어 주었는지까지 남깁니다", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 5 알게 된 경로 → 소개 · 소개한 사람 (PersonEditView 그대로) ─────────────────────
CHOICES = ["직장", "프로젝트", "소개", "행사·교육", "학교", "온라인", "가족·친척", "동호회·모임"]


def s_pick(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "알게 된 경로에서\n소개를 고르고", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 560
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 22), "알게 된 경로", font=font(MED, 38), fill=MUTED + (fa,), anchor="ls")
    picked = t > 1.0
    named = t > 2.2
    card(c, (x0, y0, x1, y0 + 470), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(MED, 42)
    x, y = x0 + 40, y0 + 40
    spots = {}
    for s in CHOICES:
        w = d.textlength(s, font=f) + 64
        if x + w > x1 - 40:
            x, y = x0 + 40, y + 110
        chosen = picked and s == "소개"
        if chosen:
            d.rounded_rectangle((x, y, x + w, y + 86), radius=43, fill=MINT + (fa,), outline=ACCENT + (fa,), width=4)
        else:
            d.rounded_rectangle((x, y, x + w, y + 86), radius=43, fill=CHIP_BG + (fa,))
        d.text((x + w / 2, y + 43), s, font=f, fill=(ACCENT if chosen else BODY) + (fa,), anchor="mm")
        spots[s] = (x + w / 2, y + 43)
        x += w + 18
    # 소개를 고르면 아래에 `소개한 사람` 줄이 생긴다
    b = ease((t - 1.2) / 0.3)
    if b > 0:
        fb = round(255 * b)
        ry = y + 120
        d.line((x0 + 40, ry, x1 - 40, ry), fill=RULE + (fb,), width=2)
        d.text((x0 + 40, ry + 75), "소개한 사람", font=font(MED, 46), fill=INK + (fb,), anchor="lm")
        value = "김하늘" if named else "선택 안 함"
        d.text((x1 - 90, ry + 75), value, font=font(MED, 46), fill=(ACCENT if named else MUTED) + (fb,), anchor="rm")
        cx, cy = x1 - 62, ry + 75
        d.line((cx - 8, cy - 14, cx + 6, cy, cx - 8, cy + 14), fill=MUTED + (fb,), width=5)
        spots["row"] = (x1 - 200, ry + 75)
    c.alpha_composite(layer)
    tap_ring(c, *spots["소개"], t, 0.7)
    if "row" in spots:
        tap_ring(c, *spots["row"], t, 1.9)
    return c


# ── 6 사람 화면 — `김하늘의 소개로` (PersonDetailView 그대로) ───────────────────────
def person_header(c, a, y0=520):
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    card(c, (x0, y0, x1, y0 + 620), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((x0 + 44, y0 + 44, x0 + 194, y0 + 194), fill=MINT + (fa,))
    d.text((x0 + 119, y0 + 119), "박", font=font(BOLD, 64), fill=ACCENT + (fa,), anchor="mm")
    d.text((x0 + 230, y0 + 119), "박서연", font=font(BOLD, 76), fill=INK + (fa,), anchor="lm")
    d.text((x0 + 44, y0 + 260), "마루디자인 · 대표", font=font(MED, 44), fill=BODY + (fa,), anchor="lm")
    f = font(MED, 40)
    x = x0 + 44
    for s, first in (("협력사", True), ("소개", False), ("#디자인", False)):
        w = d.textlength(s, font=f) + 60
        if first:
            d.rounded_rectangle((x, y0 + 320, x + w, y0 + 400), radius=40, fill=MINT + (fa,), outline=ACCENT + (fa,), width=3)
        else:
            d.rounded_rectangle((x, y0 + 320, x + w, y0 + 400), radius=40, fill=CHIP_BG + (fa,))
        d.text((x + w / 2, y0 + 360), s, font=f, fill=(ACCENT if first else BODY) + (fa,), anchor="mm")
        x += w + 16
    return layer, d, (x0, x1, y0)


def s_link(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "그 사람 화면에\n누구의 소개였는지", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    layer, d, (x0, x1, y0) = person_header(c, a)
    b = ease((t - 0.9) / 0.4)
    if b > 0:
        fb = round(255 * b)
        ly = y0 + 500
        # 꺾인 화살표 (arrow.turn.down.right 를 선으로)
        d.line((x0 + 60, ly - 26, x0 + 60, ly + 4, x0 + 108, ly + 4), fill=ACCENT + (fb,), width=5)
        d.line((x0 + 92, ly - 12, x0 + 108, ly + 4, x0 + 92, ly + 20), fill=ACCENT + (fb,), width=5)
        d.text((x0 + 140, ly), "김하늘의 소개로", font=font(MED, 50), fill=ACCENT + (fb,), anchor="lm")
        cx = x1 - 60
        d.line((cx - 8, ly - 14, cx + 6, ly, cx - 8, ly + 14), fill=MUTED + (fb,), width=5)
    c.alpha_composite(layer)
    tap_ring(c, x0 + 330, y0 + 500, t, 2.3)
    text(c, "누르면 소개해 준 사람에게로", 1260, 50, MUTED, t, 2.5, path=MED)
    return c


# ── 7 소개해 준 사람 화면 — `소개한 인연 2명` ────────────────────────────────────
INTRODUCED = [("박", "박서연", "마루디자인 · 대표"), ("정", "정유진", "청림소프트 · 주니어 개발자")]


def s_introduced(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "소개해 준 사람에게는\n소개한 인연이 모입니다", 130, 80, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1, y0 = 60, W - 60, 600
    d = ImageDraw.Draw(c)
    d.text((x0 + 30, y0 - 26), "소개한 인연 2명", font=font(MED, 40), fill=MUTED + (fa,), anchor="ls")
    card(c, (x0, y0, x1, y0 + 360), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (initial, name, sub) in enumerate(INTRODUCED):
        b = ease((t - 0.5 - k * 0.35) / 0.35)
        if b <= 0:
            continue
        fb = round(255 * min(a, b))
        y = y0 + 30 + k * 180
        d.ellipse((x0 + 40, y + 30, x0 + 140, y + 130), fill=MINT + (fb,))
        d.text((x0 + 90, y + 80), initial, font=font(BOLD, 44), fill=ACCENT + (fb,), anchor="mm")
        d.text((x0 + 170, y + 58), name, font=font(BOLD, 48), fill=INK + (fb,), anchor="lm")
        d.text((x0 + 170, y + 112), sub, font=font(MED, 38), fill=MUTED + (fb,), anchor="lm")
        cx, cy = x1 - 60, y + 80
        d.line((cx - 8, cy - 14, cx + 6, cy, cx - 8, cy + 14), fill=MUTED + (fb,), width=5)
        if k == 0:
            d.line((x0 + 170, y + 175, x1, y + 175), fill=RULE + (fb,), width=2)
    c.alpha_composite(layer)
    text(c, "김하늘 님 덕분에 알게 된 사람들", 1080, 50, ACCENT, t, 1.6, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "이어 준 사람까지,\n고마운 인연을 기억하는 법", 280, 70, INK, t, 0.1)
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


SUGGEST = shot("30-suggestions.png")
GRAPH = shot("16-network-graph.png")


def scenes():
    return [
        (3.8, s_hook),
        (3.0, s_forget),
        (4.4, s_insight),
        (2.4, s_reveal),
        (4.2, s_pick),
        (3.8, s_link),
        (3.6, s_introduced),
        # 아는 사이 후보 — 박서연 · 정유진 · 둘 다 김하늘 님이 소개 (스크린샷 30)
        (3.2, mr.card_closeup(SUGGEST, "같은 사람이 소개한 둘,\n아는 사이로 이을까요?", 0.16, 0.43)),
        # 관계도 — 김하늘에서 박서연 · 정유진으로 이어진 선 (스크린샷 16)
        (3.2, mr.card_closeup(GRAPH, "관계도에서도\n이어집니다", 0.245, 0.82)),
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
