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
    # 발음 구별 기호(Mn)를 빼고 다시 합친 뒤 소문자 — Swift `TextNormalization.folded` 와 같은 차례.
    decomposed = unicodedata.normalize("NFD", normalized(text))
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    return unicodedata.normalize("NFC", stripped).lower()


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


def graph_edges(people: list[dict], records: list[list[str]], clique_limit: int = 12, ties=None) -> list[dict]:
    known = {p["id"].upper() for p in people}
    edges: dict = {}

    def touch(x, y, field, share=0.0):
        x, y = x.upper(), y.upper()
        if x == y or x not in known or y not in known:
            return
        a, b = (x, y) if x < y else (y, x)
        e = edges.setdefault((a, b), {"a": a, "b": b, "together": 0, "togetherWeight": 0.0, "introduced": False,
                                      "sameOrganization": False, "acquainted": False})
        if field == "together":
            e["together"] += 1
            e["togetherWeight"] += share
        else:
            e[field] = True

    for participants in records:
        seen, unique = set(), []
        for pid in participants:
            u = pid.upper()
            if u in known and u not in seen:
                seen.add(u)
                unique.append(u)
        # 큰 기록의 무게 낮추기 (빌드 16 · 조사 보고서 지금 4) — n명 기록의 각 쌍에 1/(n−1).
        share = 1.0 / (len(unique) - 1) if len(unique) > 1 else 0.0
        for i in range(len(unique)):
            for j in range(i + 1, len(unique)):
                touch(unique[i], unique[j], "together", share)
    for p in people:
        if p.get("introducedBy"):
            touch(p["id"], p["introducedBy"], "introduced")
    for x, y in (ties or []):
        touch(x, y, "acquainted")
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


# ── 모임 찾기 (CommunityDetection · CommunityNaming) ─────────────────────────
# Swift 와 덧셈 차례까지 같게 쓴다 — 이웃은 번호 순, 무게는 들어온 차례로 더한다.

def _graph_from_links(n, links):
    merged = [dict() for _ in range(n)]
    loops = [0.0] * n
    for l in links:
        i, j, w = l["i"], l["j"], l["weight"]
        if not (w > 0 and i < n and j < n):
            continue
        if i == j:
            loops[i] += w
        else:
            merged[i][j] = merged[i].get(j, 0.0) + w
            merged[j][i] = merged[j].get(i, 0.0) + w
    return _graph(_sorted_neighbors(merged), loops)


def _sorted_neighbors(merged):
    return [[(k, d[k]) for k in sorted(d)] for d in merged]


def _graph(neighbors, loops):
    degree, total = [], 0.0
    for i in range(len(loops)):
        k = 2 * loops[i]
        for _, w in neighbors[i]:
            k += w
        degree.append(k)
        total += loops[i]
        for node, w in neighbors[i]:
            if node > i:
                total += w
    return {"neighbors": neighbors, "loops": loops, "degree": degree, "total": total}


def _local_moving(g, resolution, epsilon, max_passes):
    n = len(g["loops"])
    two_m = 2 * g["total"]
    community = list(range(n))
    total = list(g["degree"])
    moved_any = False
    for _ in range(max_passes):
        moved = False
        for i in range(n):
            k = g["degree"][i]
            current = community[i]
            order, weight_to = [], {}
            for node, w in g["neighbors"][i]:
                c = community[node]
                if c not in weight_to:
                    order.append(c)
                    weight_to[c] = 0.0
                weight_to[c] += w
            total[current] -= k
            best = current
            best_gain = weight_to.get(current, 0.0) - resolution * total[current] * k / two_m
            for c in order:
                if c == current:
                    continue
                gain = weight_to.get(c, 0.0) - resolution * total[c] * k / two_m
                if gain > best_gain + epsilon:
                    best, best_gain = c, gain
            total[best] += k
            if best != current:
                community[i] = best
                moved = moved_any = True
        if not moved:
            break
    return community, moved_any


def _renumber(community):
    mapping, out = {}, []
    for c in community:
        if c not in mapping:
            mapping[c] = len(mapping)
        out.append(mapping[c])
    return out, len(mapping)


