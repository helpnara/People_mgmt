#!/usr/bin/env python3
"""유튜브 쇼츠 조회수 자동 수집 — 느린 나눔 채널 (2026-11-16 사용자: 화면을 찍어 보내는 일을 없애자).

GitHub Actions(`promo-stats.yml`)가 매주 돌린다. 표준 라이브러리만 쓴다.

1. 채널 주인의 OAuth 갱신 토큰으로 접근 토큰을 받는다 (시크릿 YT_CLIENT_ID · YT_CLIENT_SECRET · YT_REFRESH_TOKEN).
2. YouTube Data API v3 — 채널의 올린 영상 전부 · 영상별 조회수 · 좋아요 · 댓글 수 · 길이 · 설명.
3. YouTube Analytics API — 영상별 평균 시청률 · 평균 시청 시간 (2~3일 늦게 잡힌다).
4. 설명의 해시태그 · 앱 이름으로 앱(인연 · 부자 · 여백)을 가른다.
5. `docs/promo-stats/YYYY-MM-DD.json` 에 원자료를 남기고, `docs/promo-youtube-stats.md` 맨 아래에 새 회차를 더한다.
   지난 원자료가 있으면 영상마다 지난 회차보다 늘어난 조회수를 함께 적는다.

노출 수 · 노출 클릭률은 YouTube Studio 에만 있어 여기서 모으지 않는다.

  python3 youtube_stats.py <repo>                      진짜 수집 (환경 변수 필요)
  python3 youtube_stats.py <repo> --sample <in.json>   원자료 파일로 문서만 다시 쓴다 (시험용 · 네트워크 없음)
"""
import datetime as dt
import json
import os
import pathlib
import re
import statistics
import sys
import urllib.parse
import urllib.request

KST = dt.timezone(dt.timedelta(hours=9))
DATA = "https://www.googleapis.com/youtube/v3"
ANALYTICS = "https://youtubeanalytics.googleapis.com/v2/reports"
APPS = [("인연", ("느린인연", "느린 인연", "slow ties")),
        ("부자", ("느린부자", "느린 부자", "노후")),
        ("여백", ("느린여백", "느린 여백", "slow margin"))]
# 이 저장소는 공개다 — 원자료 · 문서에는 이 날 이후 올린 '공개' 영상만 남긴다.
# 2026-11-18 첫 수집이 일부 공개 · 비공개 영상의 제목 · 주소까지 커밋했다.
# 일부 공개 영상은 주소만 알면 누구나 본다. 채널의 옛 영상(앱과 상관없는 것)도 뺀다.
SERIES_START = "2026-10-01"
APP_NAMES = {"인연": "느린 인연", "부자": "느린 부자", "여백": "느린 여백", "기타": "앱 표시 없음"}


# ── 네트워크 ─────────────────────────────────────────────────────────────
def http_json(url, token=None, data=None):
    req = urllib.request.Request(url, data=data)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:800]
        raise SystemExit(f"요청 실패 {e.code} {url.split('?')[0]}\n{body}")


def access_token():
    need = ["YT_CLIENT_ID", "YT_CLIENT_SECRET", "YT_REFRESH_TOKEN"]
    missing = [k for k in need if not os.environ.get(k)]
    if missing:
        raise SystemExit("시크릿이 비어 있습니다: " + ", ".join(missing) + " — docs/promo/README.md 의 자동 수집 준비를 보세요.")
    body = urllib.parse.urlencode({
        "client_id": os.environ["YT_CLIENT_ID"],
        "client_secret": os.environ["YT_CLIENT_SECRET"],
        "refresh_token": os.environ["YT_REFRESH_TOKEN"],
        "grant_type": "refresh_token",
    }).encode()
    return http_json("https://oauth2.googleapis.com/token", data=body)["access_token"]


