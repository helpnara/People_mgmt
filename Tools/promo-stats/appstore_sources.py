#!/usr/bin/env python3
"""App Store 획득 경로 자동 수집 — 쇼츠 링크로 몇 명이 왔는가 (2026-11-16 사용자).

App Store Connect **Analytics Reports API** 를 쓴다. 표준 라이브러리 + `openssl` 명령만 쓴다(JWT ES256 서명).
결과는 **비공개 저장소에만** 남긴다(2026-11-16 사용자) — 이 저장소는 공개라 문서는 물론 Actions 기록 · 요약 · 결과 파일도
누구나 본다. 그래서 `--out` 으로 파일에만 쓰고, 워크플로가 그 파일을 비공개 저장소(`STATS_REPO`)에 커밋한다.

1. 이 앱의 상시(ONGOING) 보고서 요청이 없으면 하나 만든다. 키 권한이 **관리자(Admin)** 여야 한다.
   요청을 만든 뒤 첫 보고서는 하루 이틀 뒤에 나온다.
2. 보고서 가운데 **App Store Discovery and Engagement**(노출 · 페이지 보기)와 **App Downloads**(내려받기)의
   일 단위 인스턴스를 최근 N일만 받아, 출처 유형(Source Type) · 출처 정보(Source Info, 웹 링크면 들어온 도메인)별로 더한다.

환경 변수: ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8(키 파일 내용) · ASC_APP_ID(기본 6824067748) · DAYS(기본 14)
  python3 appstore_sources.py --out <md>    표를 파일에만 (Actions 에서)
  python3 appstore_sources.py               표를 표준 출력에 (내 컴퓨터에서)
  python3 appstore_sources.py --sample <tsv> <report-name>   받은 파일 하나로 표만 그려 본다 (시험용)
"""
import base64
import collections
import datetime as dt
import gzip
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"
WANT = ("App Store Discovery and Engagement", "App Downloads")


# ── JWT (ES256) ──────────────────────────────────────────────────────────
def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der):
    """openssl 이 주는 DER 서명(SEQUENCE{r, s})을 JWT 가 쓰는 r‖s 64바이트로."""
    def read_int(buf, i):
        assert buf[i] == 0x02
        n = buf[i + 1]
        v = buf[i + 2:i + 2 + n]
        return int.from_bytes(v, "big"), i + 2 + n
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    r, i = read_int(der, i)
    s, _ = read_int(der, i)
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def token():
    need = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"]
    missing = [k for k in need if not os.environ.get(k)]
    if missing:
        raise SystemExit("시크릿이 비어 있습니다: " + ", ".join(missing))
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100,
                           "aud": "appstoreconnect-v1"}).encode())
    signing = f"{head}.{body}".encode()
    with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False) as f:
        f.write(os.environ["ASC_KEY_P8"].strip() + "\n")
        key = f.name
    try:
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key], input=signing,
                             capture_output=True, check=True).stdout
    finally:
        os.unlink(key)
    return f"{head}.{body}.{b64(der_to_raw(der))}"


# ── API ──────────────────────────────────────────────────────────────────
class Client:
    def __init__(self):
        self.jwt = token()

    def call(self, path, body=None):
        url = path if path.startswith("http") else API + path
        for attempt in range(3):
            req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
                                         method="POST" if body else "GET")
            req.add_header("Authorization", f"Bearer {self.jwt}")
            if body:
                req.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                text = e.read().decode("utf-8", "replace")[:800]
                # 잠깐 막힘(429) · 애플 쪽 오류(5xx)는 두 번까지 다시
                if (e.code == 429 or e.code >= 500) and attempt < 2:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise RuntimeError(f"{e.code} {url.split('?')[0]}\n{text}")

    def all(self, path):
        out, url = [], path
        while url:
            r = self.call(url)
            out += r.get("data", [])
            url = r.get("links", {}).get("next")
        return out


