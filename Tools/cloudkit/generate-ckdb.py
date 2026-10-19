#!/usr/bin/env python3
"""SwiftData 모델에서 CloudKit 스키마 파일(.ckdb)을 만든다 (D-42 · ADR-0005 · 느린 부자 Tools/cloudkit 방식).

    python3 Tools/cloudkit/generate-ckdb.py > Tools/cloudkit/slowconnection.ckdb
    python3 Tools/cloudkit/generate-ckdb.py --check     # 커밋한 파일이 모델과 같은가

**원본은 `App/Persistence/Schema.swift` 의 지금 판**(`typealias Person = SchemaVn.Person` 이 가리키는 판)이다.
손으로 옮겨 적지 않는다 — 판을 올릴 때 빠뜨린다.

**규칙은 애플이 정한 것이다** (WWDC19 Using Core Data With CloudKit · 느린 부자 generate-ckdb.py 와 같다).
 · 모델 하나 → 레코드 타입 `CD_<이름>`, 칸 하나 → 필드 `CD_<칸>`, 모든 레코드에 `CD_entityName`
 · 길이가 변하는 값(String · Data · 배열)은 1MB 를 넘을 수 있어 `CD_<칸>_ckAsset` 이 딸린다
 · UUID 는 STRING, Bool 은 INT64(CloudKit 에 불리언이 없다), 날짜는 TIMESTAMP
 · **하나로 가는 관계는 상대 레코드 이름을 STRING 으로** 든다. 여럿으로 가는 쪽은 저장하지 않는다(역관계에서 나온다)
 · **여럿 ↔ 여럿(기록 ↔ 함께한 사람)은 `CDMR` 연결 레코드**가 생긴다 — 느린 부자에는 없던 경우다.
   필드 이름은 CI 탐침(`cloudkit-probe.yml`, 시뮬레이터에서 `initializeCloudKitSchema` 를 dryRun · printSchema 로)이
   찍은 실제 모양과 대조한다.

**넘치게 두는 쪽이 싸다** (느린 부자 교훈): 안 쓰는 필드가 스키마에 있는 것은 무해하지만, 써야 하는데 없으면 Production 이
레코드를 거부하고, Production 스키마는 지울 수 없다.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "App/Persistence/Schema.swift"
OUTPUT = ROOT / "Tools/cloudkit/slowconnection.ckdb"

SCALAR = {
    "String": ("STRING", True),
    "UUID": ("STRING", True),
    "Int": ("INT64", False),
    "Bool": ("INT64", False),
    "Double": ("DOUBLE", False),
    "Date": ("TIMESTAMP", False),
    "Data": ("BYTES", True),
}


def current_schema_block(text):
    """지금 판의 `enum SchemaVn` 본문."""
    match = re.search(r"typealias Person = (SchemaV\d+)\.Person", text)
    if not match:
        sys.exit("지금 판(typealias Person)을 찾지 못했습니다")
    name = match.group(1)
    start = text.index(f"enum {name}: VersionedSchema")
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return name, text[i + 1:j]
    sys.exit("판 본문이 닫히지 않습니다")


def models(block):
    """(이름, [(칸, 타입 글자)]) — @Model 클래스마다 저장 칸만, 적힌 차례대로."""
    out = []
    for match in re.finditer(r"@Model\s+final class (\w+)\s*\{", block):
        depth, j = 1, match.end()
        body_start = j
        while depth:
            if block[j] == "{":
                depth += 1
            elif block[j] == "}":
                depth -= 1
            j += 1
        body = block[body_start:j - 1]
        fields = []
        level = 0
        for line in body.splitlines():
            stripped = line.strip()
            if level == 0:
                field = re.match(r"var (\w+): ([^=]+?)(\s*=.*)?$", stripped)
                if field and "{" not in stripped:
                    fields.append((field.group(1), field.group(2).strip()))
            level += line.count("{") - line.count("}")
        out.append((match.group(1), fields))
    return out


def main():
    _, block = current_schema_block(SCHEMA.read_text())
    entities = models(block)
    names = {name for name, _ in entities}
    many = {}          # (모델, 칸) → 상대 모델 — 여럿으로 가는 관계
    lines = ["DEFINE SCHEMA", ""]
    rows = []
    for name, fields in sorted(entities):
        record = []
        for field, kind in fields:
            base = kind.rstrip("?")
            if base in SCALAR:
                ck, asset = SCALAR[base]
                record.append((field, ck, asset))
            elif base in names:                      # 하나로 가는 관계
                record.append((field, "STRING", False))
            elif re.fullmatch(r"\[(\w+)\]", base) and base[1:-1] in names:
                many[(name, field)] = base[1:-1]     # 여럿으로 가는 관계 — 저장하지 않는다
            elif re.fullmatch(r"\[(\w+)\]", base) and base[1:-1] in SCALAR:
                record.append((field, "BYTES", True))  # 값 배열(태그)은 묶어서 바이트로
            else:
                sys.exit(f"모르는 타입입니다: {name}.{field}: {kind}")
        rows.append((name, record))

    for name, record in rows:
        lines.append(f"    RECORD TYPE CD_{name} (")
        lines += system_fields()
        for field, ck, asset in record:
            lines.append(f"        CD_{field} {ck},")
            if asset:
                lines.append(f"        CD_{field}_ckAsset ASSET,")
        lines += grants()
        lines.append("")

    # 여럿 ↔ 여럿이 하나라도 있으면 연결 레코드 — 기록 ↔ 함께한 사람.
    # A 의 여럿 칸이 B 를 가리키고, B 에도 A 를 가리키는 여럿 칸이 있으면 여럿 ↔ 여럿이다.
    # (자기 자신을 짝으로 세지 않는다 — 사람.소개한 사람들은 하나로 가는 `introducedBy` 의 역이다.)
    mutual = any(key != back and back[0] == other and target == key[0]
                 for key, other in many.items()
                 for back, target in many.items())
    if mutual:
        lines.append("    RECORD TYPE CDMR (")
        lines += system_fields()
        for field in ("CD_entityNames", "CD_recordNames", "CD_relationships"):
            lines.append(f"        {field} STRING,")
            lines.append(f"        {field}_ckAsset ASSET,")
        lines += grants()
        lines.append("")
    return "\n".join(lines) + "\n"


def system_fields():
    return [
        '        "___createTime" TIMESTAMP,',
        '        "___createdBy"  REFERENCE,',
        '        "___etag"       STRING,',
        '        "___modTime"    TIMESTAMP,',
        '        "___modifiedBy" REFERENCE,',
        '        "___recordID"   REFERENCE QUERYABLE,',
        "        CD_entityName   STRING,",
        # 레코드를 존 사이로 옮길 때의 영수증 — 공유를 쓰지 않아도 넘치게 둔다 (느린 부자 4차 2b).
        "        CD_moveReceipt  BYTES,",
        "        CD_moveReceipt_ckAsset ASSET,",
    ]


def grants():
    # 비공개 영역 전용 — 소유자만 읽고 쓴다.
    return [
        '        GRANT WRITE TO "_creator",',
        '        GRANT CREATE TO "_creator",',
        '        GRANT READ TO "_creator"',
        "    );",
    ]


if __name__ == "__main__":
    text = main()
    if "--check" in sys.argv:
        if not OUTPUT.exists() or OUTPUT.read_text() != text:
            sys.exit(f"❌ {OUTPUT.relative_to(ROOT)} 가 모델과 다릅니다 — 다시 만들어 커밋하세요")
        print(f"✅ {OUTPUT.relative_to(ROOT)} 최신")
    else:
        sys.stdout.write(text)