def collect():
    token = access_token()
    ch = http_json(f"{DATA}/channels?part=contentDetails,snippet&mine=true", token)["items"][0]
    uploads = ch["contentDetails"]["relatedPlaylists"]["uploads"]
    ids, page = [], ""
    while True:
        q = urllib.parse.urlencode({"part": "contentDetails", "playlistId": uploads, "maxResults": 50, "pageToken": page})
        r = http_json(f"{DATA}/playlistItems?{q}", token)
        ids += [it["contentDetails"]["videoId"] for it in r.get("items", [])]
        page = r.get("nextPageToken")
        if not page:
            break
    videos = []
    for k in range(0, len(ids), 50):
        q = urllib.parse.urlencode({"part": "snippet,statistics,contentDetails,status", "id": ",".join(ids[k:k + 50])})
        for it in http_json(f"{DATA}/videos?{q}", token).get("items", []):
            st = it.get("statistics", {})
            videos.append({
                "id": it["id"],
                "title": it["snippet"]["title"],
                "description": it["snippet"].get("description", ""),
                "publishedAt": it["snippet"]["publishedAt"],
                "privacy": it.get("status", {}).get("privacyStatus", ""),
                "seconds": iso_seconds(it["contentDetails"].get("duration", "")),
                "views": int(st.get("viewCount", 0)),
                "likes": int(st.get("likeCount", 0)),
                "comments": int(st.get("commentCount", 0)),
            })
    # 평균 시청률 · 시청 시간 — 영상 차원은 maxResults 200 · 정렬이 있어야 한다
    today = dt.datetime.now(KST).date().isoformat()
    q = urllib.parse.urlencode({
        "ids": "channel==MINE", "startDate": "2020-01-01", "endDate": today,
        "metrics": "views,averageViewDuration,averageViewPercentage",
        "dimensions": "video", "sort": "-views", "maxResults": 200,
    })
    rep = http_json(f"{ANALYTICS}?{q}", token)
    cols = [h["name"] for h in rep.get("columnHeaders", [])]
    for row in rep.get("rows", []) or []:
        m = dict(zip(cols, row))
        for v in videos:
            if v["id"] == m.get("video"):
                v["avgViewPercent"] = round(float(m["averageViewPercentage"]), 1)
                v["avgViewSeconds"] = round(float(m["averageViewDuration"]))
    return {"channel": ch["snippet"]["title"], "collectedAt": dt.datetime.now(KST).isoformat(timespec="minutes"),
            "videos": videos}


def keep(v):
    return v.get("privacy") == "public" and v.get("publishedAt", "") >= SERIES_START


def iso_seconds(s):
    m = re.fullmatch(r"P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", s or "")
    if not m:
        return 0
    d, h, mi, se = (int(x or 0) for x in m.groups())
    return d * 86400 + h * 3600 + mi * 60 + se


# ── 가르기 · 쓰기 ─────────────────────────────────────────────────────────
def app_of(v):
    hay = (v["title"] + "\n" + v["description"]).lower()
    for key, words in APPS:
        if any(w in hay for w in words):
            return key
    return "기타"


def cell(s):
    return s.replace("|", "／").replace("\n", " ").strip()


def views_text(n):
    return f"{n:,}"


def summary_rows(groups):
    rows, every = [], []
    for key in ["인연", "부자", "여백", "기타"]:
        vs = groups.get(key, [])
        if not vs:
            continue
        views = [v["views"] for v in vs]
        every += views
        rows.append((APP_NAMES[key], views))
    rows.append(("**모두**", every))
    out = []
    for name, views in rows:
        out.append(f"| {name} | {len(views)} | {views_text(sum(views))} | {round(sum(views) / len(views)):,} | "
                   f"{statistics.median(views):,.0f} | {sum(1 for x in views if x >= 500)} |")
    return out


