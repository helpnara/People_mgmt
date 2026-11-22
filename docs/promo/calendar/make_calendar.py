#!/usr/bin/env python3
"""느린 나눔 쇼츠 게시 달력 — A4 가로 · 한 달 한 장 PDF (2026-11-21 사용자: 일정 관리용 출력).

  python3 docs/promo/calendar/make_calendar.py            → docs/promo/calendar/shorts-calendar.html 을 만든다
  node docs/promo/calendar/pdf.mjs                        → shorts-calendar.pdf (A4 가로)

자료: 공개된 영상 = docs/promo-stats/ 의 가장 최근 JSON(제목 · 공개 시각 · 조회수) ·
예약 · 만들 것 · 수집 뒤 공개분 = schedule.json(손으로 고친다). 예약 시각이 지났으면 '공개'로 보인다(조회수는 다음 수집에).
고정 댓글 = schedule.json 의 "pin" — 달림 · 확인 필요 · 게시 뒤 (2026-11-22 사용자: 고정 댓글 완료도 일정표에 적어 리마인드).
  수집 자료에만 있는 옛 편은 달림으로 본다. 공개됐는데 달림이 아니면 칸에 '고정 댓글 달기' 가 뜨고, 실행하면 남은 목록을 찍는다.
글꼴: fonts/ 에 Noto Sans KR 500 · 700 · 900 (커밋 안 함 — README).
"""
import calendar
import datetime as dt
import html
import json
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
K = dt.timezone(dt.timedelta(hours=9))
NOW = dt.datetime.now(K)
APPS = {"부자": ("느린 부자", "#C8962E", "#FBF3E2"), "여백": ("느린 여백", "#4F8A3A", "#EEF5E9"), "인연": ("느린 인연", "#8B4C8C", "#F5ECF5")}


def app_of(t):
    if any(k in t for k in ["여백", "노트", "메모"]) or "slow margin" in t.lower():
        return "여백"
    if any(k in t for k in ["노후", "투자", "연금", "자산", "리밸런싱", "종목", "52번", "#Shorts", "퇴직", "부자"]):
        return "부자"
    return "인연"


def short(t):
    t = re.sub(r"[\U0001F300-\U0001FAFF]", "", t)
    for cut in [" — ", " | ", " ／ ", " #", "‘느린"]:
        if cut in t:
            t = t.split(cut)[0]
    return t.strip()


def load():
    stats = sorted((REPO / "docs/promo-stats").glob("2*.json"))[-1]
    data = json.loads(stats.read_text(encoding="utf-8"))
    items = []
    for v in data["videos"]:
        p = dt.datetime.fromisoformat(v["publishedAt"].replace("Z", "+00:00")).astimezone(K)
        hub = v["seconds"] > 180
        items.append(dict(at=p, app=app_of(v["title"]), title=("허브 · " if hub else "") + short(v["title"]),
                          status="공개", views=v["views"]))
    sched = json.loads((HERE / "schedule.json").read_text(encoding="utf-8"))["items"]
    pins = {(s["at"][5:], s["app"]): s.get("pin", "게시 뒤") for s in sched}
    for i in items:
        i["pin"] = pins.get((i["at"].strftime("%m-%d %H:%M"), i["app"]), "달림")
    seen = {(i["at"].strftime("%m-%d %H:%M"), i["app"]) for i in items}
    for s in sched:
        at = dt.datetime.strptime(s["at"], "%Y-%m-%d %H:%M").replace(tzinfo=K)
        if (at.strftime("%m-%d %H:%M"), s["app"]) in seen:
            continue
        status = s["status"]
        if status == "예약" and at <= NOW:
            status = "공개"
        items.append(dict(at=at, app=s["app"], title=s["title"], status=status, views=None, pin=s.get("pin", "게시 뒤")))
    return sorted(items, key=lambda i: i["at"]), data["collectedAt"]


def chip(i):
    if i["status"] == "공개":
        return f'<span class="st pub">{"공개 · " + format(i["views"], ",") if i["views"] is not None else "공개 · 집계 전"}</span>'
    if i["status"] == "예약":
        return '<span class="st res">예약</span>'
    if i["status"] == "후보":
        return '<span class="st cand">후보</span>'
    if i["status"] == "올릴 것":
        return '<span class="st up">올릴 것</span>'
    return '<span class="st todo">만들 것</span>'


def pin_pending(i):
    """공개됐는데 고정 댓글이 아직 달림이 아닌 편."""
    return i["status"] == "공개" and i.get("pin", "달림") != "달림"


