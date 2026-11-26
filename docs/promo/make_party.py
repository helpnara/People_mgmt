#!/usr/bin/env python3
"""느린 인연 유튜브 쇼츠 17 (1080 × 1920 · 30fps · 약 31초) — 컨셉: 송년회 12명, 작년엔 무슨 얘기 했더라? (2026-11-27).

일정표 12-04(금) 12:00 칸. 돈 · 시간 다리 2주 시험의 둘째 주(`../promo-youtube-stats.md`) — 첫 물음에 사람 수 12명 · 3시간.
앞 편과 겹치지 않게 **한 기록에 여러 사람(N:M) · 기록 틀** 을 보인다 — 14편(찾기) · 16편(사람 화면 · 기억할 것)과 다른 자리.
반복(`RepeatRule`)은 매주 · 2주 · 매달뿐이라 해마다 하는 송년회는 **기록 틀**로 잇는다.
**0초 장면에 질문 글이 이미 다 떠 있다** (`README.md` 문안 규칙).
앱 문구 그대로 다시 그렸다:
- 기록 상세(`RecordDetailView`, screenshots/09 의 꼴) — 유형 아이콘 · `친목 · 날짜` · 제목 · 장소, `함께한 사람` 줄, `메모`, `태그`.
- 사람 화면 타임라인 줄(`TimelineRow`) — 같은 기록이 함께한 사람마다 보인다(기록은 한 번만 저장 · ADR-0003).
- 기록 추가(`RecordEditView`, screenshots/51 의 꼴) — 맨 위 `틀` 칩(새 기록이고 틀이 있을 때만) · 안내
  `자주 쓰는 기록 모양을 누르면 유형 · 제목 · 장소 · 태그 · 함께한 사람이 채워집니다. 날짜 · 메모는 그대로입니다.` ·
  `함께한 사람` 줄 요약 `이름, 이름 외 n명`(participantSummary). 틀을 누르면 연 사람이 맨 앞, 틀의 사람은 가나다순(TemplateStore.fill).
- 틀 만들기 — 기록 수정 맨 아래 `이 기록을 틀로 저장` · `설정 → 기록 틀에서 이름을 바꾸거나 뺄 수 있습니다.`
사람 · 기록은 모두 지어낸 것이다 (CLAUDE.md §2).
  python3 make_party.py <repo> <out.mp4>          영상
  python3 make_party.py <repo> <out.png> <초>     그 초의 한 장
"""
import math
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
chevron = msr.chevron
SHOWN = -1.0

# 가나다순 (NameSort) — 모두 지어낸 이름
PEOPLE = ["강태오", "김하늘", "문하준", "박서연", "서지안", "오세린", "윤서아", "이도윤", "임채원", "정유진", "최민준", "한지우"]
DATE = "2025년 12월 19일"
TITLE = "동기 송년회"
MEMO = ["도윤 판교로 이직 · 서연 둘째 소식", "봄에 다 같이 북한산 가기로"]


def people_icon(d, cx, cy, col, s=1.0):
    """함께한 사람 아이콘 (person.3 꼴) — 친목 유형."""
    for dx, r in ((-22, 11), (22, 11), (0, 13)):
        d.ellipse((cx + dx * s - r * s, cy - 18 * s - r * s, cx + dx * s + r * s, cy - 18 * s + r * s), outline=col, width=4)
    for dx, w in ((-22, 18), (22, 18), (0, 22)):
        d.arc((cx + dx * s - w * s, cy + 2 * s, cx + dx * s + w * s, cy + 40 * s), 180, 360, fill=col, width=4)


