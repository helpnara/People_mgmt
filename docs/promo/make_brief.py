#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 8 (1080 × 1920 · 30fps · 약 30초) — 컨셉: 만나기 전 30초 (2026-11-08 · 1.1.9 만나기 전에).

앞 쇼츠들(make_short.py · make_record.py · make_day.py)의 그리기 도구를 쓴다. 앱 화면은 **지금 브랜치의 CI 스크린샷**
(`48-briefing.png` · 견본 정유진의 커피 약속 · 만나기 전에 · 기억할 것 · 캘린더에 추가)이다. 다음에 이야기할 것 칸은 스크린샷
(`49-talk-items.png` · 견본 김하늘)의 **줄 · 문구 그대로** 다시 그려 동그라미를 누르는 움직임을 더했다(`TalkItemsSection` — 동그라미 ·
줄 글 · `이야기할 것 더하기` · `끝낸 것 n개`). 사람은 모두 지어낸 견본이다.
  python3 make_brief.py <repo> <out.mp4>          영상
  python3 make_brief.py <repo> <out.png> <초>     그 초의 한 장
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


# ── 1 · 2 첫 장면 ─────────────────────────────────────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "약속 10분 전", 560, 64, GREY, t, 0.05, path=MED)
    text(c, "지난번에 무슨 얘기 했더라?", 720, 84, WHITE, t, 0.45)
    text(c, "그 사람, 뭘 좋아했더라?", 860, 84, ACCENT_SOFT, t, 1.05)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "만나기 전 30초", 1040, 72, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 다음에 이야기할 것 — 줄 · 문구는 스크린샷 49 그대로 ─────────────────────
TALK = ["하준이 입학 선물 물어보기", "다음 분기 멘토링 주제 정하기"]


def s_talk(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "다음에 이야기할 것,\n끝내면 체크", 170, 86, INK, t, 0.05)
    a = ease((t - 0.3) / 0.35)
    if a <= 0:
        return c
    x0, x1, y0 = 60, W - 60, 600
    d = ImageDraw.Draw(c)
    done = ease((t - 1.6) / 0.35)          # 첫 줄 동그라미가 눌린다
    leave = ease((t - 2.4) / 0.4)          # 끝낸 줄이 접힌다
    head = f"다음에 이야기할 것 {2 if leave < 0.5 else 1}"
    d.text((x0 + 30, y0 - 22), head, font=font(MED, 38), fill=MUTED + (round(255 * a),), anchor="ls")
    row_h = 150
    rows_h = row_h * 2 - row_h * leave
    card(c, (x0, y0, x1, y0 + rows_h + 260), a)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fa = round(255 * a)
    for k, s in enumerate(TALK):
        if k == 0:
            ra = round(fa * (1 - leave))
            y = y0 + row_h / 2
        else:
            ra = fa
            y = y0 + row_h / 2 + row_h * (1 - leave)
        if ra <= 0:
            continue
        cx = x0 + 110
        if k == 0 and done > 0:
            d.ellipse((cx - 34, y - 34, cx + 34, y + 34), fill=ACCENT + (round(ra * done),))
            d.line((cx - 15, y + 1, cx - 4, y + 13, cx + 17, y - 12), fill=(255, 255, 255, round(ra * done)), width=7)
            if done < 1:
                d.ellipse((cx - 30, y - 30, cx + 30, y + 30), outline=FAINT + (round(ra * (1 - done)),), width=5)
        else:
            d.ellipse((cx - 30, y - 30, cx + 30, y + 30), outline=FAINT + (ra,), width=5)
        col = MUTED if (k == 0 and done > 0.5) else BODY
        f = font(MED, 46)
        d.text((x0 + 200, y), s, font=f, fill=col + (ra,), anchor="lm")
        if k == 0 and done > 0.5:
            tw = d.textlength(s, font=f)
            d.line((x0 + 200, y + 2, x0 + 200 + tw * ease((t - 1.8) / 0.3), y + 2), fill=MUTED + (ra,), width=4)
        d.line((x0 + 200, y + row_h / 2, x1, y + row_h / 2), fill=RULE + (ra,), width=2)
    # 더하기 칸 · 끝낸 것
    yb = y0 + rows_h + 70
    d.text((x0 + 50, yb), "이야기할 것 더하기", font=font(MED, 44), fill=FAINT + (fa,), anchor="lm")
    d.line((x0 + 50, yb + 64, x1 - 50, yb + 64), fill=RULE + (fa,), width=2)
    n = 2 if leave > 0.5 else 1
    cx, cy = x0 + 70, yb + 140   # 아래 꺾쇠 (글꼴에 없는 기호라 선으로)
    d.line((cx - 16, cy - 8, cx, cy + 8, cx + 16, cy - 8), fill=MUTED + (fa,), width=5)
    d.text((x0 + 140, yb + 140), f"끝낸 것 {n}개", font=font(MED, 42), fill=MUTED + (fa,), anchor="lm")
    c.alpha_composite(layer)
    # 손가락 누름
    p = ease((t - 1.3) / 0.3)
    if 0 < p and t < 2.1:
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring)
        cx, cy = x0 + 110, y0 + row_h / 2
        rr = 40 + 60 * p
        rd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=ACCENT + (round(170 * (1 - p)),), width=8)
        c.alpha_composite(ring)
    text(c, "만나서 물어볼 것 · 전할 것을\n적어 두면 그 약속에서 다시 보여요", 1330, 50, MUTED, t, 2.6, path=MED)
    return c


# ── 5 약속을 열면 — 스크린샷 48 ────────────────────────────────────────────────
def s_phone(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "약속을 열면", 150, 86, INK, t, 0.05)
    text(c, "만나기 전에 볼 것이 한 장에", 270, 52, ACCENT, t, 0.3, path=MED)
    a = ease((t - 0.2) / 0.45)
    if a > 0:
        ms.PHONE.place(c, BRIEFING, alpha=a, zoom=1.0 + 0.05 * ease((t - 0.6) / 3.0))
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "만남은 짧아도", 740, 104, WHITE, t, 0.1)
    text(c, "기억은 길게", 880, 104, ACCENT_SOFT, t, 0.45)
    text(c, "기억할 것 · 이야기할 것은\n내 기기와 내 iCloud 에만", 1080, 54, GREY, t, 0.9, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "만나기 전 30초,\n대화는 더 깊게", 300, 88, INK, t, 0.1)
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
    return [
        (3.6, s_hook),
        (2.6, s_reveal),
        # 기억할 것 — 사람 이름 · 기억할 것 상자 · 처음 계기 (스크린샷 48 의 그 칸)
        (3.8, mr.card_closeup(BRIEFING, "꼭 기억할 것 한 줄", 0.545, 0.785)),
        (4.4, s_talk),
        (4.2, s_phone),
        (3.0, mr.card_closeup(BRIEFING, "기기 캘린더에도\n한 번에", 0.165, 0.49)),
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