def pin_line(i):
    if pin_pending(i):
        word = "고정 댓글 — 달았나요?" if i["pin"] == "확인 필요" else "고정 댓글 달기"
        return f'<div class="pin due">● {word}</div>'
    if i["status"] == "예약":
        return '<div class="pin">고정 댓글 · 게시 뒤</div>'
    return ""


def month_page(year, month, items, collected):
    mitems = [i for i in items if i["at"].year == year and i["at"].month == month]
    by_day = {}
    for i in mitems:
        by_day.setdefault(i["at"].day, []).append(i)
    cal = calendar.Calendar(firstweekday=6)  # 일요일부터
    weeks = cal.monthdayscalendar(year, month)
    counts = {a: sum(1 for i in mitems if i["app"] == a) for a in APPS}
    st = {s: sum(1 for i in mitems if i["status"] == s) for s in ["공개", "예약", "올릴 것", "만들 것", "후보"]}
    views = sum(i["views"] or 0 for i in mitems)
    pin_left = sum(1 for i in mitems if pin_pending(i))
    legend = "".join(f'<span class="lg"><i style="background:{c}"></i>{n} <b>{counts[a]}</b></span>' for a, (n, c, _) in APPS.items())
    rows = []
    for w in weeks:
        cells = []
        for idx, d in enumerate(w):
            if d == 0:
                cells.append('<td class="empty"></td>')
                continue
            today = (year, month, d) == (NOW.year, NOW.month, NOW.day)
            cls = ["day"] + (["sun"] if idx == 0 else []) + (["sat"] if idx == 6 else []) + (["today"] if today else []) + (["dense"] if len(by_day.get(d, [])) >= 3 else [])
            ents = []
            for i in by_day.get(d, []):
                name, color, soft = APPS[i["app"]]
                ents.append(
                    f'<div class="e {i["status"].replace(" ", "")}" style="--c:{color};--s:{soft}">'
                    f'<div class="l1"><b>{i["at"]:%H:%M}</b><span class="ap">{i["app"]}</span>{chip(i)}</div>'
                    f'<div class="l2">{html.escape(i["title"])}</div>{pin_line(i)}</div>')
            cells.append(f'<td class="{" ".join(cls)}"><div class="dn">{d}{"<em>오늘</em>" if today else ""}</div>{"".join(ents)}</td>')
        rows.append("<tr>" + "".join(cells) + "</tr>")
    head = "".join(f'<th class="{c}">{n}</th>' for n, c in zip("일월화수목금토", ["sun", "", "", "", "", "", "sat"]))
    return f'''<section class="page">
  <header>
    <div class="t"><span class="ch">느린 나눔 · 쇼츠 게시 달력</span><h1>{year}년 {month}월</h1></div>
    <div class="sum">
      <div class="legend">{legend}</div>
      <div class="meta">공개 <b>{st["공개"]}</b> · 예약 <b>{st["예약"]}</b> · 올릴 것 <b>{st["올릴 것"]}</b> · 만들 것 <b>{st["만들 것"]}</b>{" · 후보 <b>" + str(st["후보"]) + "</b>" if st["후보"] else ""} · 공개분 조회수 합 <b>{views:,}</b>{' · <span class="due">고정 댓글 남음 <b>' + str(pin_left) + '</b></span>' if pin_left else ''}</div>
    </div>
  </header>
  <table class="cal rows{len(weeks)}"><thead><tr>{head}</tr></thead><tbody>{"".join(rows)}</tbody></table>
  <footer>조회수는 {collected[:16].replace("T", " ")} 수집 기준 · 시각은 한국 시간 · 공개 · 집계 전 = 수집 뒤 공개되어 다음 수집에 들어감{" · 후보 = 브레인스토밍 주제, 12-11 시험 판정(여백 · 인연 돈 · 시간 다리) 뒤 바뀔 수 있음" if st["후보"] else ""} · 만든 날 {NOW:%Y-%m-%d %H:%M}</footer>
</section>'''