def _aggregate(g, community, count):
    loops = [0.0] * count
    merged = [dict() for _ in range(count)]
    for i in range(len(g["loops"])):
        loops[community[i]] += g["loops"][i]
        for node, w in g["neighbors"][i]:
            if node <= i:
                continue
            a, b = community[i], community[node]
            if a == b:
                loops[a] += w
            else:
                merged[a][b] = merged[a].get(b, 0.0) + w
                merged[b][a] = merged[b].get(a, 0.0) + w
    return _graph(_sorted_neighbors(merged), loops)


def split_connected(communities, n, links):
    neighbors = [[] for _ in range(n)]
    for l in links:
        if l["weight"] > 0 and l["i"] != l["j"] and l["i"] < n and l["j"] < n:
            neighbors[l["i"]].append(l["j"])
            neighbors[l["j"]].append(l["i"])
    out = []
    for community in communities:
        members, seen = set(community), set()
        for start in sorted(community):
            if start in seen:
                continue
            component, queue, head = [], [start], 0
            seen.add(start)
            while head < len(queue):
                node = queue[head]
                head += 1
                component.append(node)
                for nxt in sorted(neighbors[node]):
                    if nxt in members and nxt not in seen:
                        seen.add(nxt)
                        queue.append(nxt)
            out.append(sorted(component))
    return sorted(out, key=lambda c: (-len(c), c[0] if c else 0))


def modularity(communities, n, links, resolution=1.0):
    group = [-1] * n
    for idx, c in enumerate(communities):
        for node in c:
            if node < n:
                group[node] = idx
    m = 0.0
    inside = [0.0] * len(communities)
    degree = [0.0] * len(communities)
    for l in links:
        if not (l["i"] < n and l["j"] < n and l["weight"] > 0):
            continue
        m += l["weight"]
        gi, gj = group[l["i"]], group[l["j"]]
        if gi >= 0:
            degree[gi] += l["weight"]
        if gj >= 0:
            degree[gj] += l["weight"]
        if gi == gj and gi >= 0:
            inside[gi] += l["weight"]
    if m <= 0:
        return 0.0
    q = 0.0
    for c in range(len(communities)):
        share = degree[c] / (2 * m)
        q += inside[c] / m - resolution * share * share
    return q


def louvain(n, links, resolution=1.0, epsilon=1e-7, max_levels=10, max_passes=50):
    if n <= 0:
        return {"communities": [], "modularity": 0.0}
    base = _graph_from_links(n, links)
    if not base["total"] > 0:
        return {"communities": [[i] for i in range(n)], "modularity": 0.0}
    membership = list(range(n))
    g = base
    for _ in range(max_levels):
        community, moved = _local_moving(g, resolution, epsilon, max_passes)
        if not moved:
            break
        renumbered, count = _renumber(community)
        membership = [renumbered[x] for x in membership]
        g = _aggregate(g, renumbered, count)
    groups = [[] for _ in range((max(membership) if membership else -1) + 1)]
    for person, grp in enumerate(membership):
        groups[grp].append(person)
    split = split_connected([c for c in groups if c], n, links)
    return {"communities": split, "modularity": modularity(split, n, links, resolution)}


def community_name(members):
    def top(values):
        counts, labels = {}, {}
        for person_values in values:
            seen = set()
            for raw in person_values:
                v = normalized(raw or "")
                if not v:
                    continue
                key = folded(v)
                if key in seen:
                    continue
                seen.add(key)
                counts[key] = counts.get(key, 0) + 1
                labels.setdefault(key, v)
        best = sorted([(k, c) for k, c in counts.items() if c >= 2], key=lambda kc: (-kc[1], kc[0]))
        return labels[best[0][0]] if best else None
    name = top([[m.get("organization") or ""] for m in members])
    if name:
        return name
    name = top([m.get("tags", []) for m in members])
    if name:
        return "#" + name
    return top([[m.get("metThrough") or ""] for m in members])


