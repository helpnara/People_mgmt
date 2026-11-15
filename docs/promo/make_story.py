#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 11 (1080 × 1920 · 30fps · 약 33초) — 컨셉: 연락처 812명, 힘든 날 전화할 사람은? (2026-11-15).

인맥 관리가 왜 필요한지를 **이야기 한 편**으로 보인다(2026-11-15 사용자 — 스토리텔링).
조회수 1회차 분석(`../promo-youtube-stats.md`)대로 **숫자 하나 + 질문** 으로 열고, 기능 이름은 여섯째 장면부터 나온다.
1. 연락처 812명 — 힘든 날 전화할 수 있는 사람은 몇 명인가요?
2. 입사 동기 한 사람이 해마다 멀어지는 이야기(2019 매일 점심 → 2021 생일에 메시지 한 번 → 2024 마지막 연락 3년 전)
3. 통찰 — 80년 넘게 같은 사람들의 삶을 따라간 연구(하버드 성인발달연구): 50세에 관계에 가장 만족했던 사람이 80세에 가장 건강했다
4. 관계는 돌본 만큼 남는다 → 앱 → 기억할 것 · 한 해 돌아보기 · 연락 주기 알림 → 약속 → 끝

앱 화면은
- `03-person-detail.png` — 사람 상세 머리 칸(기억할 것 · 연락 주기 3개월)
- `47-year-review.png` — 한 해 돌아보기(기록 · 함께한 사람 · 사람의 흐름)
- 연락 주기 알림은 `make_quiet.py` 가 `ReminderPlanner` 문구 그대로 그린 것을 쓴다.
사람(민준 · 김하늘)은 모두 지어낸 이름이다 (CLAUDE.md §2). 이야기도 지어낸 것이다.
  python3 make_story.py <repo> <out.mp4>          영상
  python3 make_story.py <repo> <out.png> <초>     그 초의 한 장
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
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

W, H, FPS, XF = ms.W, ms.H, ms.FPS, ms.XF
ease, text, font = ms.ease, ms.text, ms.font
INK, WHITE, GREY, ACCENT, ACCENT_SOFT = ms.INK, ms.WHITE, ms.GREY, ms.ACCENT, ms.ACCENT_SOFT
BOLD, MED = ms.BOLD, ms.MED
LIGHT_BG, DARK_BG = ms.LIGHT_BG, ms.DARK_BG
DARK_CARD = mq.DARK_CARD


def shot(path):
    return Image.open(REPO / "screenshots" / path).convert("RGB")


# ── 1 첫 장면 — 올라가는 숫자 하나 + 질문 ─────────────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "내 휴대폰 연락처", 360, 58, GREY, t, 0.05, path=MED)
    a = ease((t - 0.3) / 0.3)
    if a > 0:
        n = round(812 * ease((t - 0.3) / 1.1))
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((W / 2, 470 + (1 - a) * 36), f"{n}명", font=font(BOLD, 210),
                                   fill=ACCENT_SOFT + (round(255 * a),), anchor="ma")
        c.alpha_composite(layer)
    text(c, "힘든 날,\n전화할 수 있는 사람은\n몇 명인가요?", 900, 96, WHITE, t, 1.6)
    return c


# ── 2 이야기 — 입사 동기 한 사람이 해마다 멀어진다 ──────────────────────────────
BEATS = [
    (0.5, "2019", "입사 동기 민준", "매일 점심을 함께 먹던 사이"),
    (1.7, "2021", "이직한 뒤", "생일에 메시지 한 번"),
    (2.9, "2024", "마지막 연락", "3년 전"),
]


