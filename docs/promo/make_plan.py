#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 5 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 약속 그다음까지 (2026-11-05).

첫 쇼츠(make_short.py) · 셋째(make_record.py)의 그리기 도구를 그대로 쓴다. 화면은 **지금 브랜치의 CI 스크린샷**
(1.1 의 예정된 만남 · 결과 적기 — App Store 1.1.4 판과 같은 화면). 알림 장면은 앱이 거는 문구 그대로 그린다
(`App/Services/Reminders.swift` 결과 적기). 사람은 모두 지어낸 견본이다.
  python3 make_plan.py <repo> <out.mp4>
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


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


def week(t, t0, cy=1060):
    """한 주 달력 칸 — 약속 날에 점이 찍히고, 그날이 지나가면 점이 흐려지며 물음표가 남는다."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    days = ["월", "화", "수", "목", "금", "토", "일"]
    size, gap = 116, 18
    x0 = (W - (size * 7 + gap * 6)) / 2
    plan = 3
    passed = ease((t - t0 - 1.5) / 0.6)
    for k, name in enumerate(days):
        a = ease((t - t0 - k * 0.06) / 0.3)
        if a <= 0:
            continue
        x = x0 + k * (size + gap)
        y = cy - size / 2
        fill = (255, 255, 255, round(22 * a))
        if k <= plan and passed > 0:
            fill = (255, 255, 255, round((22 + 18 * passed) * a))
        d.rounded_rectangle((x, y, x + size, y + size), radius=24, fill=fill)
        d.text((x + size / 2, y + 36), name, font=font(MED, 34), fill=GREY + (round(255 * a),), anchor="mm")
        if k == plan:
            dot = ease((t - t0 - 0.7) / 0.3)
            if dot > 0:
                r = 14
                alpha = round(255 * dot * (1 - 0.7 * passed))
                d.ellipse((x + size / 2 - r, y + 76 - r, x + size / 2 + r, y + 76 + r), fill=ACCENT_SOFT + (alpha,))
    q = ease((t - t0 - 2.0) / 0.4)
    if q > 0:
        x = x0 + plan * (size + gap) + size / 2
        d.text((x, cy + size / 2 + 70), "?", font=font(BOLD, 90), fill=ACCENT_SOFT + (round(255 * q),), anchor="mm")
    return layer


def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "약속은 잡아 두었는데", 250, 60, GREY, t, 0.05, path=MED)
    text(c, "만나고 나면", 380, 104, WHITE, t, 0.4)
    text(c, "그날 이야기는\n어디로 가나요?", 510, 96, ACCENT_SOFT, t, 0.75)
    c.alpha_composite(week(t, 1.0))
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "약속부터\n그다음까지", 1040, 72, ACCENT, t, 0.8, path=MED)
    return c


def notification(t, t0, y=820):
    """잠금 화면 알림 한 장 — 앱이 거는 결과 적기 알림의 문구 그대로."""
    a = ease((t - t0) / 0.45)
    if a <= 0:
        return None
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1 = 70, W - 70
    yy = y + (1 - a) * 40
    d.rounded_rectangle((x0, yy, x1, yy + 300), radius=44, fill=(250, 251, 250, round(240 * a)))
    s = 78
    icon = ms.ICON.resize((s, s), Image.LANCZOS)
    icon.putalpha(ms.rounded_mask((s, s), round(s * 0.225)).point(lambda v: round(v * a)))
    layer.alpha_composite(icon, (x0 + 34, round(yy + 34)))
    d.text((x0 + 132, yy + 46), "느린 인연", font=font(MED, 34), fill=(110, 118, 125, round(255 * a)), anchor="lm")
    d.text((x1 - 34, yy + 46), "오전 9:00", font=font(MED, 32), fill=(140, 147, 153, round(255 * a)), anchor="rm")
    d.text((x0 + 132, yy + 100), "만난 결과를 적어 둘까요?", font=font(BOLD, 44), fill=INK + (round(255 * a),), anchor="lm")
    body = "어제 예정이던 커피 약속 · 정유진.\n느린 인연에 결과를 남겨 두세요."
    d.multiline_text((x0 + 132, yy + 140), body, font=font(MED, 38), fill=(60, 66, 72, round(255 * a)), spacing=12)
    return layer


def s_notify(t):
    c = DARK_BG.convert("RGBA")
    text(c, "만난 다음 날,", 300, 96, WHITE, t, 0.05)
    text(c, "알림 한 번", 430, 96, ACCENT_SOFT, t, 0.35)
    n = notification(t, 0.8)
    if n is not None:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((70, 850, W - 70, 1150), radius=44,
                                             fill=(0, 0, 0, round(90 * ease((t - 0.8) / 0.45))))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(n)
    text(c, "설정 → 알림에서 켤 때만 옵니다", 1300, 48, GREY, t, 1.6, path=MED)
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "지나간 약속이", 720, 104, WHITE, t, 0.1)
    text(c, "인연의 기록으로", 860, 104, ACCENT_SOFT, t, 0.45)
    text(c, "그날 나눈 이야기가\n그 사람의 타임라인에 남습니다", 1060, 58, GREY, t, 0.9, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "다음 약속부터,\n미리 적어 두세요", 300, 88, INK, t, 0.1)
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
    add = shot("10-add-record.png")
    home = shot("41-planned-home.png")
    band = shot("42-planned-awaiting.png")
    return [
        (3.8, s_hook),
        (2.6, s_reveal),
        (3.4, mr.card_closeup(add, "약속을 잡으면\n앞날짜로 미리 적기", 0.19, 0.40)),
        (3.4, mr.card_closeup(home, "홈에는\n다가오는 만남으로", 0.69, 0.895)),
        (3.4, mr.card_closeup(home, "그날이 지나면\n결과를 적을 만남으로", 0.545, 0.67)),
        (3.6, mr.card_closeup(band, "결과 적기, 아니면\n그대로 만났어요 한 번", 0.165, 0.375)),
        (3.6, s_notify),
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
    if len(sys.argv) > 3:  # 확인용 한 장: make_plan.py <repo> <out.png> <초>
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