# ── 시점에 따른 관계 변화 (TemporalNetwork · D-32) ───────────────────────────
# 사람 · 기록 · 아는 사이는 번호로 받는다 (번호 차례 = 이름 순). 시점마다 창(365일) 안의 함께한 기록을
# 반감기 182.625일로 줄여 더하고, 소개 · 아는 사이는 두 사람이 그 시점에 있으면 1 을 더한다.

TEMPORAL_WINDOW = 365
TEMPORAL_HALF_LIFE = 182.625
TEMPORAL_MIN_EDGES = 10
TEMPORAL_MIN_MODULARITY = 0.3
TEMPORAL_MIN_GROUP = 3
TEMPORAL_MATCH = 0.3
TEMPORAL_SIZE_CHANGE = 0.3
TEMPORAL_INCLUSION = 0.5


def temporal_slices(people, records, ties, slice_days):
    n = len(people)
    first_record = [None] * n
    for r in records:
        for x in set(r["participants"]):
            if 0 <= x < n and (first_record[x] is None or r["day"] < first_record[x]):
                first_record[x] = r["day"]
    known = []
    for i, p in enumerate(people):
        days = [d for d in (p.get("firstMetDay"), first_record[i]) if d is not None]
        known.append(min(days) if days else None)
    pair_sets = []
    intro = set()
    for i, p in enumerate(people):
        j = p.get("introducedBy")
        if j is not None and 0 <= j < n and j != i:
            intro.add((min(i, j), max(i, j)))
    tie = set()
    for a, b in ties:
        if a != b and 0 <= a < n and 0 <= b < n:
            tie.add((min(a, b), max(a, b)))
    out = []
    for t in slice_days:
        present = [i for i in range(n) if known[i] is not None and known[i] <= t]
        pres = set(present)
        weight = {}
        for r in records:
            d = r["day"]
            if d > t or d <= t - TEMPORAL_WINDOW:
                continue
            ps = sorted(set(x for x in r["participants"] if x in pres))
            if len(ps) < 2:
                continue
            w = 0.5 ** ((t - d) / TEMPORAL_HALF_LIFE) / (len(ps) - 1)
            for a in range(len(ps)):
                for b in range(a + 1, len(ps)):
                    key = (ps[a], ps[b])
                    weight[key] = weight.get(key, 0.0) + w
        for key in sorted(intro | tie):
            if key[0] in pres and key[1] in pres:
                add = (1.0 if key in intro else 0.0) + (1.0 if key in tie else 0.0)
                weight[key] = weight.get(key, 0.0) + add
        edges = sorted(weight.items())
        linked = sorted(set(i for (a, b), _ in edges for i in (a, b)))
        status, communities = "sparse", []
        if len(edges) >= TEMPORAL_MIN_EDGES:
            node = {p: k for k, p in enumerate(present)}
            links = [{"i": node[a], "j": node[b], "weight": w} for (a, b), w in edges]
            found = louvain(len(present), links)
            groups = [[present[k] for k in c] for c in found["communities"] if len(c) >= TEMPORAL_MIN_GROUP]
            if found["modularity"] >= TEMPORAL_MIN_MODULARITY and groups:
                status, communities = "shown", groups
            else:
                status = "unclear"
        out.append({"day": t, "present": present, "linked": linked, "status": status,
                    "edges": [[a, b, w] for (a, b), w in edges], "communities": communities})
    return out


def temporal_match(x, y, threshold=TEMPORAL_MATCH):
    """두 모임을 같은 모임의 앞뒤로 볼까 — Jaccard 가 문턱 이상이거나, 작은 쪽의 절반 이상이 큰 쪽에 들어 있다 (GED 포함도)."""
    a, b = set(x), set(y)
    if not a or not b:
        return False
    both = len(a & b)
    return both / len(a | b) >= threshold or both / min(len(a), len(b)) >= TEMPORAL_INCLUSION