def s_story(t):
    c = DARK_BG.convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (t0, year, head, sub) in enumerate(BEATS):
        a = ease((t - t0) / 0.45)
        if a <= 0:
            continue
        # 해가 지날수록 카드가 옅어진다 — 멀어지는 사이
        fade = a * (1.0 - 0.28 * k)
        al = round(255 * fade)
        y = 420 + k * 330 + round((1 - a) * 30)
        d.text((150, y), year, font=font(BOLD, 52), fill=ACCENT_SOFT + (al,), anchor="ls")
        d.rounded_rectangle((120, y + 30, W - 120, y + 250), radius=40, fill=DARK_CARD + (al,))
        d.text((180, y + 105), head, font=font(BOLD, 56), fill=(235, 238, 240, al), anchor="lm")
        d.text((180, y + 185), sub, font=font(MED, 46), fill=(165, 172, 178, al), anchor="lm")
    c.alpha_composite(layer)
    text(c, "누구의 잘못도 아니었습니다.\n그저 바빴을 뿐", 1450, 60, WHITE, t, 3.7, path=MED)
    return c


# ── 3 통찰 — 하버드 성인발달연구 ─────────────────────────────────────────────
def s_insight(t):
    c = DARK_BG.convert("RGBA")
    text(c, "80년 넘게 같은 사람들의 삶을\n따라간 연구가 있습니다", 330, 58, GREY, t, 0.05, path=MED)
    text(c, "50세에 관계에\n가장 만족했던 사람이", 640, 88, WHITE, t, 0.9)
    text(c, "80세에\n가장 건강했습니다", 960, 104, ACCENT_SOFT, t, 1.8)
    text(c, "하버드 성인발달연구", 1340, 40, GREY, t, 2.4, path=MED)
    return c


def s_turn(t):
    c = DARK_BG.convert("RGBA")
    text(c, "관계는\n저절로 남지 않습니다", 560, 92, WHITE, t, 0.1)
    text(c, "돌본 만큼 남습니다", 900, 96, ACCENT_SOFT, t, 0.9)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "함께한 시간을 적어 두는 인연 기록", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 8 안부 알림 — make_quiet 의 연락 주기 알림(ReminderPlanner 문구 그대로) ─────────
def s_notify(t):
    c = DARK_BG.convert("RGBA")
    text(c, "멀어지기 전에,", 300, 96, WHITE, t, 0.05)
    text(c, "먼저 알려 줍니다", 430, 90, ACCENT_SOFT, t, 0.35)
    n = mq.notification(t, 0.8)
    if n is not None:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((70, 850, W - 70, 1100), radius=44,
                                             fill=(0, 0, 0, round(90 * ease((t - 0.8) / 0.45))))
        c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30)))
        c.alpha_composite(n)
    text(c, "사람마다 정한 연락 주기가 지나면\n안부 알림 한 번", 1250, 52, GREY, t, 1.6, path=MED)
    return c


def s_promise(t):
    c = DARK_BG.convert("RGBA")
    text(c, "인맥은 숫자가 아니라", 680, 92, WHITE, t, 0.1)
    text(c, "함께한 시간입니다", 820, 104, ACCENT_SOFT, t, 0.5)
    text(c, "사람에게 점수를 매기지 않습니다\n기록은 내 기기와 내 iCloud 에만", 1060, 54, GREY, t, 1.0, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "10년 뒤에도 곁에 있을 사람,\n오늘 한 번 연락해 보세요", 280, 70, INK, t, 0.1)
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


DETAIL = shot("03-person-detail.png")
YEAR = shot("47-year-review.png")


def scenes():
    return [
        (3.8, s_hook),
        (5.0, s_story),
        (3.8, s_insight),
        (2.6, s_turn),
        (2.4, s_reveal),
        # 사람 상세 머리 칸 — 기억할 것(커피는 디카페인 …) · 연락 주기 3개월 (스크린샷 03)
        (3.6, mr.card_closeup(DETAIL, "그 사람에 대해\n기억할 것을 적어 두고", 0.165, 0.70)),
        # 한 해 돌아보기 — 기록 4 · 함께한 사람 3 · 사람의 흐름 (스크린샷 47)
        (3.4, mr.card_closeup(YEAR, "올해 누구와\n시간을 보냈는지 돌아보고", 0.29, 0.72)),
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
