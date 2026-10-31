#!/usr/bin/env python3
"""모임 짝짓기 문턱 0.1 · 0.2 · 0.3 비교 (빌드 16 · 조사 보고서 지금 3).

    python3 Tools/golden/compare-thresholds.py

정답표의 시점 견본(`cases.json` 의 `temporal`)마다 문턱별 변화 판정을 나란히 찍는다.
문턱을 고르는 것은 사용자 결정이다 — 이 표를 보여 주고 선택지로 묻는다. Swift 는 `TemporalNetwork.matchThreshold`.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import generate as g  # noqa: E402

THRESHOLDS = (0.1, 0.2, 0.3)
WORDS = {"new": "새로", "grew": "늘음", "shrank": "줄음", "merged": "이어짐", "split": "나뉨",
         "faded": "기록 없음", "steady": "그대로", "returned": "다시 모임"}


def main() -> None:
    cases = json.loads((Path(__file__).parent / "cases.json").read_text())["temporal"]
    for c in cases:
        slices = g.temporal_slices(c["people"], c["records"], c.get("ties", []), c["sliceDays"])
        rows = {th: [f"{e['slice']}:{WORDS[e['kind']]}{len(e['members'])}" for e in g.temporal_changes(slices, th)]
                for th in THRESHOLDS}
        same = len({tuple(r) for r in rows.values()}) == 1
        print(f"■ {c['name']}" + ("  (세 문턱 모두 같음)" if same else "  ← 문턱에 따라 갈림"))
        for th in THRESHOLDS:
            print(f"   {th}: " + (" · ".join(rows[th]) or "변화 없음"))


if __name__ == "__main__":
    main()