def download(url):
    """조각 파일은 서명된 주소라 인증 머리글 없이 받는다. gzip 이면 푼다."""
    last = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                raw = r.read()
            return (gzip.decompress(raw) if raw[:2] == b"\x1f\x8b" else raw).decode("utf-8")
        except (urllib.error.URLError, OSError) as e:
            last = e
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f"조각 파일을 받지 못했습니다: {last}")


def base_name(name):
    """'App Downloads Detailed' → ('App Downloads', 'Detailed')"""
    for kind in ("Detailed", "Standard"):
        if name.endswith(" " + kind):
            return name[: -len(kind) - 1], kind
    return name, ""


def instance_texts(c, rep, since, diag):
    """보고서 하나에서 since 이후 인스턴스의 조각 파일 글을 모은다.
    일 단위(DAILY)를 먼저 쓰고, 하나도 없을 때만 주 단위(WEEKLY)를 쓴다 — 둘을 섞으면 두 번 센다."""
    name = rep["attributes"]["name"]
    for gran in ("DAILY", "WEEKLY"):
        insts = c.all(f"/v1/analyticsReports/{rep['id']}/instances?filter[granularity]={gran}")
        dates = sorted(i["attributes"].get("processingDate", "") for i in insts)
        recent = [i for i in insts if i["attributes"].get("processingDate", "") >= since]
        line = f"{name} · {gran} 인스턴스 {len(insts)}개(기간 안 {len(recent)}개)"
        if dates:
            line += f" · 처리일 {dates[0]} ~ {dates[-1]}"
        texts, segs = [], 0
        for inst in recent:
            for seg in c.all(f"/v1/analyticsReportInstances/{inst['id']}/segments"):
                segs += 1
                texts.append(download(seg["attributes"]["url"]))
        rows = sum(max(0, len([l for l in t.splitlines() if l.strip()]) - 1) for t in texts)
        diag.append(line + f" · 조각 {segs}개 · 자료 줄 {rows}줄")
        if recent:
            return texts, rows
    return [], 0


