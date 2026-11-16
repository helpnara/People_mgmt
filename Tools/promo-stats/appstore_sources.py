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
            raise RuntimeError(f"{e.code} {url.split('?')[0]}\n{text}")

    def all(self, path):
        out, url = [], path
        while url:
            r = self.call(url)
            out += r.get("data", [])
            url = r.get("links", {}).get("next")
        return out


def fetch_rows(days):
    app = os.environ.get("ASC_APP_ID") or "6824067748"
    c = Client()
    notes = []
    reqs = c.all(f"/v1/apps/{app}/analyticsReportRequests?filter[accessType]=ONGOING")
    if not reqs:
        try:
            c.call("/v1/analyticsReportRequests", {"data": {
                "type": "analyticsReportRequests", "attributes": {"accessType": "ONGOING"},
                "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})
        except RuntimeError as e:
            raise SystemExit("보고서 요청을 만들지 못했습니다. 키 권한이 관리자(Admin)인지 보세요.\n" + str(e))
        notes.append("이 앱의 분석 보고서 요청을 처음 만들었습니다. **첫 보고서는 하루 이틀 뒤에** 나옵니다 — 다음 주 실행부터 숫자가 보입니다.")
        return {}, notes
    since = (dt.date.today() - dt.timedelta(days=days)).isoformat()
    tables = {}
    for rq in reqs:
        reports = c.all(f"/v1/analyticsReportRequests/{rq['id']}/reports")
        names = [r["attributes"]["name"] for r in reports]
        for rep in reports:
            name = rep["attributes"]["name"]
            if not name.startswith(WANT):
                continue
            # 같은 보고서의 표준 · 자세히 판이 둘 다 있으면 자세히(출처 정보가 있다)만 쓴다
            if name.endswith("Standard") and name.replace("Standard", "Detailed") in names:
                continue
            for inst in c.all(f"/v1/analyticsReports/{rep['id']}/instances?filter[granularity]=DAILY"):
                if inst["attributes"].get("processingDate", "") < since:
                    continue
                for seg in c.all(f"/v1/analyticsReportInstances/{inst['id']}/segments"):
                    with urllib.request.urlopen(seg["attributes"]["url"], timeout=120) as r:
                        raw = r.read()
                    tables.setdefault(name, []).append(gzip.decompress(raw).decode("utf-8") if raw[:2] == b"\x1f\x8b" else raw.decode("utf-8"))
    if not tables:
        notes.append(f"최근 {days}일 안의 보고서가 아직 없습니다 (요청이 막 만들어졌거나, 그 기간에 자료가 없거나).")
    return tables, notes


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
        notes = []
    else:
        tables, notes = fetch_rows(days)
    md = [f"## App Store 획득 경로 — 최근 {days}일", "",
          "웹에서 온 방문은 출처 유형 `Web Referrer`, 쇼츠 링크라면 출처 정보에 `youtube.com` 이 보인다.", ""]
    md += [f"> {n}" for n in notes] + ([""] if notes else [])
    for name in sorted(tables):
        md += summarize(name, tables[name])
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