CSS = """
@font-face{font-family:K;font-weight:500;src:url('fonts/NotoSansKR-500.ttf')}
@font-face{font-family:K;font-weight:700;src:url('fonts/NotoSansKR-700.ttf')}
@font-face{font-family:K;font-weight:900;src:url('fonts/NotoSansKR-900.ttf')}
@page{size:A4 landscape;margin:0}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:K,sans-serif;color:#24211E;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.page{width:297mm;height:210mm;padding:9mm 10mm 7mm;display:flex;flex-direction:column;page-break-after:always;background:#FBF9F5}
header{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:4mm}
.t .ch{display:block;font-size:8.5pt;font-weight:700;letter-spacing:2.5pt;color:#8A8276}
.t h1{font-size:22pt;font-weight:900;letter-spacing:-.5pt;margin-top:.5mm}
.sum{text-align:right}
.legend{display:flex;gap:5mm;justify-content:flex-end;font-size:8.5pt;font-weight:500;color:#4A4640}
.lg{display:flex;align-items:center;gap:1.6mm}.lg i{width:3mm;height:3mm;border-radius:1mm;display:inline-block}.lg b{font-weight:900;color:#24211E}
.meta{margin-top:1.6mm;font-size:8pt;color:#6B655C}.meta b{color:#24211E;font-weight:700}
table.cal{flex:1;width:100%;border-collapse:separate;border-spacing:1.2mm;table-layout:fixed;margin:-1.2mm}
.cal.rows4 tbody tr{height:40mm}.cal.rows5 tbody tr{height:32.5mm}.cal.rows6 tbody tr{height:27mm}
th{font-size:8pt;font-weight:700;color:#6B655C;text-align:left;padding:0 1.5mm 1mm;height:5mm}
th.sun,td.sun .dn{color:#C0533F} th.sat,td.sat .dn{color:#3F6FA8}
td{vertical-align:top;background:#fff;border-radius:2.2mm;padding:1.4mm 1.4mm 1mm;border:.25mm solid #ECE6DB;overflow:hidden}
td.empty{background:transparent;border:none}
td.today{border:.5mm solid #24211E}
.dn{font-size:9pt;font-weight:900;color:#4A4640;margin-bottom:.8mm;display:flex;align-items:center;gap:1.5mm}
.dn em{font-style:normal;font-size:6.5pt;font-weight:700;background:#24211E;color:#fff;border-radius:1mm;padding:.2mm 1.2mm}
.e{border-left:1mm solid var(--c);background:var(--s);border-radius:1mm;padding:.6mm 1.2mm .7mm 1.4mm;margin-bottom:.8mm}
.e.만들것{background:#fff;border:.25mm dashed var(--c);border-left:1mm solid var(--c)}
.e.올릴것{background:#fff;border:.25mm solid var(--c);border-left:1mm solid var(--c)}
.e.후보{background:#fff;border:.25mm dashed #C9C2B6;border-left:1mm solid var(--c);opacity:.92}
.l1{display:flex;align-items:center;gap:1.2mm;font-size:7pt;line-height:1.25}
.pin{font-size:6pt;font-weight:500;color:#8A8276;margin-top:.3mm}.pin.due,.due{color:#C0533F;font-weight:700}
.l1 b{font-weight:900}.l1 .ap{font-weight:700;color:var(--c)}
.st{margin-left:auto;font-size:6pt;font-weight:700;border-radius:.8mm;padding:.1mm 1mm;white-space:nowrap}
.st.pub{background:#24211E;color:#fff}.st.res{background:#fff;color:#24211E;border:.25mm solid #24211E}.st.todo{background:#fff;color:#C0533F;border:.25mm solid #C0533F}.st.up{background:#C0533F;color:#fff}.st.cand{background:#fff;color:#8A8276;border:.25mm dashed #8A8276}
.l2{font-size:6.6pt;font-weight:500;color:#3A3631;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;word-break:keep-all;margin-top:.2mm}
footer{margin-top:2.5mm;font-size:6.8pt;color:#8A8276}
td.dense .l2{display:block;white-space:nowrap;text-overflow:ellipsis}
"""


def main():
    items, collected = load()
    months = sorted({(i["at"].year, i["at"].month) for i in items})
    pages = "".join(month_page(y, m, items, collected) for y, m in months)
    out = HERE / "shorts-calendar.html"
    out.write_text(f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>느린 나눔 쇼츠 게시 달력</title><style>{CSS}</style></head><body>{pages}</body></html>', encoding="utf-8")
    print(out, "·", len(items), "편 ·", ", ".join(f"{y}-{m:02d}" for y, m in months))
    due = [i for i in items if pin_pending(i)]
    soon = [i for i in items if i["status"] == "예약"][:4]
    print("고정 댓글 남은 것:", "없음" if not due else "")
    for i in due:
        print(f"  - {i['at']:%m-%d %H:%M} {i['app']} · {i['title']} ({i['pin']})")
    if soon:
        print("게시 뒤 달 것(다가오는 예약):", " · ".join(f"{i['at']:%m-%d %H:%M} {i['app']}" for i in soon))


if __name__ == "__main__":
    main()
