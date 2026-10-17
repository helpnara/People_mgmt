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


def sort_timeline(records: list[dict]) -> list[str]:
    ordered = sorted(records, key=lambda r: (-r["occurredAt"], -r["createdAt"]))
    return [r["id"] for r in ordered]


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
    text, tag_only = term

    def has(value) -> bool:
        return value is not None and text in folded(value)

    if not tag_only and has(person["name"]):
        return ("name", "이름 일치")
    for tag in person.get("tags", []):
        if has(tag):
            return ("tag", f"태그 #{tag} 일치")
    if not tag_only:
        for field, evidence in (("nickname", "별명 일치"), ("organization", "소속 일치"),
                                ("role", "직무 일치"), ("relationshipType", "관계 유형 일치"),
                                ("metThrough", "알게 된 경로 일치"), ("firstNote", "첫 인연 메모 일치")):
            if has(person.get(field)):
                return ("person", evidence)
    for record in person.get("records", []):
        shown = record["displayTitle"]
        if not tag_only:
            if has(record.get("title")):
                return ("record", f"기록 '{shown}' 제목 일치")
            if has(record.get("note")):
                return ("record", f"기록 '{shown}' 메모 일치")
            if has(record.get("location")):
                return ("record", f"기록 '{shown}' 장소 일치")
        for tag in record.get("tags", []):
            if has(tag):
                return ("record", f"기록 '{shown}' 태그 #{tag} 일치")
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
        hits.append({"personID": person["id"], "kind": worst[0], "evidence": worst[1],
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
