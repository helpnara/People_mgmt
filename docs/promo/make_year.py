#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 4 (1080 × 1920 · 30fps · 약 29초) — 컨셉: 올해, 누구와 보냈나요? (2026-11-04)

첫 쇼츠(make_short.py) · 셋째(make_record.py)의 그리기 도구를 그대로 쓴다. 화면은 **지금 브랜치의 CI 스크린샷**
(1.1.2 에 있는 한 해 돌아보기 · 기록 사진 · 모임의 변화 — App Store 판과 같은 화면). 사람은 모두 지어낸 견본이다.
  python3 make_year.py <repo> <out.mp4>
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
from PIL import Image, ImageDraw  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def faces(t, t0, cy=1240):
    """한 해 동안 만난 사람들 — 점이 하나씩 켜지고, 대부분은 다시 흐려진다(떠오르는 얼굴은 몇뿐)."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cols, rows, gap, r = 6, 3, 130, 34
    x0 = W / 2 - gap * (cols - 1) / 2
    y0 = cy - gap * (rows - 1) / 2
    remembered = {1, 8, 15}
    for k in range(cols * rows):
        a = ease((t - t0 - k * 0.07) / 0.3)
        if a <= 0:
            continue
        fade = ease((t - t0 - 1.8) / 0.6)
        keep = k in remembered
        alpha = a * (1.0 if keep else 1.0 - 0.75 * fade)
        color = (ACCENT_SOFT if keep and fade > 0 else (196, 204, 210))
        cx, cy2 = x0 + (k % cols) * gap, y0 + (k // cols) * gap
        d.ellipse((cx - r, cy2 - r, cx + r, cy2 + r), fill=color + (round(255 * alpha),))
    return layer


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "한 해가 저물어 갑니다", 250, 60, GREY, t, 0.05, path=MED)
    text(c, "올해, 누구와", 380, 104, WHITE, t, 0.4)
    text(c, "시간을 보냈나요?", 510, 104, ACCENT_SOFT, t, 0.75)
    c.alpha_composite(faces(t, 1.0))
    text(c, "떠오르는 얼굴은 몇 명뿐", 1600, 56, GREY, t, 2.9, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "적어 둔 만남이\n한 해를 돌려줍니다", 1040, 72, ACCENT, t, 0.8, path=MED)
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "순위는 없습니다", 760, 104, WHITE, t, 0.1)
    text(c, "누구를 몇 번 만났는지로\n사람을 줄 세우지 않아요", 960, 62, GREY, t, 0.6, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "올해가 가기 전에,\n한 줄씩 적어 두세요", 300, 88, INK, t, 0.1)
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
    review = shot("47-year-review.png")
    return [
        (3.8, s_hook),
        (2.6, s_reveal),
        (3.6, mr.phone_still(review, "내 인맥 → 돌아보기\n2026년 돌아보기")),
        (3.4, mr.card_closeup(review, "기록 · 함께한 사람 ·\n처음 만난 사람", 0.165, 0.44)),
        (3.4, mr.card_closeup(review, "새로 · 다시 함께한 사람,\n쉬어 간 사람까지", 0.455, 0.68)),
        (3.4, mr.card_closeup(review, "어느 달에\n자주 만났는지", 0.745, 0.985)),
        (3.6, mr.phone_still(shot("44-record-photos.png"), "그날의 사진도\n기록에 함께")),
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