# ── 1 첫 장면 — 0초부터 다 떠 있는 질문 + 둥근 탁자의 12명 ─────────────────────────────
def s_hook(t):
    c = DARK_BG.convert("RGBA")
    text(c, "1년에 한 번 보는 얼굴들", 250, 54, GREY, t, SHOWN, path=MED)
    text(c, "송년회 12명,\n작년엔 무슨\n얘기 했더라?", 350, 104, WHITE, t, SHOWN)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, R = W / 2, 1340, 300
    d.ellipse((cx - 170, cy - 170, cx + 170, cy + 170), fill=DARK_CARD + (255,))
    for k in range(12):
        ang = -math.pi / 2 + k * 2 * math.pi / 12
        x, y = cx + R * math.cos(ang), cy + R * math.sin(ang)
        a = round(255 * (0.55 + 0.35 * (0.5 + 0.5 * math.sin(t * 3.0 + k * 0.55))))
        d.ellipse((x - 46, y - 46, x + 46, y + 46), fill=(70, 80, 88, a))
        d.text((x, y), "?", font=font(BOLD, 48), fill=(232, 236, 238, a), anchor="mm")
    c.alpha_composite(layer)
    return c


def s_why(t):
    c = DARK_BG.convert("RGBA")
    text(c, "누가 이직했다고 했지?", 560, 84, WHITE, t, 0.1)
    text(c, "누구네 둘째 소식이었지?", 690, 84, ACCENT_SOFT, t, 0.55)
    text(c, "3시간 나눈 이야기, 1년이면 흐려져요", 900, 50, GREY, t, 1.2, path=MED)
    return c


def s_reveal(t):
    c = LIGHT_BG.convert("RGBA")
    ms.icon_at(c, 300, 620, ease(t / 0.5), scale=0.85 + 0.15 * ease(t / 0.6))
    text(c, "느린 인연", 840, 120, INK, t, 0.35)
    text(c, "기록 하나에 12명 모두", 1040, 56, ACCENT, t, 0.8, path=MED)
    return c


