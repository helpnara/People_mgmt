#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 (1080 × 1920 · 30fps · 약 28초) — 컨셉: 이 사람, 어디서 만났더라?

장면마다 프레임을 PIL 로 그리고 ffmpeg 로 묶는다. 앱 화면은 스토어용 녹화본 · 스크린샷(모두 지어낸 견본).
  python3 make_short.py <repo> <out.mp4>
"""
import math
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
HERE = pathlib.Path(__file__).resolve().parent
W, H, FPS = 1080, 1920, 30
XF = 0.35  # 장면 사이 겹침(초)

INK = (20, 24, 29)
INK_SOFT = (38, 44, 52)
WHITE = (247, 249, 248)
GREY = (150, 158, 165)
ACCENT = (47, 107, 94)
ACCENT_SOFT = (124, 196, 178)
BG_TOP, BG_BOTTOM = (228, 240, 236), (244, 247, 246)
RULE = (214, 222, 219)

BOLD = str(HERE / "font/NotoSansKR-ExtraBold.ttf")
MED = str(HERE / "font/NotoSansKR-Medium.ttf")
_fonts = {}


def font(path, size):
    key = (path, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(path, size)
    return _fonts[key]


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def gradient(top, bottom):
    g = Image.new("RGB", (1, 2))
    g.putpixel((0, 0), top)
    g.putpixel((0, 1), bottom)
    return g.resize((W, H), Image.BILINEAR)


LIGHT_BG = gradient(BG_TOP, BG_BOTTOM)
DARK_BG = gradient(INK, INK_SOFT)


def text(canvas, s, y, size, color, t, t0, path=BOLD, spacing=0.3, rise=36, dur=0.45):
    """t0 초에 떠오르며 나타나는 가운데 정렬 글."""
    a = ease((t - t0) / dur)
    if a <= 0:
        return
    f = font(path, size)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.multiline_text((W / 2, y + (1 - a) * rise), s, font=f, fill=color + (round(255 * a),),
                     anchor="ma", align="center", spacing=round(size * spacing))
    canvas.alpha_composite(layer)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


class Phone:
    """앱 화면을 둥근 모서리 · 그림자 · 테두리로 놓는다. 위치는 고정이라 그림자는 한 번만 만든다."""

    def __init__(self, width=760, y=430):
        self.w = width
        self.h = round(width * 1920 / 886)
        self.x = (W - width) // 2
        self.y = y
        self.r = round(width * 0.085)
        self.mask = rounded_mask((self.w, self.h), self.r)
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((self.x, self.y + 22, self.x + self.w, self.y + self.h + 22),
                                             radius=self.r, fill=(20, 24, 29, 70))
        self.shadow = sh.filter(ImageFilter.GaussianBlur(30))
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle((self.x, self.y, self.x + self.w - 1, self.y + self.h - 1),
                                               radius=self.r, outline=RULE + (255,), width=3)
        self.ring = ring

    def place(self, canvas, screen, alpha=1.0, zoom=1.0):
        screen = screen.convert("RGB")
        if zoom != 1.0:  # 위쪽 가운데를 붙잡고 살짝 당긴다
            cw, ch = screen.width / zoom, screen.height / zoom
            x0 = (screen.width - cw) / 2
            screen = screen.crop((round(x0), 0, round(x0 + cw), round(ch)))
        shot = screen.resize((self.w, self.h), Image.LANCZOS).convert("RGBA")
        m = self.mask if alpha >= 1 else self.mask.point(lambda v: round(v * alpha))
        shot.putalpha(m)
        if alpha >= 1:
            canvas.alpha_composite(self.shadow)
        else:
            s = self.shadow.copy()
            s.putalpha(s.getchannel("A").point(lambda v: round(v * alpha)))
            canvas.alpha_composite(s)
        canvas.alpha_composite(shot, (self.x, self.y))
        if alpha >= 1:
            canvas.alpha_composite(self.ring)


PHONE = Phone()


def video_frames(path, start, dur):
    """녹화본의 [start, start+dur) 를 초당 30장으로 푼다."""
    w, h = 886, 1920
    p = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(dur), "-i", str(path),
                        "-vf", "fps=30", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                       check=True, capture_output=True).stdout
    n = len(p) // (w * h * 3)
    return [Image.frombytes("RGB", (w, h), p[i * w * h * 3:(i + 1) * w * h * 3]) for i in range(n)]


# ── 장면들 — 각자 (길이, t → RGB 프레임) ─────────────────────────────────────

ICON = Image.open(REPO / "App/Assets.xcassets/AppIcon.appiconset/icon-1024.png").convert("RGBA")
PREVIEW = REPO / "screenshots/store/upload/preview-iphone.mp4"
RAW = REPO / "screenshots/store/raw/iphone"


def contact_card(canvas, t, t0, y=900):
    """연락처 앱처럼 이름과 번호만 있는 카드 (지어낸 견본 김하늘)."""
    a = ease((t - t0) / 0.5)
    if a <= 0:
        return
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1 = 150, 930
    yy = y + (1 - a) * 50
    al = round(255 * a)
    d.rounded_rectangle((x0, yy, x1, yy + 300), radius=44, fill=(255, 255, 255, al))
    d.ellipse((x0 + 50, yy + 60, x0 + 230, yy + 240), fill=(205, 212, 210, al))
    d.text((x0 + 140, yy + 150), "김", font=font(BOLD, 84), fill=(255, 255, 255, al), anchor="mm")
    d.text((x0 + 280, yy + 82), "김하늘", font=font(BOLD, 66), fill=INK + (al,))
    d.text((x0 + 282, yy + 178), "010-1234-5678", font=font(MED, 44), fill=(110, 118, 125, al))
    canvas.alpha_composite(layer)


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "이 사람,", 330, 118, WHITE, t, 0.15)
    text(c, "어디서 만났더라?", 490, 118, ACCENT_SOFT, t, 0.75)
    contact_card(c, t, 1.5)
    return c


QUESTIONS = ["어디서 처음 만났지?", "마지막으로 본 게 언제지?", "그때 무슨 이야기를 했더라?"]


def s_problem(t):
    c = DARK_BG.convert("RGBA")
    text(c, "연락처엔\n이름과 번호만", 280, 100, WHITE, t, 0.1)
    contact_card(c, t, -1)
    for i, q in enumerate(QUESTIONS):
        text(c, q, 1270 + i * 92, 52, GREY, t, 0.7 + i * 0.55, path=MED)
    return c


def icon_at(canvas, size, cy, a, scale=1.0):
    s = max(1, round(size * scale))
    im = ICON.resize((s, s), Image.LANCZOS)
    im.putalpha(rounded_mask((s, s), round(s * 0.225)).point(lambda v: round(v * a)))
    canvas.alpha_composite(im, ((W - s) // 2, round(cy - s / 2)))


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    a = ease(t / 0.5)
    icon_at(c, 300, 620, a, scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "연락처가 아니라\n인연을 기록합니다", 1040, 64, ACCENT, t, 0.8, path=MED)
    return c


def first_encounter_callout(canvas, t, t0):
    """상세 화면 아래쪽의 첫 인연 칸을 크게 띄운다 — 쇼츠의 아래쪽 글 띠에 가리지 않게 가운데로 (견본 김하늘의 자료 그대로)."""
    a = ease((t - t0) / 0.45)
    if a <= 0:
        return
    dim = Image.new("RGBA", (W, H), (20, 24, 29, round(70 * a)))
    canvas.alpha_composite(dim)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1, y0 = 90, 990, 960 + (1 - a) * 40
    al = round(255 * a)
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 20, x1, y0 + 500), radius=48, fill=(20, 24, 29, round(80 * a)))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(26)))
    d.rounded_rectangle((x0, y0, x1, y0 + 480), radius=48, fill=(255, 255, 255, al), outline=ACCENT + (al,), width=5)
    d.text((x0 + 60, y0 + 50), "첫 인연", font=font(BOLD, 52), fill=ACCENT + (al,))
    d.text((x0 + 60, y0 + 135), "2019년 3월 4일", font=font(MED, 42), fill=(95, 104, 112, al))
    d.multiline_text((x0 + 60, y0 + 210), "입사 첫날 옆자리에 앉았다.\n점심을 같이 먹으며\n팀 분위기를 알려 주었다.",
                     font=font(MED, 46), fill=INK + (al,), spacing=14)
    canvas.alpha_composite(layer)


def still_scene(raw_name, caption, callout=None):
    shot = Image.open(RAW / raw_name).convert("RGB")

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        PHONE.place(c, shot, alpha=ease(t / 0.3), zoom=1.0 + 0.05 * ease(t / 3.6))
        if callout:
            callout(c, t, 0.9)
        return c
    return frame


def video_scene(start, dur, caption):
    frames = video_frames(PREVIEW, start, dur)

    def frame(t):
        c = LIGHT_BG.convert("RGBA")
        text(c, caption, 170, 86, INK, t, 0.05)
        i = min(len(frames) - 1, int(t * FPS))
        PHONE.place(c, frames[i], alpha=ease(t / 0.3))
        return c
    return frame


CHIPS = ["무료", "회원가입 없음", "광고 없음"]


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    icon_at(c, 260, 470, ease(t / 0.5), scale=0.9 + 0.1 * ease(t / 0.6))
    text(c, "느린 인연", 650, 116, INK, t, 0.25)
    # 칩 세 개
    a = ease((t - 0.8) / 0.45)
    if a > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = font(BOLD, 46)
        widths = [d.textlength(s, font=f) + 70 for s in CHIPS]
        x = (W - (sum(widths) + 24 * (len(CHIPS) - 1))) / 2
        y = 860 + (1 - a) * 30
        for s, w in zip(CHIPS, widths):
            d.rounded_rectangle((x, y, x + w, y + 92), radius=46, fill=ACCENT + (round(255 * a),))
            d.text((x + w / 2, y + 46), s, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
            x += w + 24
        c.alpha_composite(layer)
    text(c, "기록은 내 기기와 내 iCloud 에만", 1010, 50, (80, 90, 96), t, 1.2, path=MED)
    text(c, "App Store 에서\n느린 인연 검색", 1160, 72, ACCENT, t, 1.7)
    return c


def scenes():
    return [
        (3.2, s_hook),
        (3.4, s_problem),
        (2.6, s_reveal),
        (3.8, still_scene("02-person-detail.png", "어떻게 알게 되었는지", first_encounter_callout)),
        (2.8, video_scene(4.3, 2.8, "무엇을 함께했는지")),
        (6.8, video_scene(9.5, 6.8, "내 인맥이 지도처럼\n해마다 달라진 모임까지")),
        (3.2, still_scene("06-overview.png", "한동안 못 본 사람도\n잊지 않게")),
        (5.2, s_end),
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
        if len(live) > 1:  # 앞 장면과 겹치는 구간 — 섞는다
            j, jt = live[-2]
            img = Image.blend(sc[j][1](jt).convert("RGB"), img, ease(lt / XF))
        if t > total - 0.4:  # 끝에서 살짝 어둡게가 아니라 그대로 — 쇼츠는 다시 돈다
            pass
        enc.stdin.write(img.tobytes())
    enc.stdin.close()
    enc.wait()
    print(f"{OUT} — {total:.1f}초 · {n}장")


if __name__ == "__main__":
    main()