def temporal_changes(slices, threshold=TEMPORAL_MATCH):
    events = []
    dormant = []   # 앞에서 최근 기록 없음이 된 모임 — 다시 보이면 다시 모임 (빌드 16 · 조사 보고서 지금 2)
    for s in range(1, len(slices)):
        prev, cur = slices[s - 1]["communities"], slices[s]["communities"]
        succ = [[c for c in range(len(cur)) if temporal_match(prev[p], cur[c], threshold)] for p in range(len(prev))]
        pred = [[p for p in range(len(prev)) if temporal_match(prev[p], cur[c], threshold)] for c in range(len(cur))]
        woke = []
        for c, group in enumerate(cur):
            if not pred[c]:
                back = next((k for k in range(len(dormant) - 1, -1, -1) if temporal_match(dormant[k], group, threshold)), None)
                if back is None:
                    events.append({"slice": s, "kind": "new", "members": group})
                else:
                    woke.append(back)
                    events.append({"slice": s, "kind": "returned", "members": group})
            elif len(pred[c]) >= 2:
                events.append({"slice": s, "kind": "merged", "members": group})
            else:
                p = pred[c][0]
                if len(succ[p]) >= 2:
                    continue
                ratio = (len(group) - len(prev[p])) / len(prev[p])
                if ratio > TEMPORAL_SIZE_CHANGE:
                    events.append({"slice": s, "kind": "grew", "members": group})
                elif ratio < -TEMPORAL_SIZE_CHANGE:
                    events.append({"slice": s, "kind": "shrank", "members": group})
                else:
                    events.append({"slice": s, "kind": "steady", "members": group})
        dormant = [d for k, d in enumerate(dormant) if k not in woke]
        for p, group in enumerate(prev):
            if not succ[p]:
                events.append({"slice": s, "kind": "faded", "members": group})
                dormant.append(group)
            elif len(succ[p]) >= 2:
                events.append({"slice": s, "kind": "split", "members": group})
    return events


# ── 입력 상태 (InputReadiness) ───────────────────────────────────────────────

READINESS_TITLES = {"traits": "특성 분포", "firstMet": "올해 처음 만남", "review": "돌아보기", "graph": "관계도", "groups": "모임 찾기"}


