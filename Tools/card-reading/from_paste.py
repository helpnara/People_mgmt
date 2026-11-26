#!/usr/bin/env python3
"""명함 읽기 시험의 **읽은 결과 복사** 글을 받아 읽기 규칙을 다시 돌린다 (이슈 127).

앱 `설정 → 실험 → 명함 읽기 시험` 에서 명함마다 `읽은 결과 복사` 로 받은 글(여러 장을 이어 붙여도 된다)을 파일로 두고:

  python3 Tools/card-reading/from_paste.py 붙여넣은.txt          방식마다 다시 읽은 칸 · 앱이 낸 칸과 다르면 표시
  python3 Tools/card-reading/from_paste.py 붙여넣은.txt --lines  읽은 줄도 함께

- 읽기 규칙은 파이썬 정답표(`Tools/golden/generate.py` 의 `parse_card`)를 그대로 쓴다 — 앱의 `Core/BusinessCardParser.swift` 와
  글자 하나 다르지 않게 맞춰 둔 것. 규칙을 고칠 때는 둘을 같이 고친다.
- 가린 글(`· 가림`)은 `#` → `5`, `○` → `가` 로 (번호 앞자리 `010` · `02` 는 가리지 않았다) 되돌려 읽는다. 이름이 한글 2~4자인지 · 번호 모양인지 같은 **모양**은 그대로 남아
  규칙이 같은 길을 탄다. 직무 · 회사 · 연락 이름표 낱말은 가리지 않았다(`Core/CardMasking.swift`).
- **받은 글은 저장소에 넣지 않는다** — 실제 사람의 명함이다. 고칠 거리가 보이면 모양만 본떠 지어낸 사례로
  `Tools/golden/cases.json` 의 `cardParse` 에 더한다.
"""
from __future__ import annotations

import importlib.util
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("golden", HERE.parent / "golden" / "generate.py")
golden = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(golden)

FIELDS = ["이름", "소속", "직무", "휴대전화", "사무실", "팩스", "이메일"]
MARKS = ["①", "②", "③"]
LINE_RE = re.compile(r"^\s*([0-9.]+)\s*\|\s?(.*)$")


def unmask(text: str) -> str:
    return text.replace("#", "5").replace("○", "가")


def fields_of(parsed: dict) -> dict:
    c = parsed["contact"]
    def opt(v):
        return v if v else None
    return {"이름": parsed["name"], "소속": parsed["organization"], "직무": parsed["role"],
            "휴대전화": opt(c["mobile"]), "사무실": opt(c["office"]), "팩스": opt(c["fax"]), "이메일": opt(c["email"])}


def split_cards(text: str) -> list[dict]:
    cards, card, mode = [], None, None
    for raw in text.splitlines():
        line = raw.rstrip("\n")
        if line.startswith("# 명함 읽기 시험"):
            card = {"title": line[2:].strip(), "masked": "가림" in line, "head": [], "reported": {}, "modes": {}}
            cards.append(card)
            mode = None
            continue
        if card is None:
            continue
        if line.startswith("## "):
            mode = line[3:].strip()
            card["modes"][mode] = []
            continue
        if line.startswith("# "):
            card["head"].append(line[2:])
            m = re.match(r"# (\S+): (.*)$", line)
            if m and m.group(1) in FIELDS:
                body = m.group(2).split(" · 채점")[0]
                values = {}
                for part in body.split(" | "):
                    part = part.strip()
                    if part[:1] in MARKS:
                        v = part[1:].strip()
                        values[part[:1]] = None if v in ("(없음)", "(안 읽음)") else v
                card["reported"][m.group(1)] = values
            continue
        if mode is not None:
            m = LINE_RE.match(line)
            if m:
                card["modes"][mode].append([m.group(2), float(m.group(1))])
    return cards


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    show_lines = "--lines" in argv
    cards = split_cards(pathlib.Path(argv[1]).read_text(encoding="utf-8"))
    if not cards:
        print("명함 읽기 시험 글을 찾지 못했습니다 — `# 명함 읽기 시험 — …` 으로 시작하는 글을 붙여 넣으세요.")
        return 1
    drift = 0
    for card in cards:
        print(f"\n━━ {card['title']}")
        for head in card["head"]:
            if head.startswith("테두리"):
                print(f"   {head}")
        for mode, lines in card["modes"].items():
            mark = mode[:1]
            readable = [[unmask(t) if card["masked"] else t, h] for t, h in lines]
            got = fields_of(golden.parse_card(readable))
            print(f"   {mode} · {len(lines)}줄")
            for field in FIELDS:
                reported = card["reported"].get(field, {}).get(mark)
                mine = got[field]
                # 가린 글을 되돌려 읽은 값은 가린 모양으로 견준다.
                shown = golden.card_mask(mine) if (card["masked"] and mine) else mine
                flag = ""
                if reported is not None or shown is not None:
                    if (reported or None) != (shown or None):
                        flag = "   ← 앱이 낸 값과 다름"
                        drift += 1
                print(f"     {field:<5} {shown if shown is not None else '—'}{flag}")
            if show_lines:
                for text, height in lines:
                    print(f"       {height:.4f} | {text}")
    print()
    if drift:
        print(f"앱이 낸 값과 다른 칸 {drift}개 — 가림 되돌리기 탓(이름에 직무 낱말이 섞인 경우 등)이거나 앱과 파이썬 규칙이 어긋났다.")
    else:
        print("앱이 낸 칸과 모두 같다 — 규칙을 고친 뒤 이 글로 다시 돌려 무엇이 바뀌는지 본다.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