def render(snapshot, previous, number):
    at = dt.datetime.fromisoformat(snapshot["collectedAt"])
    shown = [v for v in snapshot["videos"] if v["privacy"] == "public" and 0 < v["seconds"] <= 180]
    shown.sort(key=lambda v: v["publishedAt"], reverse=True)
    prev = {v["id"]: v["views"] for v in (previous or {}).get("videos", [])}
    prev_at = (previous or {}).get("collectedAt", "")[:10]
    groups = {}
    for v in shown:
        groups.setdefault(app_of(v), []).append(v)
    has_watch = any("avgViewPercent" in v for v in shown)

    def age(v):
        pub = dt.datetime.fromisoformat(v["publishedAt"].replace("Z", "+00:00")).astimezone(KST)
        return pub.strftime("%m-%d"), (at - pub).days

    def line(v, with_app):
        day, days = age(v)
        cells = []
        if with_app:
            cells.append(APP_NAMES[app_of(v)].replace("느린 ", ""))
        cells += [day, f"{days}일", cell(v["title"]), views_text(v["views"])]
        if previous is not None:
            cells.append(f"+{v['views'] - prev[v['id']]:,}" if v["id"] in prev else "새 영상")
        cells += [str(v["likes"]), str(v["comments"])]
        if has_watch:
            cells += [f"{v['avgViewPercent']}%" if "avgViewPercent" in v else "–",
                      f"{v['avgViewSeconds']}초" if "avgViewSeconds" in v else "–"]
        return "| " + " | ".join(cells) + " |"

    head = ["올린 날", "올린 지", "제목", "조회수"]
    if previous is not None:
        head.append(f"{prev_at} 보다")
    head += ["좋아요", "댓글"]
    if has_watch:
        head += ["평균 시청률", "평균 시청 시간"]

    def table(rows, with_app):
        h = (["앱"] if with_app else []) + head
        right = {"조회수", "좋아요", "댓글", "평균 시청률", "평균 시청 시간", f"{prev_at} 보다", "올린 지"}
        return ["| " + " | ".join(h) + " |", "|" + "|".join("---:" if x in right else "---" for x in h) + "|"] + \
               [line(v, with_app) for v in rows]

    out = [
        "", "---", "",
        f"## {number}회차 — {at.strftime('%Y-%m-%d %H:%M')} (한국 시간 · 자동 수집)",
        "",
        f"`promo-stats.yml` 이 YouTube Data · Analytics API 로 모았다. 공개된 쇼츠(3분 이하) {len(shown)}편 · 조회수는 반올림 없는 값이다.",
        "평균 시청률 · 시청 시간은 2~3일 늦게 잡혀 최근 영상은 비어 있을 수 있다. 노출 수 · 노출 클릭률은 API 에 없어 YouTube Studio 에서만 본다.",
        f"원자료: `promo-stats/{at.date().isoformat()}.json`",
        "",
        "### 앱별 요약",
        "",
        "| 앱 | 편 수 | 조회수 합 | 평균 | 가운데값 | 500 넘은 편 |",
        "|---|---:|---:|---:|---:|---:|",
        *summary_rows(groups),
        "",
        f"### 느린 인연 쇼츠 {len(groups.get('인연', []))}편 (최근 것부터)",
        "",
        *table(groups.get("인연", []), with_app=False),
        "",
        "### 모든 쇼츠 (최근 것부터)",
        "",
        *table(shown, with_app=True),
        "",
    ]
    return "\n".join(out)


def main():
    repo = pathlib.Path(sys.argv[1])
    stats_dir = repo / "docs" / "promo-stats"
    doc = repo / "docs" / "promo-youtube-stats.md"
    if "--sample" in sys.argv:
        snapshot = json.loads(pathlib.Path(sys.argv[sys.argv.index("--sample") + 1]).read_text(encoding="utf-8"))
    else:
        snapshot = collect()
    snapshot["videos"] = [v for v in snapshot["videos"] if keep(v)]
    stats_dir.mkdir(parents=True, exist_ok=True)
    day = snapshot["collectedAt"][:10]
    olders = sorted(p for p in stats_dir.glob("*.json") if p.stem < day)
    previous = json.loads(olders[-1].read_text(encoding="utf-8")) if olders else None
    (stats_dir / f"{day}.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    text = doc.read_text(encoding="utf-8")
    # 같은 날 다시 돌리면 그날 회차를 바꿔 쓴다
    same_day = re.search(rf"\n\n---\n\n## \d+회차 — {day} [^\n]*자동 수집\)\n.*?(?=\n\n---\n\n## |\Z)", text, re.S)
    if same_day:
        text = text[:same_day.start()] + text[same_day.end():]
    number = len(re.findall(r"^## \d+회차", text, re.M)) + 1
    doc.write_text(text.rstrip("\n") + "\n" + render(snapshot, previous, number), encoding="utf-8")
    print(f"{doc.name} 에 {number}회차를 더했다 — 영상 {len(snapshot['videos'])}편")


if __name__ == "__main__":
    main()