# ── 4 작년 기록 하나 — 기록 상세 (RecordDetailView · screenshots/09) ──────────────────────
def s_record(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "작년 송년회,\n기록 하나", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    # 머리 카드
    y0 = 470
    card(c, (x0, y0, x1, y0 + 260), a)
    d = ImageDraw.Draw(c)
    people_icon(d, x0 + 70, y0 + 66, ACCENT + (fa,), 0.8)
    d.text((x0 + 120, y0 + 66), "친목 · " + DATE, font=font(MED, 38), fill=ACCENT + (fa,), anchor="lm")
    d.text((x0 + 46, y0 + 150), TITLE, font=font(BOLD, 62), fill=INK + (fa,), anchor="lm")
    d.text((x0 + 46, y0 + 220), "을지로", font=font(MED, 40), fill=BODY + (fa,), anchor="lm")
    # 함께한 사람
    b = ease((t - 0.7) / 0.35) * a
    fb = round(255 * b)
    d.text((x0 + 30, 800), "함께한 사람 12", font=font(MED, 42), fill=MUTED + (fb,), anchor="ls")
    y1 = 830
    card(c, (x0, y1, x1, y1 + 300), b)
    d = ImageDraw.Draw(c)
    for k, name in enumerate(["강태오", "김하늘", "문하준"]):
        y = y1 + 50 + k * 100
        d.text((x0 + 46, y), name, font=font(BOLD, 44), fill=INK + (fb,), anchor="lm")
        chevron(d, x1 - 60, y, MUTED + (fb,))
        if k < 2:
            d.line((x0 + 46, y + 50, x1, y + 50), fill=RULE + (fb,), width=2)
    d.text((W / 2, y1 + 300 + 44), "… 9명 더", font=font(MED, 38), fill=MUTED + (fb,), anchor="mm")
    # 메모
    m = ease((t - 1.3) / 0.35) * a
    fm = round(255 * m)
    d.text((x0 + 30, 1250), "메모", font=font(MED, 42), fill=MUTED + (fm,), anchor="ls")
    y2 = 1280
    card(c, (x0, y2, x1, y2 + 200), m)
    d = ImageDraw.Draw(c)
    for k, s_ in enumerate(MEMO):
        d.text((x0 + 46, y2 + 64 + k * 74), s_, font=font(MED, 44), fill=INK + (fm,), anchor="lm")
    if t > 2.0:
        r = ease((t - 2.0) / 0.35)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle((x0 - 14, y2 - 14, x1 + 14, y2 + 214), radius=40, outline=ACCENT + (round(255 * r),), width=8)
        c.alpha_composite(layer)
    text(c, "그날 나눈 이야기는 메모 한 줄", 1600, 46, MUTED, t, 2.4, path=MED)
    return c


# ── 5 12명 모두의 타임라인에 (TimelineRow · ADR-0003 — 기록은 한 번만 저장) ─────────────────
def s_everyone(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "적은 건 한 번,\n12명 타임라인 모두에", 130, 84, INK, t, 0.05)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    gx, gy = 240, 170
    x0 = (W - 3 * gx) / 2
    for k, name in enumerate(PEOPLE):
        r, col = divmod(k, 4)
        cx, cy = x0 + col * gx, 560 + r * gy
        a = ease((t - 0.3 - k * 0.09) / 0.3)
        if a <= 0:
            continue
        on = t > 1.6 + k * 0.06
        fill = (MINT if on else CHIP_BG) + (round(255 * a),)
        d.ellipse((cx - 44, cy - 60, cx + 44, cy + 28), fill=fill)
        d.text((cx, cy - 16), name[0], font=font(BOLD, 42), fill=(ACCENT if on else BODY) + (round(255 * a),), anchor="mm")
        d.text((cx, cy + 62), name, font=font(MED, 32), fill=INK + (round(255 * a),), anchor="mm")
    c.alpha_composite(layer)
    b = ease((t - 2.3) / 0.35)
    if b > 0:
        fb = round(255 * b)
        x0, x1, y0 = 60, W - 60, 1110
        d = ImageDraw.Draw(c)
        d.text((x0 + 30, y0 - 26), "이도윤 · 타임라인", font=font(MED, 40), fill=MUTED + (fb,), anchor="ls")
        card(c, (x0, y0, x1, y0 + 260), b)
        d = ImageDraw.Draw(c)
        people_icon(d, x0 + 70, y0 + 74, ACCENT + (fb,), 0.8)
        d.text((x0 + 120, y0 + 70), DATE, font=font(MED, 36), fill=MUTED + (fb,), anchor="lm")
        d.text((x0 + 120, y0 + 140), TITLE, font=font(BOLD, 48), fill=INK + (fb,), anchor="lm")
        d.text((x0 + 120, y0 + 206), MEMO[0], font=font(MED, 38), fill=BODY + (fb,), anchor="lm")
        chevron(d, x1 - 60, y0 + 150, MUTED + (fb,))
    text(c, "누구 화면을 열어도 그날 이야기가 보입니다", 1530, 44, MUTED, t, 2.8, path=MED)
    return c


# ── 6 올해는 틀 한 번 (RecordEditView · screenshots/51 · TemplateStore.fill) ──────────────
def s_template(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "올해는\n틀 한 번으로 12명", 130, 84, INK, t, 0.05)
    a = ease((t - 0.25) / 0.35)
    if a <= 0:
        return c
    fa = round(255 * a)
    x0, x1 = 60, W - 60
    d = ImageDraw.Draw(c)
    d.text((W / 2, 470), "기록 추가", font=font(BOLD, 46), fill=INK + (fa,), anchor="mm")
    d.text((x0 + 30, 580), "틀", font=font(MED, 40), fill=MUTED + (fa,), anchor="ls")
    y0 = 605
    card(c, (x0, y0, x1, y0 + 140), a)
    d = ImageDraw.Draw(c)
    picked = t > 1.3
    for k, (s_, w) in enumerate((("점심 약속", 210), ("동기 송년회", 250))):
        cx0 = x0 + 36 + k * 250
        sel = picked and k == 1
        d.rounded_rectangle((cx0, y0 + 36, cx0 + w, y0 + 104), radius=34,
                            fill=(MINT if sel else CHIP_BG) + (fa,), outline=(ACCENT + (fa,)) if sel else None, width=3)
        d.text((cx0 + w / 2, y0 + 70), s_, font=font(MED, 36), fill=(ACCENT if sel else BODY) + (fa,), anchor="mm")
    tap_ring(c, x0 + 36 + 250 + 125, y0 + 70, t, 1.0)
    d = ImageDraw.Draw(c)
    d.multiline_text((x0 + 30, y0 + 165), "자주 쓰는 기록 모양을 누르면 유형 · 제목 · 장소 · 태그 · 함께한\n사람이 채워집니다. 날짜 · 메모는 그대로입니다.",
                     font=font(MED, 31), fill=MUTED + (fa,), spacing=10)
    # 채워지는 칸
    rows = [("유형", "친목" if picked else "식사"), ("제목", TITLE if picked else ""), ("장소", "을지로" if picked else ""),
            ("함께한 사람", "이도윤, 강태오 외 10명" if picked else "이도윤")]
    y1 = 900
    card(c, (x0, y1, x1, y1 + 4 * 120), a)
    d = ImageDraw.Draw(c)
    f = ease((t - 1.45) / 0.3) if picked else 0
    for k, (lab, val) in enumerate(rows):
        y = y1 + 60 + k * 120
        d.text((x0 + 46, y), lab, font=font(MED, 42), fill=INK + (fa,), anchor="lm")
        if val:
            col = ACCENT if (picked and f > 0) else BODY
            d.text((x1 - 46, y), val, font=font(BOLD if picked else MED, 42), fill=col + (fa,), anchor="rm")
        if k < 3:
            d.line((x0 + 46, y + 60, x1, y + 60), fill=RULE + (fa,), width=2)
    if picked and t > 1.8:
        r = ease((t - 1.8) / 0.35)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle((x0 - 14, y1 + 3 * 120 - 6, x1 + 14, y1 + 4 * 120 + 14), radius=36,
                                                outline=ACCENT + (round(255 * r),), width=8)
        c.alpha_composite(layer)
    text(c, "작년 기록 수정 맨 아래\n이 기록을 틀로 저장", 1490, 46, ACCENT, t, 2.6, path=MED)
    return c


def s_msg(t):
    c = DARK_BG.convert("RGBA")
    text(c, "송년회 끝나고 30초", 620, 84, WHITE, t, 0.1)
    text(c, "메모 한 줄이면", 750, 96, ACCENT_SOFT, t, 0.55)
    text(c, "내년 송년회의 첫마디가 됩니다", 960, 52, GREY, t, 1.2, path=MED)
    return c


def s_end(t):
    c = LIGHT_BG.convert("RGBA")
    text(c, "올해 송년회도\n기록 하나에 12명", 280, 66, INK, t, 0.1)
    ms.icon_at(c, 220, 790, ease((t - 0.6) / 0.5), scale=0.9 + 0.1 * ease((t - 0.6) / 0.6))
    text(c, "느린 인연", 930, 100, INK, t, 0.8)
    a = ease((t - 1.3) / 0.45)
    if a > 0:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = font(BOLD, 46)
        chips = ["무료", "회원가입 없음", "광고 없음"]
        widths = [d.textlength(s_, font=f) + 70 for s_ in chips]
        x = (W - (sum(widths) + 24 * (len(chips) - 1))) / 2
        y = 1090 + (1 - a) * 30
        for s_, w in zip(chips, widths):
            d.rounded_rectangle((x, y, x + w, y + 92), radius=46, fill=ACCENT + (round(255 * a),))
            d.text((x + w / 2, y + 46), s_, font=f, fill=(255, 255, 255, round(255 * a)), anchor="mm")
            x += w + 24
        c.alpha_composite(layer)
    text(c, "App Store 에서\n느린 인연 검색", 1250, 72, ACCENT, t, 1.9)
    return c


def scenes():
    return [
        (3.6, s_hook),
        (3.2, s_why),
        (2.4, s_reveal),
        (4.8, s_record),
        (4.6, s_everyone),
        (4.8, s_template),
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
