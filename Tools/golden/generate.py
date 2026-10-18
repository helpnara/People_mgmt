#!/usr/bin/env python3
"""Core 의 기댓값을 파이썬으로 **독립 계산**해 JSON 으로 적는다.

왜 있나
-------
원격 세션(리눅스)에는 Swift 툴체인이 없다. 컴파일 못 하는 환경에서 테스트 기댓값을
손으로 적으면 **테스트가 버그를 승인한다**. 그래서 태그 정리 · 표시명 · 정렬 · 검색 ·
검증 · 날짜 정규화를 설계서(docs/requirements-v0.5.md 5.3 · 6.2 · 6.7 · 7.2 · 7.3)만 보고
파이썬으로 다시 구현해 그 결과를 적는다. Swift 테스트(`GoldenTests.swift`)가 이 파일을 읽는다.

  python3 Tools/golden/generate.py          # 기댓값을 다시 만든다
  python3 Tools/golden/generate.py --check  # 커밋된 것과 다르면 실패한다 (CI)

의존성 없음 — 표준 라이브러리만.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import unicodedata
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parents[2]
CASES = ROOT / "Tools" / "golden" / "cases.json"
OUT = ROOT / "Packages" / "Core" / "Tests" / "CoreTests" / "Golden" / "expected.json"

TAG_MAX_LENGTH = 30
TAG_MAX_COUNT = 20
TITLE_MAX_LENGTH = 40
TITLE_FALLBACK = "(내용 없음)"
NAME_MAX = 100


# ── 글자 정리 (TextNormalization) ────────────────────────────────────────────

def normalized(text: str) -> str:
    return unicodedata.normalize("NFC", text).strip()


def folded(text: str) -> str:
    return normalized(text).lower()


def collapsed_spaces(text: str) -> str:
    return " ".join(text.split())


def nil_if_empty(text):
    if text is None:
        return None
    cleaned = normalized(text)
    return cleaned or None


# ── 태그 (TagNormalizer) ───────────────────────────────────────────────────────

def normalize_tag(raw: str):
    text = normalized(raw)
    while text.startswith("#"):
        text = text[1:]
    text = collapsed_spaces(text).strip()
    if not text or len(text) > TAG_MAX_LENGTH:
        return None
    return text


def normalize_tags(raws: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for raw in raws:
        tag = normalize_tag(raw)
        if tag is None:
            continue
        key = tag.lower()
        if key in seen:
            continue
        seen.add(key)
        result.append(tag)
        if len(result) >= TAG_MAX_COUNT:
            break
    return result


def split_tags(text: str) -> list[str]:
    return re.split(r"[,;\n]", text)


# ── 표시명 (DisplayTitle) ─────────────────────────────────────────────────────

def display_title(title, note) -> str:
    if title is not None:
        cleaned = normalized(title)
        if cleaned:
            return cleaned
    if note is not None:
        for raw_line in unicodedata.normalize("NFC", note).split("\n"):
            line = raw_line.strip()
            if not line:
                continue
            if len(line) > TITLE_MAX_LENGTH:
                return line[:TITLE_MAX_LENGTH] + "…"
            return line
    return TITLE_FALLBACK


# ── 정렬 (NameSort) ───────────────────────────────────────────────────────────

def sort_people(people: list[dict]) -> list[str]:
    ordered = sorted(people, key=lambda p: (folded(p["name"]), p["createdAt"]))
    return [p["name"] for p in ordered]


def sort_recency(people: list[dict]) -> list[str]:
    def key(p):
        last = p.get("lastRecordAt")
        return (0, -last, folded(p["name"]), p["createdAt"]) if last is not None else (1, 0, folded(p["name"]), p["createdAt"])
    return [p["name"] for p in sorted(people, key=key)]


def sort_timeline(records: list[dict]) -> list[str]:
    ordered = sorted(records, key=lambda r: (-r["occurredAt"], -r["createdAt"]))
    return [r["id"] for r in ordered]


# ── 날 수 (RelativeDay) ──────────────────────────────────────────────────────

def relative_day(days: int) -> str:
    if days == 0:
        return "오늘"
    if days == 1:
        return "어제"
    if days == -1:
        return "내일"
    n = abs(days)
    suffix = "전" if days > 0 else "후"
    if n < 7:
        return f"{n}일 {suffix}"
    if n < 30:
        return f"{n // 7}주 {suffix}"
    if n < 365:
        return f"{n // 30}개월 {suffix}"
    return f"{n // 365}년 {suffix}"


# ── 연락처 (ContactName · ContactNote) ───────────────────────────────────────

def east_asian(text: str) -> bool:
    chars = [ch for ch in text if not ch.isspace()]
    return bool(chars) and all(0xAC00 <= ord(ch) <= 0xD7A3 or 0x4E00 <= ord(ch) <= 0x9FFF for ch in chars)


def contact_name(given: str, family: str) -> str:
    g = collapsed_spaces(normalized(given))
    f = collapsed_spaces(normalized(family))
    if not g:
        return f
    if not f:
        return g
    if east_asian(f) and east_asian(g):
        return f + g
    return g + " " + f


def contact_note(phones: list[str], emails: list[str]) -> str:
    seen, parts = set(), []
    for raw in phones + emails:
        item = collapsed_spaces(normalized(raw))
        if not item or item in seen:
            continue
        seen.add(item)
        parts.append(item)
    return " · ".join(parts)[:500]


# ── 관계 지표 (DyadMetrics · NetworkOverview · TraitDistribution · RelationGraph) ─

import math

DAYS_PER_MONTH = 30.4375


def dyad_metrics(records: list[dict], first_met, today: int, type_count: int = 9) -> dict:
    past = sorted([r for r in records if r["day"] <= today], key=lambda r: (-r["day"], r["id"].upper()))
    last_year = [r for r in past if today - r["day"] <= 364]
    recent = [r for r in past if today - r["day"] <= 181]
    previous = [r for r in past if 182 <= today - r["day"] <= 364]
    out = {
        "total": len(past), "lastYear": len(last_year), "daysSinceLast": None, "spanDays": None,
        "spanFromFirstMeeting": first_met is not None, "perMonthTenths": None, "frequencyText": None,
        "trend": None, "recentHalf": len(recent), "previousHalf": len(previous),
        "diversityClass": None, "typeCounts": [],
        "pastIDs": [r["id"] for r in past], "lastYearIDs": [r["id"] for r in last_year],
        "recentHalfIDs": [r["id"] for r in recent], "previousHalfIDs": [r["id"] for r in previous],
        "firstID": past[-1]["id"] if past else None, "lastID": past[0]["id"] if past else None,
        "spanText": None,
    }
    if not past:
        return out
    last, first = past[0], past[-1]
    out["daysSinceLast"] = today - last["day"]
    out["spanDays"] = max(0, last["day"] - (first_met if first_met is not None else first["day"]))
    out["spanText"] = span_text(out["spanDays"])
    if len(past) >= 3:
        days = max(float(today - first["day"]), DAYS_PER_MONTH)
        per_month = float(len(past)) * DAYS_PER_MONTH / days
        out["perMonthTenths"] = math.floor(per_month * 10 + 0.5)
        out["frequencyText"] = frequency_text(per_month)
    if len(past) >= 4:
        diff = len(recent) - len(previous)
        out["trend"] = "rising" if diff >= 2 else ("falling" if diff <= -2 else "steady")
    counts: dict = {}
    for r in past:
        counts[r["type"]] = counts.get(r["type"], 0) + 1
    out["typeCounts"] = [{"type": t, "count": c} for t, c in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]
    if len(past) >= 3 and type_count > 1:
        n = float(len(past))
        entropy = 0.0
        for item in out["typeCounts"]:
            p_ = item["count"] / n
            entropy -= p_ * math.log(p_)
        normalized_ = entropy / math.log(float(type_count))
        out["diversityClass"] = "mostlyOne" if normalized_ < 0.25 else ("several" if normalized_ < 0.6 else "even")
    return out


def span_text(days: int) -> str:
    days = max(0, days)
    if days < 30:
        return f"{days}일"
    years = days // 365
    months = min((days % 365) // 30, 11)
    if years > 0 and months > 0:
        return f"{years}년 {months}개월"
    if years > 0:
        return f"{years}년"
    return f"{months}개월"


def frequency_text(per_month: float) -> str:
    tenths = math.floor(per_month * 10 + 0.5)
    if tenths >= 10:
        if tenths % 10 == 0:
            return f"한 달에 약 {tenths // 10}번"
        return f"한 달에 약 {tenths // 10}.{tenths % 10}번"
    per_year = math.floor(per_month * 12 + 0.5)
    if per_year >= 1:
        return f"1년에 약 {per_year}번"
    return "1년에 1번 미만"


def network_overview(people: list[dict], today: int, year_start: int, year_end: int, neglect_days: int) -> dict:
    def by_name(p):
        return (folded(p["name"]), p["id"].upper())
    active = [p for p in people if p["lastDay"] is not None and today - p["lastDay"] <= 364]
    new = sorted([p for p in people if p["firstMetDay"] is not None and year_start <= p["firstMetDay"] <= year_end],
                 key=lambda p: (-p["firstMetDay"],) + by_name(p))
    quiet = sorted([p for p in people if p["lastDay"] is not None and today - p["lastDay"] >= neglect_days],
                   key=lambda p: (p["lastDay"],) + by_name(p))
    none = sorted([p for p in people if p["lastDay"] is None], key=by_name)
    return {"total": len(people), "activeCount": len(active), "newThisYearIDs": [p["id"] for p in new],
            "quietIDs": [p["id"] for p in quiet], "noRecordIDs": [p["id"] for p in none]}


def trait_buckets(items: list[dict], limit: int = 8) -> list[dict]:
    labels, members, order, unspecified = {}, {}, [], []
    for item in items:
        seen = set()
        for raw in item["values"]:
            value = normalized(raw)
            if not value:
                continue
            key = folded(value)
            if key in seen:
                continue
            seen.add(key)
            if key not in labels:
                labels[key] = value
                order.append(key)
            members.setdefault(key, []).append(item["id"])
        if not seen:
            unspecified.append(item["id"])
    ordered = sorted(order, key=lambda k: (-len(members[k]), k))
    keep = max(limit - 1, 0) if len(ordered) > limit else len(ordered)
    out = [{"label": labels[k], "count": len(members[k]), "ids": members[k], "isUnspecified": False, "isRest": False}
           for k in ordered[:keep]]
    if len(ordered) > keep:
        rest = set(ordered[keep:])
        ids, seen_ids = [], set()
        for item in items:
            keys = [folded(normalized(v)) for v in item["values"]]
            if any(k in rest for k in keys) and item["id"] not in seen_ids:
                seen_ids.add(item["id"])
                ids.append(item["id"])
        out.append({"label": f"그 밖에 {len(rest)}가지", "count": len(ids), "ids": ids, "isUnspecified": False, "isRest": True})
    if unspecified:
        out.append({"label": "미지정", "count": len(unspecified), "ids": unspecified, "isUnspecified": True, "isRest": False})
    return out


def graph_edges(people: list[dict], records: list[list[str]], clique_limit: int = 12) -> list[dict]:
    known = {p["id"].upper() for p in people}
    edges: dict = {}

    def touch(x, y, field):
        x, y = x.upper(), y.upper()
        if x == y or x not in known or y not in known:
            return
        a, b = (x, y) if x < y else (y, x)
        e = edges.setdefault((a, b), {"a": a, "b": b, "together": 0, "introduced": False, "sameOrganization": False})
        if field == "together":
            e["together"] += 1
        else:
            e[field] = True

    for participants in records:
        seen, unique = set(), []
        for pid in participants:
            u = pid.upper()
            if u in known and u not in seen:
                seen.add(u)
                unique.append(u)
        for i in range(len(unique)):
            for j in range(i + 1, len(unique)):
                touch(unique[i], unique[j], "together")
    for p in people:
        if p.get("introducedBy"):
            touch(p["id"], p["introducedBy"], "introduced")
    groups: dict = {}
    for p in people:
        key = folded(p.get("organization") or "")
        if key:
            groups.setdefault(key, []).append(p)
    for key in sorted(groups):
        members = sorted(groups[key], key=lambda p: (folded(p["name"]), p["id"].upper()))
        if len(members) < 2:
            continue
        if len(members) <= clique_limit:
            for i in range(len(members)):
                for j in range(i + 1, len(members)):
                    touch(members[i]["id"], members[j]["id"], "sameOrganization")
        else:
            for i in range(len(members)):
                touch(members[i]["id"], members[(i + 1) % len(members)]["id"], "sameOrganization")
    return [edges[k] for k in sorted(edges)]


# ── 관계 유형 · 알게 된 경로 선택지 (RelationshipPresets.choices) ───────────

def preset_choices(presets: list[str], used: list[str]) -> list[str]:
    counts: dict = {}
    for raw in used:
        v = normalized(raw)
        if not v or v in presets:
            continue
        counts[v] = counts.get(v, 0) + 1
    extras = sorted(counts, key=lambda v: (-counts[v], folded(v), v))
    return presets + extras


# ── 연락 수단 다섯 칸 (ContactFields · ContactSorter) ─────────────────────────

CONTACT_KINDS = ("mobile", "office", "fax", "email")


def contact_fields() -> dict:
    return {"mobile": "", "office": "", "fax": "", "email": "", "other": ""}


def contact_contains(f: dict, v: str) -> bool:
    return v in (f["mobile"], f["office"], f["fax"], f["email"]) or v in f["other"].split(" · ")


def contact_place(f: dict, raw: str, kind: str) -> None:
    value = collapsed_spaces(normalized(raw))
    if not value or contact_contains(f, value):
        return
    if kind in CONTACT_KINDS and not f[kind]:
        f[kind] = value
    else:
        f["other"] = value if not f["other"] else f["other"] + " · " + value


def label_key(label: str) -> str:
    return "".join(ch for ch in label.lower() if ch.isalpha())


def label_kind(key: str):
    if not key:
        return ("none",)
    has = lambda parts: any(p in key for p in parts)
    if key == "f" or has(["fax", "팩스"]):
        return ("kind", "fax")
    if key in ("e", "email", "mail") or has(["메일"]):
        return ("kind", "email")
    if key in ("m", "hp", "handphone") or has(["mobile", "iphone", "cell", "휴대", "핸드폰", "모바일"]):
        return ("kind", "mobile")
    if key in ("o", "main", "dir") or has(["office", "work", "company", "direct", "회사", "사무실", "직장", "대표", "직통"]):
        return ("kind", "office")
    if key in ("t", "tel", "phone", "telephone", "전화", "전화번호", "연락처"):
        return ("phone",)
    if has(["home", "other", "pager", "school", "집", "자택", "기타"]):
        return ("kind", "other")
    return ("unknown",)


def is_mobile(number: str) -> bool:
    digits = "".join(ch for ch in number if ch.isascii() and ch.isdigit())
    if "+" in number and digits.startswith("82"):
        digits = "0" + digits[2:]
    return 10 <= len(digits) <= 11 and digits.startswith("01") and digits[2] in "016789"


def contact_from_contact(phones: list[dict], emails: list[str]) -> dict:
    f = contact_fields()
    for p in phones:
        k = label_kind(label_key(p["label"]))
        if k[0] in ("none", "phone"):
            kind = "mobile" if is_mobile(p["value"]) else "office"
        elif k == ("kind", "email") or k[0] == "unknown":
            kind = "other"
        else:
            kind = k[1]
        contact_place(f, p["value"], kind)
    for e in emails:
        contact_place(f, e, "email")
    return f


# Swift 의 Character.isNewline 과 같은 줄바꿈들. `\r\n` 은 둘로 갈라지고 빈 조각은 버려진다.
CONTACT_SPLIT_RE = re.compile("[·,;|\n\r\x0b\x0c\x85\u2028\u2029]")


def contact_tokens(text: str) -> list[str]:
    parts = CONTACT_SPLIT_RE.split(normalized(text))
    return [p for p in (collapsed_spaces(x) for x in parts) if p]


def contact_resolve(label: str, value: str, is_email: bool):
    k = label_kind(label)
    if is_email:
        return "email" if k in (("none",), ("kind", "email")) else None
    if k[0] in ("none", "phone"):
        return "mobile" if is_mobile(value) else "office"
    if k == ("kind", "email") or k[0] == "unknown":
        return None
    return k[1]


def contact_sort(token: str, f: dict) -> None:
    emails = [m.span() for m in EMAIL_RE.finditer(token)]
    phones = [m.span() for m in PHONE_RE.finditer(token)
              if not any(s < m.end() and m.start() < e for s, e in emails)]
    found = sorted([(s, e, True) for s, e in emails] + [(s, e, False) for s, e in phones])
    if not found:
        contact_place(f, token, "other")
        return
    placements, cursor = [], 0
    for s, e, is_email in found:
        kind = contact_resolve(label_key(token[cursor:s]), token[s:e], is_email)
        if kind is None:
            contact_place(f, token, "other")
            return
        placements.append((token[s:e], kind))
        cursor = e
    if label_key(token[cursor:]):
        contact_place(f, token, "other")
        return
    for value, kind in placements:
        contact_place(f, value, kind)


def contact_split(text: str) -> dict:
    f = contact_fields()
    for token in contact_tokens(text):
        contact_sort(token, f)
    return f


# ── 명함 (BusinessCardParser) ────────────────────────────────────────────────

ROLE_KEYWORDS = ["대표이사", "대표", "회장", "사장", "부사장", "전무", "상무", "이사", "본부장", "실장", "센터장",
                 "부장", "차장", "과장", "팀장", "대리", "주임", "사원", "책임", "선임", "수석", "연구원", "교수",
                 "원장", "매니저", "디자이너", "개발자", "엔지니어", "컨설턴트",
                 "ceo", "cto", "cfo", "coo", "director", "manager", "engineer", "designer", "developer",
                 "consultant", "president", "founder", "professor", "lead"]
KOREAN_ORG = ["주식회사", "(주)", "㈜", "유한회사", "재단", "협회", "대학교", "병원", "연구소", "은행", "그룹"]
LATIN_ORG = {"inc", "corp", "co", "ltd", "llc", "company", "university", "labs", "lab"}
DEPARTMENT_SUFFIXES = ["팀", "부", "실", "과", "처", "국", "센터", "본부", "그룹"]
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE_RE = re.compile(r"(?:\+82[\s.-]?)?\(?0?\d{1,2}\)?[\s.-]?\d{3,4}[\s.-]?\d{4}")
LATIN_NAME_RE = re.compile(r"^[A-Z][A-Za-z'-]+(?: [A-Z][A-Za-z'-]+){1,2}$")


def latin_letters(token: str) -> str:
    return "".join(ch for ch in token if ch.isascii() and ch.isalpha()).lower()


def is_org(text: str) -> bool:
    if any(k in text for k in KOREAN_ORG):
        return True
    return any(latin_letters(t) in LATIN_ORG for t in text.split(" "))


def is_role_token(token: str) -> bool:
    latin = latin_letters(token)
    for k in ROLE_KEYWORDS:
        if k[0].isascii():
            if latin == k:
                return True
        elif token.endswith(k):
            return True
    return False


def is_hangul_name(text: str) -> bool:
    tokens = text.split(" ")
    if not (len(tokens) == 1 or all(len(t) == 1 for t in tokens)):
        return False
    joined = "".join(tokens)
    if not 2 <= len(joined) <= 4:
        return False
    if not all(0xAC00 <= ord(ch) <= 0xD7A3 for ch in joined):
        return False
    return not any(joined.endswith(s) for s in DEPARTMENT_SUFFIXES)


def is_fax(lower: str) -> bool:
    return lower.startswith(("fax", "팩스", "f.", "f "))


def parse_card(lines: list[list]) -> dict:
    out = {"name": None, "organization": None, "role": None, "phones": [], "emails": [], "lines": []}
    contact_lines = []
    candidate = None
    def offer(name, height):
        nonlocal candidate
        if candidate is not None and candidate[1] >= height:
            return
        candidate = (name, height)
    for raw, height in lines:
        text = collapsed_spaces(normalized(raw))
        if not text:
            continue
        out["lines"].append(text)
        lower = text.lower()
        emails = EMAIL_RE.findall(text)
        phones = PHONE_RE.findall(text)
        if emails or phones or "www." in lower or "http" in lower:
            contact_lines.append(text)
            for e in (x.lower() for x in emails):
                if e not in out["emails"]:
                    out["emails"].append(e)
            if not is_fax(lower):
                for p in (x.strip(" ") for x in phones):
                    if p not in out["phones"]:
                        out["phones"].append(p)
            continue
        if is_org(text):
            if out["organization"] is None:
                out["organization"] = text
            continue
        tokens = text.split(" ")
        if len(tokens) >= 2 and is_hangul_name(tokens[0]) and any(is_role_token(t) for t in tokens[1:]):
            offer(tokens[0], height)
            if out["role"] is None:
                out["role"] = " ".join(tokens[1:])
            continue
        if any(is_role_token(t) for t in tokens):
            if out["role"] is None:
                out["role"] = text
            continue
        if is_hangul_name(text):
            offer(text.replace(" ", ""), height)
        elif LATIN_NAME_RE.search(text):
            offer(text, height)
    out["name"] = candidate[0] if candidate else None
    out["contact"] = contact_split("\n".join(contact_lines))
    return out


# ── 검증 (Validation) ────────────────────────────────────────────────────────

def name_problem(name: str):
    cleaned = normalized(name)
    if not cleaned:
        return "이름을 입력하세요"
    if len(cleaned) > NAME_MAX:
        return f"이름은 {NAME_MAX}자까지 쓸 수 있습니다"
    return None


def can_save_record(title, note) -> bool:
    return nil_if_empty(title) is not None or nil_if_empty(note) is not None


# ── 날짜 (DayNormalizer) ─────────────────────────────────────────────────────

def noon_epoch(iso: str, zone: str) -> float:
    instant = datetime.fromisoformat(iso)
    local = instant.astimezone(ZoneInfo(zone))
    noon = local.replace(hour=12, minute=0, second=0, microsecond=0)
    return noon.timestamp()


# ── 조사 (Josa) ──────────────────────────────────────────────────────────────

def final_consonant(text: str):
    stripped = text.rstrip()
    if not stripped:
        return None
    code = ord(stripped[-1])
    if not 0xAC00 <= code <= 0xD7A3:
        return None
    return (code - 0xAC00) % 28 != 0


def josa(text: str) -> dict:
    has = final_consonant(text)
    pick = lambda yes, no, both: both if has is None else (yes if has else no)  # noqa: E731
    return {"eulReul": pick("을", "를", "을(를)"), "gwaWa": pick("과", "와", "과(와)"),
            "iGa": pick("이", "가", "이(가)")}


# ── 검색 (SearchQuery · SearchMatcher) ────────────────────────────────────────

KIND_RANK = {"name": 0, "tag": 1, "person": 2, "record": 3}


def parse_query(raw: str) -> list[tuple[str, bool]]:
    terms = []
    for word in raw.split():
        tag_only = word.startswith("#")
        body = word[1:] if tag_only else word
        text = folded(body)
        if text:
            terms.append((text, tag_only))
    return terms


def best_match(term: tuple[str, bool], person: dict):
    """(종류, 근거, 기록 id 또는 None)"""
    text, tag_only = term

    def has(value) -> bool:
        return value is not None and text in folded(value)

    if not tag_only and has(person["name"]):
        return ("name", "이름 일치", None)
    for tag in person.get("tags", []):
        if has(tag):
            return ("tag", f"태그 #{tag} 일치", None)
    if not tag_only:
        for field, evidence in (("nickname", "별명 일치"), ("organization", "소속 일치"),
                                ("role", "직무 일치"), ("relationshipType", "관계 유형 일치"),
                                ("metThrough", "알게 된 경로 일치"), ("firstNote", "첫 인연 메모 일치")):
            if has(person.get(field)):
                return ("person", evidence, None)
    for record in person.get("records", []):
        shown = record["displayTitle"]
        if not tag_only:
            if has(record.get("title")):
                return ("record", f"기록 '{shown}' 제목 일치", record["id"])
            if has(record.get("note")):
                return ("record", f"기록 '{shown}' 메모 일치", record["id"])
            if has(record.get("location")):
                return ("record", f"기록 '{shown}' 장소 일치", record["id"])
        for tag in record.get("tags", []):
            if has(tag):
                return ("record", f"기록 '{shown}' 태그 #{tag} 일치", record["id"])
    return None


def search(query: str, people: list[dict]) -> list[dict]:
    terms = parse_query(query)
    if not terms:
        return []
    hits = []
    for person in people:
        worst = None
        matched = True
        for term in terms:
            match = best_match(term, person)
            if match is None:
                matched = False
                break
            if worst is None or KIND_RANK[match[0]] > KIND_RANK[worst[0]]:
                worst = match
        if not matched or worst is None:
            continue
        hits.append({"personID": person["id"], "kind": worst[0], "evidence": worst[1], "recordID": worst[2],
                     "_sort": (KIND_RANK[worst[0]], folded(person["name"]), person["id"].upper())})
    hits.sort(key=lambda h: h["_sort"])
    for hit in hits:
        del hit["_sort"]
    return hits


# ── 모아서 적기 ──────────────────────────────────────────────────────────────

def build() -> dict:
    cases = json.loads(CASES.read_text(encoding="utf-8"))
    out: dict = {}

    out["tags"] = [{"name": c["name"], "input": c["input"], "expected": normalize_tags(c["input"])}
                   for c in cases["tags"]]
    out["tagSplit"] = [{"name": c["name"], "input": c["input"],
                        "expected": normalize_tags(split_tags(c["input"]))}
                       for c in cases["tagSplit"]]
    out["displayTitle"] = [{"name": c["name"], "title": c["title"], "note": c["note"],
                            "expected": display_title(c["title"], c["note"])}
                           for c in cases["displayTitle"]]
    out["nameSort"] = [{"name": c["name"], "people": c["people"], "expected": sort_people(c["people"])}
                       for c in cases["nameSort"]]
    from datetime import date
    out["relativeDay"] = [{"from": c["from"], "to": c["to"],
                           "expected": relative_day((date.fromisoformat(c["to"]) - date.fromisoformat(c["from"])).days)}
                          for c in cases["relativeDay"]]
    out["contactName"] = [{"given": c["given"], "family": c["family"], "expected": contact_name(c["given"], c["family"])}
                          for c in cases["contactName"]]
    out["contactNote"] = [{"phones": c["phones"], "emails": c["emails"], "expected": contact_note(c["phones"], c["emails"])}
                          for c in cases["contactNote"]]
    out["dyadMetrics"] = [{"name": c["name"], "records": c["records"], "firstMetDay": c.get("firstMetDay"),
                           "today": c["today"], "expected": dyad_metrics(c["records"], c.get("firstMetDay"), c["today"])}
                          for c in cases["dyadMetrics"]]
    out["spanText"] = [{"days": d, "expected": span_text(d)} for d in cases["spanText"]]
    out["networkOverview"] = [{"name": c["name"], "people": c["people"], "today": c["today"], "yearStart": c["yearStart"],
                               "yearEnd": c["yearEnd"], "neglectDays": c["neglectDays"],
                               "expected": network_overview(c["people"], c["today"], c["yearStart"], c["yearEnd"], c["neglectDays"])}
                              for c in cases["networkOverview"]]
    out["traitBuckets"] = [{"name": c["name"], "items": c["items"], "limit": c["limit"],
                            "expected": trait_buckets(c["items"], c["limit"])} for c in cases["traitBuckets"]]
    out["graphEdges"] = [{"name": c["name"], "people": c["people"], "records": c["records"], "cliqueLimit": c["cliqueLimit"],
                          "expected": graph_edges(c["people"], c["records"], c["cliqueLimit"])} for c in cases["graphEdges"]]
    out["presetChoices"] = [{"name": c["name"], "presets": c["presets"], "used": c["used"],
                             "expected": preset_choices(c["presets"], c["used"])}
                            for c in cases["presetChoices"]]
    out["contactSplit"] = [{"text": t, "expected": contact_split(t)} for t in cases["contactSplit"]]
    out["contactFromContact"] = [{"phones": c["phones"], "emails": c["emails"],
                                  "expected": contact_from_contact(c["phones"], c["emails"])}
                                 for c in cases["contactFromContact"]]
    out["cardParse"] = [{"name": c["name"], "lines": c["lines"], "expected": parse_card(c["lines"])}
                        for c in cases["cardParse"]]
    out["recencySort"] = [{"name": c["name"], "people": c["people"], "expected": sort_recency(c["people"])}
                          for c in cases["recencySort"]]
    out["timelineSort"] = [{"name": c["name"], "records": c["records"], "expected": sort_timeline(c["records"])}
                           for c in cases["timelineSort"]]
    out["validation"] = [{"name": c["name"], "expected": name_problem(c["name"])}
                         for c in cases["validation"]]
    out["recordSave"] = [{"title": c["title"], "note": c["note"],
                          "expected": can_save_record(c["title"], c["note"])}
                         for c in cases["recordSave"]]
    out["dayNoon"] = [{"iso": c["iso"], "timeZone": c["timeZone"],
                       "expectedEpoch": noon_epoch(c["iso"], c["timeZone"])}
                      for c in cases["dayNoon"]]
    out["josa"] = [{"text": t, "expected": josa(t)} for t in cases["josa"]]
    people = cases["search"]["people"]
    out["search"] = {
        "people": people,
        "queries": [{"query": q, "expected": search(q, people)} for q in cases["search"]["queries"]],
    }
    return out


def main() -> int:
    check = "--check" in sys.argv[1:]
    result = json.dumps(build(), ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != result:
            print(f"::error::{OUT.relative_to(ROOT)} 가 최신이 아닙니다. "
                  "python3 Tools/golden/generate.py 를 돌리고 커밋하세요.")
            return 1
        print(f"✅ {OUT.relative_to(ROOT)} 최신")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(result, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} — {len(result)}바이트")
    return 0


if __name__ == "__main__":
    sys.exit(main())
