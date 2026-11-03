#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 3 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 만나고 30초 기록.

첫 쇼츠(make_short.py)의 그리기 도구를 그대로 쓴다. App Store 판(1.0)에 있는 화면만 쓰려고 **1.0 을 낸 커밋(`134054a`)의
CI 스크린샷**을 git 에서 꺼내 쓴다 — 지금 저장소의 스크린샷에는 1.1.1(사진 · 시각 칸)이 섞여 있다. 사람은 모두 지어낸 견본이다.
  python3 make_record.py <repo> <out.mp4>
"""
import io
import math
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
REPO = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
import make_short as ms  # noqa: E402  (같은 인자를 읽는다)
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG

RELEASE = "134054a"  # App Store 1.0 (빌드 37) 을 낸 main 병합


def shot(path):
    """1.0 을 낸 커밋의 스크린샷."""
    data = subprocess.run(["git", "-C", str(REPO), "show", f"{RELEASE}:screenshots/{path}"],
                          check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGB")


# ── 30초 고리 (어두운 바탕) ──────────────────────────────────────────────────
SS = 2


def timer_ring(t, cy=1250, r=230):
    """한 바퀴 도는 고리와 가운데 남은 초 — 30 에서 줄어든다(장면 길이에 맞춰 빠르게)."""
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = W / 2
    box = [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS]
    a = ease(t / 0.4)
    d.ellipse(box, outline=(255, 255, 255, round(40 * a)), width=18 * SS)
    p = ease((t - 0.3) / 2.8)
    if p > 0:
        d.arc(box, start=-90, end=-90 + 360 * p, fill=ACCENT_SOFT + (round(255 * a),), width=18 * SS)
    layer = layer.resize((W, H), Image.LANCZOS)
    left = max(0, 30 - math.floor(30 * p))
    d2 = ImageDraw.Draw(layer)
    d2.text((cx, cy - 20), str(left), font=font(BOLD, 150), fill=WHITE + (round(255 * a),), anchor="mm")
    d2.text((cx, cy + 95), "초", font=font(MED, 50), fill=GREY + (round(255 * a),), anchor="mm")
    return layer


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "회의 끝나고 엘리베이터 안,", 250, 64, GREY, t, 0.05, path=MED)
    text(c, "방금 나눈 이야기", 370, 96, WHITE, t, 0.45)
    text(c, "어디에 적어 두나요?", 500, 96, ACCENT_SOFT, t, 0.85)
    c.alpha_composite(timer_ring(t))
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "만난 날 30초면\n기록 끝", 1040, 72, ACCENT, t, 0.8, path=MED)
    return c


def phone_still(image, caption, zoom_to=1.05):
    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        ms.PHONE.place(c, image, alpha=ease(t / 0.3), zoom=1.0 + (zoom_to - 1.0) * ease(t / 3.8))
        return c
    return frame


def card_closeup(image, caption, top, bottom):
    """화면의 한 칸만 카드처럼 크게 띄워 천천히 당긴다 (top · bottom 은 화면 높이의 비율)."""
    w, h = image.size
    crop = image.crop((0, round(h * top), w, round(h * bottom)))
    card_w = 980
    base = crop.resize((card_w, round(crop.height * card_w / crop.width)), Image.LANCZOS)
    radius = 40
    mask = ms.rounded_mask(base.size, radius)

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        z = 1.0 + 0.08 * ease(t / 3.8)
        cw, ch = base.width / z, base.height / z
        x0 = (base.width - cw) * 0.5
        y0 = (base.height - ch) * 0.3
        img = base.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch))).resize(base.size, Image.LANCZOS).convert("RGBA")
        a = ease(t / 0.35)
        img.putalpha(mask.point(lambda v: round(v * a)))
        x = (W - base.width) // 2
        y = 520
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((x, y + 24, x + base.width, y + base.height + 24), radius=radius,
                                             fill=(20, 24, 29, round(60 * a)))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(img, (x, y))
        return c
    return frame


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "만나고 30초,\n인연은 오래", 300, 92, INK, t, 0.1)
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
    add_record = shot("store/raw/iphone/03-add-record.png")
    return [
        (3.4, s_hook),
        (2.6, s_reveal),
        (3.8, phone_still(add_record, "날짜는 오늘,\n유형은 지난번 그대로")),
        (3.6, card_closeup(add_record, "제목이나 메모\n한 줄이면 저장", 0.355, 0.84)),
        (3.8, phone_still(shot("39-participant-search.png"), "함께한 사람은\n초성 ㅈㅇ 으로")),
        (3.8, phone_still(shot("09-record-detail.png"), "여럿이 함께해도\n한 번만 적으면 모두에게")),
        (3.6, phone_still(shot("store/raw/iphone/01-people.png"), "홈 맨 위엔\n최근 기록 세 건")),
        (3.8, phone_still(shot("05-search.png"), "몇 달 뒤엔 검색 한 번,\n어디서 찾았는지까지")),
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