def fetch_rows(days):
    """반환: (표 이름 → TSV 글 목록, 사용자에게 보일 알림, 진단 줄).
    진단 줄은 개수 · 날짜만 적고 비공개 저장소 파일에만 남는다(공개 Actions 기록에 찍지 않는다)."""
    app = os.environ.get("ASC_APP_ID") or "6824067748"
    c = Client()
    notes, diag = [], []
    reqs = c.all(f"/v1/apps/{app}/analyticsReportRequests?filter[accessType]=ONGOING")
    live = [r for r in reqs if not r["attributes"].get("stoppedDueToInactivity")]
    diag.append(f"상시(ONGOING) 요청 {len(reqs)}개 · 그 가운데 멈춘 것 {len(reqs) - len(live)}개")
    if not live:
        try:
            c.call("/v1/analyticsReportRequests", {"data": {
                "type": "analyticsReportRequests", "attributes": {"accessType": "ONGOING"},
                "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})
        except RuntimeError as e:
            raise SystemExit("보고서 요청을 만들지 못했습니다. 키 권한이 관리자(Admin)인지 보세요.\n" + str(e))
        why = "멈춘 요청(오래 안 읽어서)을 대신할 " if reqs else ""
        notes.append(f"이 앱의 {why}분석 보고서 요청을 새로 만들었습니다. **첫 보고서는 하루 이틀 뒤에** 나옵니다 — 다음 실행부터 숫자가 보입니다.")
        return {}, notes, diag
    since = (dt.date.today() - dt.timedelta(days=days)).isoformat()
    diag.append(f"기간: 처리일 {since} 부터")
    # 같은 이름의 보고서는 자세히(Detailed · 출처 정보가 있다)를 먼저 보고,
    # 그 판에 자료가 없을 때만 표준(Standard)을 쓴다 — 방문이 적으면 애플이 자세히 판을 비워 둔다.
    found = collections.defaultdict(dict)  # 기본 이름 → {판: 보고서}
    for rq in live:
        for rep in c.all(f"/v1/analyticsReportRequests/{rq['id']}/reports"):
            base, kind = base_name(rep["attributes"]["name"])
            if base in WANT:
                found[base].setdefault(kind, rep)
    tables = {}
    for base in WANT:
        if not found.get(base):
            diag.append(f"{base}: 보고서 목록에 아직 없음")
            continue
        for kind in ("Detailed", "Standard", ""):
            rep = found[base].get(kind)
            if not rep:
                continue
            texts, rows = instance_texts(c, rep, since, diag)
            if rows:
                tables[rep["attributes"]["name"]] = texts
                break
    if not tables:
        notes.append(f"최근 {days}일 안의 자료가 아직 없습니다 — 아래 `진단` 에서 어느 단계가 비었는지 보세요.")
    return tables, notes, diag


# ── 더하기 · 그리기 ──────────────────────────────────────────────────────
def pick(cols, *names):
    low = {c.lower(): c for c in cols}
    for n in names:
        if n.lower() in low:
            return low[n.lower()]
    return None


def summarize(name, tsvs):
    """출처 유형 · 출처 정보(· 사건 · 내려받기 종류)별 합. 열 이름이 바뀌어도 있는 것만 쓴다."""
    sums = collections.Counter()
    first = last = None
    group_cols = None
    for text in tsvs:
        lines = [l for l in text.splitlines() if l.strip()]
        if not lines:
            continue
        cols = lines[0].split("\t")
        count = pick(cols, "Counts", "Count", "Total Downloads")
        date = pick(cols, "Date")
        keys = [k for k in (pick(cols, "Event"), pick(cols, "Download Type"), pick(cols, "Source Type"),
                            pick(cols, "Source Info")) if k]
        if not count or not keys:
            continue
        group_cols = keys
        for l in lines[1:]:
            row = dict(zip(cols, l.split("\t")))
            try:
                n = int(float(row.get(count, "0") or 0))
            except ValueError:
                continue
            sums[tuple(row.get(k, "") or "–" for k in keys)] += n
            if date and row.get(date):
                d = row[date]
                first = d if first is None or d < first else first
                last = d if last is None or d > last else last
    if not sums:
        return [f"### {name}", "", "자료 없음", ""]
    out = [f"### {name}", "", f"기간 {first} ~ {last}" if first else "", "",
           "| " + " | ".join(group_cols) + " | 수 |", "|" + "---|" * len(group_cols) + "---:|"]
    for key, n in sorted(sums.items(), key=lambda kv: -kv[1]):
        out.append("| " + " | ".join(k.replace("|", "／") for k in key) + f" | {n:,} |")
    out.append("")
    return out


def main():
    days = int(os.environ.get("DAYS") or 14)
    if "--sample" in sys.argv:
        i = sys.argv.index("--sample")
        tables = {sys.argv[i + 2]: [open(sys.argv[i + 1], encoding="utf-8").read()]}
        notes, diag = [], []
    else:
        tables, notes, diag = fetch_rows(days)
    md = [f"## App Store 획득 경로 — 최근 {days}일", "",
          "웹에서 온 방문은 출처 유형 `Web Referrer`, 쇼츠 링크라면 출처 정보에 `youtube.com` 이 보인다.", ""]
    md += [f"> {n}" for n in notes] + ([""] if notes else [])
    for name in sorted(tables):
        md += summarize(name, tables[name])
    if diag:
        md += ["### 진단", "", "보고서를 어디까지 받았는지(개수 · 날짜만). 숫자가 비면 여기서 멈춘 단계를 본다.", ""]
        md += [f"- {d}" for d in diag] + [""]
    text = "\n".join(md) + "\n"
    if "--out" in sys.argv:
        # 공개 저장소의 Actions 기록은 누구나 본다 — 숫자는 기록에 찍지 않고 파일로만 넘긴다
        with open(sys.argv[sys.argv.index("--out") + 1], "w", encoding="utf-8") as f:
            f.write(text)
        print(f"표 {len(tables)}개를 파일로 넘겼다 (숫자는 기록에 찍지 않는다)")
    else:
        print(text)


if __name__ == "__main__":
    main()