def input_readiness(i: dict) -> list[dict]:
    n = i["people"]
    def toward(count, pct):
        return min(float(count * 100) / float(n * pct), 1.0) if n > 0 else 0.0
    def percent(count):
        return (count * 200 + n) // (2 * n) if n > 0 else 0
    def need(count, pct):
        return max((n * pct + 99) // 100 - count, 0)
    def level(p):
        return "ready" if p >= 1 else ("almost" if p >= 0.6 else "notYet")
    items = []
    empty = "사람을 적으면 시작합니다."
    typed = min(i["withRelationshipType"], i["withMetThrough"])
    tp = min(min(float(n) / 20.0, toward(typed, 80)), 1.0)
    if n < 20:
        th = f"사람을 {20 - n}명 더 적으면 분포가 뜻을 갖습니다."
    elif need(typed, 80) > 0:
        th = f"관계 유형 · 알게 된 경로를 {need(typed, 80)}명 더 채우면 분포가 정확해집니다."
    else:
        th = "내 인연의 구성이 믿을 만하게 보입니다."
    items.append({"feature": "traits", "level": level(tp), "progress": tp,
                  "current": f"사람 {n}명 · 관계 유형과 경로를 적은 사람 {percent(typed)}%", "hint": th})
    fp = toward(i["withFirstMet"], 50); fn = need(i["withFirstMet"], 50)
    items.append({"feature": "firstMet", "level": level(fp), "progress": fp,
                  "current": f"처음 만난 날을 적은 사람 {i['withFirstMet']}명 / {n}명",
                  "hint": empty if n == 0 else f"처음 만난 날을 {fn}명 더 적으면 올해 처음 만남과 인연 기간이 정확해집니다." if fn > 0
                          else "올해 처음 만난 사람과 인연 기간이 정확하게 보입니다."})
    rp = toward(i["withRecords"], 50); rn = need(i["withRecords"], 50)
    items.append({"feature": "review", "level": level(rp), "progress": rp,
                  "current": f"기록이 있는 사람 {i['withRecords']}명 / {n}명",
                  "hint": empty if n == 0 else f"{rn}명과의 기록을 더 남기면 최근 기록 없음 · 관계 돌아보기가 뜻을 갖습니다." if rn > 0
                          else "오래 기록이 없는 인연과 사람마다의 흐름이 보입니다."})
    gp = toward(i["linkedPeople"], 30); gn = need(i["linkedPeople"], 30)
    items.append({"feature": "graph", "level": level(gp), "progress": gp,
                  "current": f"서로 이어진 사람 {i['linkedPeople']}명 / {n}명 ({percent(i['linkedPeople'])}%)",
                  "hint": empty if n == 0 else f"{gn}명을 더 이으면 관계도에 모양이 드러납니다 — 아는 사이를 고르거나, 기록에 함께한 사람을 두 명 이상 넣으세요." if gn > 0
                          else "사람들 사이의 연결이 관계도에 드러납니다."})
    op = min(min(float(i["strongEdges"]) / 20.0, float(i["linkedPeople"]) / 10.0), 1.0)
    es, ls = max(20 - i["strongEdges"], 0), max(10 - i["linkedPeople"], 0)
    if es > 0 or ls > 0:
        parts = []
        if es > 0:
            parts.append(f"진한 선 {es}개")
        if ls > 0:
            parts.append(f"이어진 사람 {ls}명")
        oh = " · ".join(parts) + " 더 있으면 모임(그룹)을 찾아 관계도에 묶어 보여 줍니다."
    else:
        oh = "모임(그룹)을 찾을 만큼 연결이 쌓였습니다."
    items.append({"feature": "groups", "level": level(op), "progress": op,
                  "current": f"진한 선 {i['strongEdges']}개 · 이어진 사람 {i['linkedPeople']}명", "hint": oh})
    return items


def readiness_summary(items):
    ready = sum(1 for x in items if x["level"] == "ready")
    head = f"{len(items)}가지 중 {ready}가지 준비됨"
    nxt = next((x for x in items if x["level"] != "ready"), None)
    return head + " · 모두 준비됨" if nxt is None else head + " · 다음: " + READINESS_TITLES[nxt["feature"]]


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
    # 연 · 월 · 일은 그 시간대에서 읽고, 그 날의 12:00 UTC (이슈 20).
    instant = datetime.fromisoformat(iso)
    local = instant.astimezone(ZoneInfo(zone))
    return datetime(local.year, local.month, local.day, 12, tzinfo=timezone.utc).timestamp()


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
                          "ties": c.get("ties", []),
                          "expected": graph_edges(c["people"], c["records"], c["cliqueLimit"], c.get("ties", []))} for c in cases["graphEdges"]]
    out["louvain"] = [{"name": c["name"], "nodeCount": c["nodeCount"], "links": c["links"],
                       "resolution": c.get("resolution", 1.0),
                       "expected": louvain(c["nodeCount"], c["links"], c.get("resolution", 1.0))} for c in cases["louvain"]]
    out["splitConnected"] = [{"name": c["name"], "nodeCount": c["nodeCount"], "links": c["links"], "communities": c["communities"],
                              "expected": split_connected(c["communities"], c["nodeCount"], c["links"])} for c in cases["splitConnected"]]
    out["communityName"] = [{"name": c["name"], "members": c["members"], "expected": community_name(c["members"])}
                            for c in cases["communityName"]]
    out["temporal"] = []
    for c in cases["temporal"]:
        sl = temporal_slices(c["people"], c["records"], c.get("ties", []), c["sliceDays"])
        out["temporal"].append({"name": c["name"], "people": c["people"], "records": c["records"],
                                "ties": c.get("ties", []), "sliceDays": c["sliceDays"],
                                "slices": sl, "changes": temporal_changes(sl),
                                # 짝짓기 문턱 비교 (빌드 16 · 조사 보고서 지금 3) — 0.1 · 0.2 에서의 판정도 Swift 와 대조한다.
                                "thresholdChanges": [{"threshold": th, "changes": temporal_changes(sl, th)} for th in (0.1, 0.2)]})
    out["inputReadiness"] = [{"name": c["name"], "input": c["input"], "expected": input_readiness(c["input"]),
                              "summary": readiness_summary(input_readiness(c["input"]))} for c in cases["inputReadiness"]]
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
    out["folded"] = [{"input": t, "expected": folded(t)} for t in cases["folded"]]
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
