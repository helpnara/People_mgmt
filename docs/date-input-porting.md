# 날짜 입력 이관 안내서 — 느린 인연의 날짜 칸을 다른 앱으로

> 작성 2026-11-08 · 기준 판 **느린 인연 1.1.9 (빌드 65)** · 저장소 `helpnara/People_mgmt` 브랜치 `claude/slow-connection`
> 이 문서 하나로 다른 앱(느린 부자 · 느린 여백 · 새 앱)에 날짜 입력을 옮길 수 있게 **설계 원칙 · 저장 규칙 · 지난 실수 · 시험 · 전체 코드**를 모았다.
> 코드는 이 판의 파일을 그대로 붙였다(부록). 앱 고유 이름(`Color.accent` 같은 토큰)은 받는 앱의 것으로 바꾸면 된다.

---

## 1. 한눈에

| 무엇 | 어떻게 | 파일 |
|---|---|---|
| 날짜 칸 하나 | 왼쪽 이름 + 오른쪽 **값 칩** → 누르면 **말풍선** → **마지막 단위를 고르는 순간 닫히며** 값이 들어간다 | `ApproxDateField` (`DateField.swift`) |
| 정밀도 | `날짜까지 · 월까지 · 연도만` 세그먼트 — 아는 만큼만 적는다 | `PrecisionPicker` · `Core.DatePrecision` |
| 날짜까지 고르개 | 칸 달력 `‹ 2026년 3월 ⌄ ›` — 화살표로 달, 제목 → 열두 달 → 제목 → 열두 해. **날을 누를 때만 닫힌다** | `DayCalendar` |
| 월까지 고르개 | 열두 달 `‹ 2026년 ⌄ ›` — 제목 → 열두 해. **달을 누를 때만 닫힌다** | `MonthGrid` |
| 연도만 고르개 | 열두 해씩 넘기기. **해를 누르면 닫힌다**. `모름` 칸을 둘 수 있다 | `YearGrid` |
| 해 없는 날(생일 · 기념일) | 달 → 날 두 걸음, 그 달에 없는 날은 없다. 해는 따로 칸(`모름` 포함) | `MonthDayGrid` + `YearGrid` |
| 시각 | 날짜와 **따로** — `시각 넣기` 토글 + 시스템 시각 돌림판. 저장은 자정부터 센 분(0~1439) | `Core.TimeOfDay` |
| 저장 | 날짜는 **그날 12:00 UTC**, 월까지는 그달 1일 · 연도만은 1월 1일로 **접어서** 정오 UTC | `Core.DayNormalizer` · `Core.ApproximateDate` |
| 보이는 글 | 칩 · 목록 · 상세 모두 **저장했을 때 보일 글 그대로** (`2021년 3월` · `2019년` · 날짜까지는 기기 형식) | `ApproximateDate.label` · `Date.shown` |

사용자 평(2026-11-08): *날짜 입력 방식이 매우 잘 구성되어 있어 다른 앱에도 적용하려 한다.*

---

## 2. 설계 원칙 — 바꾸지 말 것

1. **한 꼴만 쓴다.** 앱 안의 모든 날짜 입력(기록 날짜 · 처음 만난 날 · 생일 · 기념일 · 태어난 해)이 `이름 + 값 칩 → 말풍선 → 고르는 순간 닫힘` 이다(이슈 60). 화면마다 다른 날짜 고르개를 두지 않는다.
2. **마지막 단위를 고를 때만 닫는다.** 날짜까지면 *날*, 월까지면 *달*, 연도만이면 *해*. 해 · 달을 넘기거나 고르는 것으로는 닫히지 않는다(이슈 83). 사용자는 해 → 달 → 날을 **한 번 열어** 끝낸다.
3. **시스템 달력(`DatePicker` · `.graphical`)을 날짜 칸에 쓰지 않는다.** 위의 해 · 달을 돌리기만 해도 선택 값이 바뀌어, *날을 누른 것* 과 *해 · 달을 바꾼 것* 을 가를 수 없다 — 값이 바뀌면 닫게 하면 해만 바꿔도 닫힌다(이슈 83 · 빌드 57 까지의 실수). 그래서 칸 달력을 직접 그렸다.
4. **칩에는 저장 결과를 미리 보인다.** 월까지를 고르면 칩이 바로 `2021년 3월`. 저장 규칙과 **같은 함수**(`ApproximateDate.noon` → `label`)로 접어 보인다 — 따로 셈하지 않는다. 미리보기 줄을 따로 두지 않는다.
5. **정밀도는 사람의 기억에 맞춘다.** 오래된 인연은 `2019년` 만 안다. 모르는 것을 강요하지 않는다(FR-033 · D-52). 정밀도를 바꾸면 떠 있던 말풍선은 닫는다.
6. **날은 그달에 맞게 남긴다.** 월 · 해만 바꿀 때 1월 31일 → 2월이면 2월 28 · 29일(`CivilDate.clamped`). 정밀도를 날짜까지로 되돌려도 고른 날이 크게 흔들리지 않는다.
7. **시각은 날짜와 따로.** 시각을 `Date` 의 시 · 분으로 넣으면 시간대가 바뀔 때 날까지 밀린다. 날짜는 정오 UTC, 시각은 *분 숫자*. 시각 없는 기록은 같은 날 안에서 **그날의 끝**으로 선다(`TimeOfDay.noTime` = 1440).
8. **말풍선을 열기 전에 키보드를 내린다.** 입력 칸에 초점이 남은 채 말풍선을 열고 닫으면 화면이 그 칸을 다시 보이려 위아래로 튄다(이슈 61 · `Keyboard.dismiss()`).
9. **누르는 자리는 44pt 이상, 고른 것은 옅은 강조 바탕 · 강조색 굵은 글자, 오늘은 강조색 글자.** 주의 첫날 · 요일 글자는 기기 달력(`Calendar.current`)을 따른다.
10. **접근성 이름에 해를 넣을 때는 `Text(verbatim:)`.** 글 열쇠(`LocalizedStringKey`)에 넣은 정수는 천 단위 쉼표가 붙어 VoiceOver 가 `2,026년 1월` 로 읽는다(이슈 85).
11. **아이폰에서도 말풍선으로.** `.popover` + `.presentationCompactAdaptation(.popover)` — 시트로 바뀌지 않아 화면 맥락이 남는다.

---

## 3. 화면 구성 (사용처)

### 3.1 날짜 + 정밀도 (기록 날짜 · 처음 만난 날)

```swift
Section {
    PrecisionPicker(selection: $draft.occurredPrecision)          // 날짜까지 · 월까지 · 연도만
    ApproxDateField("날짜", date: $draft.occurredAt, precision: draft.occurredPrecision)
    if draft.occurredPrecision == .day {                          // 시각은 날짜까지일 때만
        Toggle("시각 넣기", isOn: hasTime)
        if draft.occurredMinute != nil {
            DatePicker("시각", selection: timeOfDay, displayedComponents: .hourAndMinute)
        }
    }
} footer: {
    Text("기본은 오늘입니다. 예정된 만남은 앞날짜로 적어도 됩니다. … 날짜가 정확하지 않으면 월까지 · 연도만을 고르세요.")
}
```

시각 토글 · 바인딩 (`RecordEditView`):

```swift
/// 시각 넣기 — 켜면 지금 시각을 30분 단위로 내린 값에서 시작한다. 끄면 시각을 비운다.
private var hasTime: Binding<Bool> {
    Binding(get: { draft.occurredMinute != nil }, set: { on in
        if on {
            Keyboard.dismiss()   // 초점이 제목 칸에 남아 화면이 튀지 않게 (이슈 61)
            let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
            draft.occurredMinute = (parts.hour ?? 12) * 60 + ((parts.minute ?? 0) / 30) * 30
        } else {
            draft.occurredMinute = nil
        }
    })
}

/// 시각 고르개 ↔ 자정부터 센 분. 날짜는 쓰지 않는다(날짜는 위 칸).
private var timeOfDay: Binding<Date> {
    Binding(get: {
        let minute = draft.occurredMinute ?? 12 * 60
        return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }, set: { date in
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        draft.occurredMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    })
}
```

### 3.2 해 없는 날 (생일 · 기념일) — 달 → 날, 해는 따로

```swift
LabeledContent("날짜") {
    Button { Keyboard.dismiss(); pickingBirthday = true } label: {
        DateChip(text: "\(draft.birthMonth)월 \(draft.birthDay)일")
    }
    .buttonStyle(.plain)
    .accessibilityHint("눌러서 고릅니다")
    .popover(isPresented: $pickingBirthday) {
        MonthDayGrid(selectedMonth: draft.birthMonth, selectedDay: draft.birthDay,
                     dayLimit: { birthDayLimit(month: $0) }) { month, day in
            draft.birthMonth = month
            draft.birthDay = day
            pickingBirthday = false
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }
}
LabeledContent("태어난 해") {
    Button { Keyboard.dismiss(); pickingBirthYear = true } label: {
        DateChip(text: draft.birthYear.map { "\($0)년" } ?? "모름")
    }
    .buttonStyle(.plain)
    .popover(isPresented: $pickingBirthYear) {
        YearGrid(selected: draft.birthYear, range: 1900...올해, unknownLabel: "모름") { year in
            draft.birthYear = year          // nil = 모름
            pickingBirthYear = false
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }
}

/// 그 달에 없는 날은 고를 수 없다 — 해를 모르면 2월은 29일까지.
private func birthDayLimit(month: Int) -> Int {
    if let year = draft.birthYear { return CivilDate.daysIn(month: month, year: year) }
    return month == 2 ? 29 : CivilDate.daysIn(month: month, year: 2001)
}
// 해 · 달이 바뀌면 날을 그 달에 맞게 내린다 (.onChange(of: birthMonth / birthYear) → clamp)
```

### 3.3 정밀도 없이 날짜 하나만 필요한 앱

`ApproxDateField("날짜", date: $date, precision: .day)` 로 쓰면 된다(명함 여러 장 등록의 `처음 만난 날` 이 이렇게 쓴다). 정밀도 칸을 두지 않으면 `PrecisionPicker` 는 빼도 된다.

---

## 4. 저장 규칙 (자료 모양)

| 칸 | 타입 | 규칙 |
|---|---|---|
| 날짜 | `Date` | **그날 12:00 UTC** (`DayNormalizer.noon`) — 연 · 월 · 일은 그 기기 시간대에서 읽고 그 날의 정오 UTC 로. UTC−11 ~ +11 어디서 읽어도 같은 날 |
| 정밀도 | `Int` (기본 0) | 0 날짜까지 · 1 월까지 · 2 연도만 (`DatePrecision.of` — 모르는 값은 날짜까지). 월까지면 **그달 1일**, 연도만이면 **그해 1월 1일** 정오 UTC 로 접어 저장(`ApproximateDate.noon`) |
| 시각 | `Int?` | 자정부터 센 분 0 ~ 1439, 없으면 nil. 날짜까지일 때만 저장(월 · 연도면 지운다 — `TimeOfDay.clamped`) |
| 해 없는 날 | `month: Int`, `day: Int`, `year: Int?` | 생일 · 기념일. 해가 없으면 2월 29일 허용 |

정렬 · 마지막 기록일 · 며칠 전(`RelativeDay`) · 알림은 **접은 값**을 그대로 쓴다 — 따로 셈하지 않는다.
같은 날 안의 차례: 시각이 늦은 것 먼저, **시각 없는 것은 그날의 끝**(`TimeOfDay.sortKey`), 그다음 만든 시각 역순 (`TimelineSort`).

**옛 자료 옮기기**: 날짜를 *기기 시간대의 정오* 나 *자정* 으로 저장해 왔다면, 앱을 처음 켤 때 한 번 정오 UTC 로 옮긴다(`DateConvention.migrateIfNeeded` · 깃발 `dates.utcNoon.v1` · 실패하면 되돌리고 다음에 다시). 두 번 돌아도 그대로다.

**CloudKit · 스키마**: 정밀도 · 시각 칸은 모두 기본값(0 · nil)이 있어 가벼운 옮기기로 들어간다. CloudKit 을 쓰면 새 칸을 개발 환경에 올리고 Production 에 배포해야 한다.

**백업**: 정밀도 · 시각을 옵셔널로 실어, 옛 백업은 날짜까지 · 시각 없음으로 읽는다.

---

## 5. 지난 실수와 교훈 (이슈 번호는 `docs/08-feedback.md`)

| 이슈 · 빌드 | 무엇이 문제였나 | 지금의 답 |
|---|---|---|
| 20 · 빌드 12~13 | 날짜를 **기기 시간대의 정오**로 저장 → 서울에서 적은 3월 8일이 LA 에서 3월 7일로 | 그날의 **12:00 UTC**. 옛 값은 처음 켤 때 한 번 옮김 |
| 38 · 빌드 28 | 오래된 인연은 날짜를 모른다 | 정밀도 셋 · 접어서 저장 · 보이는 글 `2021년 3월` |
| 59 · 빌드 39 | 시스템 달력은 날을 골라도 떠 있고 바깥을 눌러야 닫혔다 | (60 으로 바뀜) |
| 60 · 빌드 39 | 화면마다 날짜 입력이 달랐다 | **한 꼴** — 칩 → 말풍선 → 고르는 순간 닫힘. 정밀도마다 맞는 고르개 |
| 61 · 빌드 40 | 입력 칸 초점이 남은 채 말풍선을 열고 닫으면 화면이 튐 · 새 기록이 날짜 칸이 아니라 제목 칸에서 열림 | 말풍선 · 시각 넣기 전에 `Keyboard.dismiss()` · 새 기록은 초점 없이 맨 위(날짜)에서 |
| 83 · 빌드 58 | **해를 바꾸면 달력이 닫혔다** → 다시 열어 달 → 닫힘 → 다시 열어 날 (시스템 달력은 해 · 달만 돌려도 값이 바뀜) | 칸 달력 `DayCalendar` — 해 · 달은 닫히지 않고 **날에서만** 닫힘. 월까지도 제목 → 열두 해 |
| 85 · 빌드 60 | VoiceOver 가 `2,026년 1월` 로 읽음 (`LocalizedStringKey` 의 정수 서식) | 해가 든 접근성 이름은 `Text(verbatim:)` |
| D-63 · 빌드 39 | 같은 날 약속 둘의 차례 | 시각 칸(분) · 시각 없는 것은 그날의 끝 |

**화면 시험이 잡은 것** (`UITests/NavigationUITests.swift` `testDayCalendarClosesOnlyOnDay`):
- 칩 글(`2026년 11월 5일`)도 `…일` 로 끝나 *날 칸* 으로 잘못 보였다 → 찾을 때 `identifier != "dateChip"` 으로 칩을 뺀다(CI 132 · 134).
- 줄 전체가 잡혀 가운데 빈 곳을 누르면 말풍선이 안 뜬다 → 칩 위에 떨어지는 오른쪽 자리(`dx: 0.85`)를 누른다(CI 136).
- 단계가 바뀌는 동안 누르면 사라지던 칸이 눌린다 → 단계마다 화면이 바뀐 것을 본 뒤 누른다(CI 137).

---

## 6. 의존하는 것 (받는 앱에서 바꿀 것)

| 이 코드가 쓰는 것 | 뜻 | 받는 앱에서 |
|---|---|---|
| `Color.accent` · `accentSoft` · `chip` · `ink` · `muted` | 색 토큰(라이트 · 다크) | 그 앱의 토큰으로 이름만 바꾼다. `Color.white` · `.black` 은 쓰지 않는다 |
| `Font.scaled(_:weight:)` | 글자 설정을 따르는 크기(`UIFontMetrics`) | 그 앱의 것, 없으면 부록의 두 줄을 가져간다 |
| `Keyboard.dismiss()` | 떠 있는 키보드 내리기 | 부록 그대로 |
| `CivilDate` (`daysIn` · `clamped`) | 시간대 없는 연 · 월 · 일 | 부록의 앞부분만 |
| `DatePrecision` · `ApproximateDate` · `DayNormalizer` · `TimeOfDay` | 순수 Foundation — 리눅스에서도 시험된다 | Core 패키지(또는 그 앱의 순수 로직 모듈)에 그대로 |
| 문구 | `날짜까지 · 월까지 · 연도만` · `눌러서 고릅니다` · `모름` · `달을 고르세요` · `이전` · `다음` | 그대로 쓰거나 그 앱 말투로 |

iOS 17 이상 (`presentationCompactAdaptation` · `LabeledContent`). Swift 6 엄격 동시성에서 그대로 빌드된다.

---

## 7. 이관 순서 (체크리스트)

1. [ ] 순수 로직 4개(`DatePrecision` · `ApproximateDate` · `DayNormalizer` · `TimeOfDay`)와 `CivilDate` 앞부분을 순수 모듈에 넣는다.
2. [ ] 정답표(§8)를 옮겨 순수 로직 시험을 먼저 통과시킨다 — 기댓값은 파이썬이 계산한 것만 쓴다.
3. [ ] `DateField.swift` · `PrecisionPicker.swift` · `Keyboard.swift` 를 넣고 색 · 글꼴 토큰 이름을 바꾼다.
4. [ ] 날짜 칸이 있는 화면을 **전수 조사**해 모두 `ApproxDateField`(또는 `MonthDayGrid` · `YearGrid`)로 바꾼다. `DatePicker(.graphical / .compact)` 날짜 칸이 남지 않게(시각 돌림판은 그대로).
5. [ ] 저장하는 곳에서 `ApproximateDate.noon(of:precision:calendar:)` 로 접는다. 보이는 곳은 `Date.shown(precision:style:)`.
6. [ ] 정밀도 · 시각 칸을 스키마에 더한다(기본값 있음 · 가벼운 옮기기). 옛 날짜는 정오 UTC 로 한 번 옮긴다(§4).
7. [ ] 백업 · 내보내기에 정밀도 · 시각을 싣는다(옵셔널).
8. [ ] 화면 시험 `testDayCalendarClosesOnlyOnDay` 를 옮긴다 — 해 → 달 → 날, 날에서만 닫힘.
9. [ ] 실기기 확인: ① 해를 바꿔도 안 닫힘 ② 날을 누르면 닫히고 칩이 그 날 ③ 월까지 · 연도만 칩 글 ④ 입력 중 날짜 칩 → 화면 안 튐 ⑤ VoiceOver 로 달 · 날 칸 이름에 쉼표 없음 ⑥ 껐다 켜도 그대로.

---

## 8. 정답표 (파이썬 · 기댓값의 근원)

Swift 시험의 수치 · 글 기댓값은 이 파이썬이 계산한 JSON 만 쓴다(느린 시리즈 규칙).

```python
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

NO_TIME = 24 * 60  # 시각 없는 기록은 그날의 끝


def noon_epoch(iso: str, zone: str) -> float:
    # 연 · 월 · 일은 그 시간대에서 읽고, 그 날의 12:00 UTC (이슈 20).
    instant = datetime.fromisoformat(iso)
    local = instant.astimezone(ZoneInfo(zone))
    return datetime(local.year, local.month, local.day, 12, tzinfo=timezone.utc).timestamp()


def approx_noon(iso: str, zone: str, precision: int):
    """(정오 epoch, 보이는 글) — 날짜까지는 그날, 월까지는 그달 1일, 연도만은 1월 1일의 12:00 UTC (Swift `ApproximateDate`)."""
    day = datetime.fromtimestamp(noon_epoch(iso, zone), tz=timezone.utc)
    if precision not in (1, 2):  # 모르는 값은 날짜까지 (`DatePrecision.of`)
        return day.timestamp(), None
    month = 1 if precision == 2 else day.month
    folded_day = datetime(day.year, month, 1, 12, tzinfo=timezone.utc)
    label = f"{day.year}년" if precision == 2 else f"{day.year}년 {day.month}월"
    return folded_day.timestamp(), label


def time_text(minute: int) -> str:
    m = min(max(minute, 0), NO_TIME - 1)
    hour = m // 60
    half = "오전" if hour < 12 else "오후"
    shown = 12 if hour % 12 == 0 else hour % 12
    return f"{half} {shown}:{m % 60:02d}"


def time_key(minute):
    return NO_TIME if minute is None else min(max(minute, 0), NO_TIME - 1)
```

입력 사례 (`Tools/golden/cases.json` 의 해당 칸):

```json
{
  "dayNoon": [
    {
      "iso": "2026-03-08T23:30:00+09:00",
      "timeZone": "Asia/Seoul"
    },
    {
      "iso": "2026-03-08T23:30:00+09:00",
      "timeZone": "UTC"
    },
    {
      "iso": "2026-01-01T00:00:00+09:00",
      "timeZone": "Asia/Seoul"
    },
    {
      "iso": "2025-12-31T23:59:59+09:00",
      "timeZone": "Asia/Seoul"
    },
    {
      "iso": "2026-03-08T00:30:00+09:00",
      "timeZone": "America/Los_Angeles"
    },
    {
      "iso": "2026-03-08T12:00:00+00:00",
      "timeZone": "Pacific/Auckland"
    },
    {
      "iso": "2026-07-01T00:10:00-07:00",
      "timeZone": "America/Los_Angeles"
    }
  ],
  "approxDate": [
    {
      "iso": "2021-03-04T09:00:00+09:00",
      "timeZone": "Asia/Seoul",
      "precision": 0
    },
    {
      "iso": "2021-03-04T09:00:00+09:00",
      "timeZone": "Asia/Seoul",
      "precision": 1
    },
    {
      "iso": "2021-03-04T09:00:00+09:00",
      "timeZone": "Asia/Seoul",
      "precision": 2
    },
    {
      "iso": "2021-03-01T00:30:00+09:00",
      "timeZone": "Asia/Seoul",
      "precision": 1
    },
    {
      "iso": "2021-03-01T00:30:00+09:00",
      "timeZone": "UTC",
      "precision": 1
    },
    {
      "iso": "2019-12-31T23:30:00+09:00",
      "timeZone": "Asia/Seoul",
      "precision": 2
    },
    {
      "iso": "2019-12-31T23:30:00+09:00",
      "timeZone": "America/Los_Angeles",
      "precision": 2
    },
    {
      "iso": "2024-02-29T12:00:00+00:00",
      "timeZone": "UTC",
      "precision": 1
    },
    {
      "iso": "2024-02-29T12:00:00+00:00",
      "timeZone": "UTC",
      "precision": 9
    }
  ],
  "timeOfDay": [
    0,
    5,
    59,
    540,
    545,
    719,
    720,
    721,
    870,
    1439,
    1500,
    -3
  ]
}
```

시험의 꼴 — `expectedEpoch` 와 `ApproximateDate.noon(...).timeIntervalSince1970`, `expectedLabel` 과 `ApproximateDate.label(...)`, `text` · `sortKey` 와 `TimeOfDay.text` · `sortKey` 를 견준다.

---

## 9. 부록 — 전체 코드 (1.1.9 그대로)

#### `App/Features/Shared/DateField.swift`

```swift
import Core
import SwiftUI

/// **날짜 칸 하나** (빌드 39 · 1.1 · 이슈 60 · 2026-11-01 사용자) — 앱의 날짜 입력은 모두 이 꼴이다.
/// 왼쪽에 이름, 오른쪽에 지금 값(누르는 칩). 누르면 말풍선이 뜨고 **정밀도의 마지막 단위를 고르는 순간 닫히며 값이 들어간다**.
///
/// - 날짜까지: 달력(`DayCalendar`) — 해 · 달은 위 제목을 눌러 바꾸고(닫히지 않는다), **날을 누르면** 닫힌다
/// - 월까지: 열두 달 — 해는 제목을 눌러 바꾸고(닫히지 않는다), **달을 누르면** 닫힌다
/// - 연도만: 열두 해씩 넘기며 — **해를 누르면** 닫힌다
///
/// 빌드 57 까지 날짜까지는 시스템 달력(`DatePicker` · graphical)이었고 값이 바뀌면 닫았다 — 시스템 달력은 위의 해 · 달을
/// 돌리기만 해도 고른 날을 바꾸므로 해만 바꿔도 닫혔다(이슈 83 · 2026-11-05 사용자: 해 → 닫힘 → 다시 열어 달 → 닫힘 → 다시 열어 날).
/// 날을 누른 것과 해 · 달을 바꾼 것을 시스템 달력에서는 가를 수 없어, 앱의 다른 고르개와 같은 칸 달력으로 바꿨다.
///
/// 저장할 때 `Core.ApproximateDate` 가 접는다(월까지 = 그달 1일 · 연도만 = 1월 1일). 여기서는 달 · 해만 바꾸고 날은 그달에
/// 맞게 남긴다(`Core.CivilDate.clamped`) — 정밀도를 날짜까지로 되돌려도 고른 날이 크게 흔들리지 않게.
struct ApproxDateField: View {
    let title: LocalizedStringKey
    @Binding var date: Date
    let precision: DatePrecision
    @State private var picking = false

    init(_ title: LocalizedStringKey, date: Binding<Date>, precision: DatePrecision) {
        self.title = title
        self._date = date
        self.precision = precision
    }

    var body: some View {
        LabeledContent(title) {
            Button {
                // 입력 칸의 초점을 먼저 놓는다 — 말풍선이 닫힐 때 화면이 그 칸으로 튀지 않게 (이슈 61).
                Keyboard.dismiss()
                picking = true
            } label: {
                DateChip(text: valueText)
            }
            .buttonStyle(.plain)
            .accessibilityHint("눌러서 고릅니다")
            .accessibilityIdentifier("dateChip")
            .popover(isPresented: $picking) {
                picker
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
            }
        }
        // 정밀도를 바꾸면 떠 있던 말풍선은 닫는다 — 다른 꼴의 고르개가 남지 않게.
        .onChange(of: precision) { _, _ in picking = false }
    }

    /// 저장했을 때 보일 글 그대로 — 저장 규칙과 같은 함수로 접어 본다.
    private var valueText: String {
        let stored = ApproximateDate.noon(of: date, precision: precision, calendar: .current)
        return ApproximateDate.label(of: stored, precision: precision) ?? date.formatted(date: .long, time: .omitted)
    }

    private var parts: (year: Int, month: Int, day: Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// 고른 연 · 월(· 일)로 바꾸고 닫는다. 날을 주지 않으면 지금 날을 그달에 맞게 남긴다.
    private func set(year: Int, month: Int, day: Int? = nil) {
        let civil = CivilDate.clamped(year: year, month: month, day: day ?? parts.day)
        if let next = Calendar.current.date(from: DateComponents(year: civil.year, month: civil.month, day: civil.day, hour: 12)) {
            date = next
        }
        picking = false
    }

    @ViewBuilder
    private var picker: some View {
        switch precision {
        case .day:
            DayCalendar(selectedYear: parts.year, selectedMonth: parts.month, selectedDay: parts.day) { year, month, day in
                set(year: year, month: month, day: day)
            }
        case .month:
            MonthGrid(selectedYear: parts.year, selectedMonth: parts.month) { year, month in
                set(year: year, month: month)
            }
        case .year:
            YearGrid(selected: parts.year, range: DateGrids.years) { year in
                if let year { set(year: year, month: parts.month) }
            }
        }
    }
}

/// 날짜 칸의 값 칩 — 시스템 날짜 고르개의 작은 꼴과 비슷하게(옅은 바탕 · 강조색 글자).
struct DateChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.scaled(16))
            .foregroundStyle(Color.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.chip, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}

enum DateGrids {
    /// 고를 수 있는 해 — 1900년부터 올해 + 10년(예정된 만남)까지.
    static let years: ClosedRange<Int> = {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        return 1900...(now + 10)
    }()
}

/// 칸 하나 — 누르기 쉬운 크기(44pt 이상), 고른 것은 옅은 강조 바탕 · 강조색 굵은 글자.
private struct GridCell: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.scaled(16, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.accent : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.accentSoft : Color.chip, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 해가 든 접근성 이름은 `Text(verbatim:)` 로 — 글 열쇠(LocalizedStringKey)에 넣은 정수는 천 단위 쉼표가 붙어
/// `2,026년 1월` 이 된다(CI 138 에서 찾음 · VoiceOver 도 그렇게 읽는다).
/// 위쪽 넘기기 줄 — `‹ 2026년 ›`. `onTitle` 이 있으면 제목이 단추다(`2026년 3월 ⌄` — 눌러서 한 단계 위를 고른다).
private struct PagerHeader: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void
    var onTitle: (() -> Void)?
    var titleHint: String = ""

    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("이전")
            Spacer()
            if let onTitle {
                Button(action: onTitle) {
                    HStack(spacing: 4) {
                        Text(title).font(.scaled(17, weight: .semibold)).foregroundStyle(Color.ink)
                        Image(systemName: "chevron.down").font(.scaled(12, weight: .semibold)).foregroundStyle(Color.accent)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(titleHint)
                .accessibilityIdentifier("calendarTitle")
            } else {
                Text(title).font(.scaled(17, weight: .semibold)).foregroundStyle(Color.ink)
            }
            Spacer()
            Button(action: forward) {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("다음")
        }
        .foregroundStyle(Color.accent)
    }
}

/// 열두 달 — 해를 넘기고 달을 누르면 그 연 · 월을 알린다. 제목(`2026년 ⌄`)을 누르면 열두 해에서 해를 고른다 —
/// 해를 골라도 알리지 않고(닫히지 않는다) 그 해의 열두 달로 돌아온다 (이슈 83).
struct MonthGrid: View {
    let selectedYear: Int
    let selectedMonth: Int
    let onPick: (Int, Int) -> Void
    @State private var year: Int
    @State private var choosingYear = false

    init(selectedYear: Int, selectedMonth: Int, onPick: @escaping (Int, Int) -> Void) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.onPick = onPick
        self._year = State(initialValue: selectedYear)
    }

    var body: some View {
        if choosingYear {
            YearGrid(selected: year, range: DateGrids.years) { picked in
                if let picked { year = picked }
                choosingYear = false
            }
        } else {
            months
        }
    }

    private var months: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(year)년",
                        canGoBack: year > DateGrids.years.lowerBound, canGoForward: year < DateGrids.years.upperBound,
                        back: { year -= 1 }, forward: { year += 1 },
                        onTitle: { choosingYear = true }, titleHint: "눌러서 해를 고릅니다")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    GridCell(text: "\(month)월", selected: year == selectedYear && month == selectedMonth) {
                        onPick(year, month)
                    }
                    .accessibilityLabel(Text(verbatim: "\(year)년 \(month)월"))
                }
            }
        }
        .frame(minWidth: 280)
    }
}

/// 열두 해씩 — 넘기고 해를 누르면 그 해를 알린다. `unknownLabel` 이 있으면 맨 위에 `모름` 단추(nil 을 알린다).
struct YearGrid: View {
    let selected: Int?
    let range: ClosedRange<Int>
    var unknownLabel: String?
    let onPick: (Int?) -> Void
    @State private var start: Int

    init(selected: Int?, range: ClosedRange<Int>, unknownLabel: String? = nil, onPick: @escaping (Int?) -> Void) {
        self.selected = selected
        self.range = range
        self.unknownLabel = unknownLabel
        self.onPick = onPick
        let anchor = min(max(selected ?? Calendar(identifier: .gregorian).component(.year, from: Date()), range.lowerBound),
                         range.upperBound)
        self._start = State(initialValue: anchor - (anchor - range.lowerBound) % 12)
    }

    var body: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(start) – \(min(start + 11, range.upperBound))",
                        canGoBack: start > range.lowerBound, canGoForward: start + 12 <= range.upperBound,
                        back: { start -= 12 }, forward: { start += 12 })
            if let unknownLabel {
                GridCell(text: unknownLabel, selected: selected == nil) { onPick(nil) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(start...min(start + 11, range.upperBound)), id: \.self) { year in
                    GridCell(text: "\(year)년", selected: year == selected) { onPick(year) }
                }
            }
        }
        .frame(minWidth: 280)
    }
}

/// 생일의 월 · 일 — 달을 누르면 그 달의 날로 넘어가고, 날을 누르면 알린다. 그 달에 없는 날은 없다(`dayLimit`).
struct MonthDayGrid: View {
    let selectedMonth: Int
    let selectedDay: Int
    let dayLimit: (Int) -> Int
    let onPick: (Int, Int) -> Void
    @State private var month: Int?

    init(selectedMonth: Int, selectedDay: Int, dayLimit: @escaping (Int) -> Int, onPick: @escaping (Int, Int) -> Void) {
        self.selectedMonth = selectedMonth
        self.selectedDay = selectedDay
        self.dayLimit = dayLimit
        self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: 8) {
            if let month {
                PagerHeader(title: "\(month)월", canGoBack: true, canGoForward: false,
                            back: { self.month = nil }, forward: {})
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(1...dayLimit(month), id: \.self) { day in
                        GridCell(text: "\(day)", selected: month == selectedMonth && day == selectedDay) {
                            onPick(month, day)
                        }
                        .accessibilityLabel("\(month)월 \(day)일")
                    }
                }
            } else {
                Text("달을 고르세요").font(.scaled(15, weight: .semibold)).foregroundStyle(Color.ink)
                    .frame(minHeight: 44)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(1...12, id: \.self) { m in
                        GridCell(text: "\(m)월", selected: m == selectedMonth) { month = m }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }
}

/// **날짜까지 달력** (이슈 83 · 2026-11-05 사용자) — 해 → 달 → 날 차례로 고르고 **날을 누를 때만** 알린다(닫힌다).
///
/// - 날: `‹ 2026년 3월 ⌄ ›` — 화살표로 달을 넘기고, 제목을 누르면 열두 달로
/// - 달: `‹ 2026년 ⌄ ›` 열두 달 — 달을 누르면 그 달의 날로(닫히지 않는다), 제목을 누르면 열두 해로
/// - 해: 열두 해씩 — 해를 누르면 그 해의 열두 달로(닫히지 않는다)
///
/// 주의 첫날 · 요일 글자는 기기 달력(`Calendar.current`)을 따른다. 오늘은 강조색 글자, 고른 날은 옅은 강조 바탕.
struct DayCalendar: View {
    let selectedYear: Int
    let selectedMonth: Int
    let selectedDay: Int
    let onPick: (Int, Int, Int) -> Void
    @State private var year: Int
    @State private var month: Int
    @State private var stage: Stage = .days

    private enum Stage { case days, months, years }

    init(selectedYear: Int, selectedMonth: Int, selectedDay: Int, onPick: @escaping (Int, Int, Int) -> Void) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.selectedDay = selectedDay
        self.onPick = onPick
        self._year = State(initialValue: selectedYear)
        self._month = State(initialValue: selectedMonth)
    }

    var body: some View {
        Group {
            switch stage {
            case .days: days
            case .months: months
            case .years:
                YearGrid(selected: year, range: DateGrids.years) { picked in
                    if let picked { year = picked }
                    stage = .months
                }
            }
        }
        .frame(minWidth: 300)
    }

    // MARK: 날

    private var days: some View {
        let calendar = Calendar.current
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12)) ?? Date()
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return VStack(spacing: 6) {
            PagerHeader(title: "\(year)년 \(month)월",
                        canGoBack: !(year == DateGrids.years.lowerBound && month == 1),
                        canGoForward: !(year == DateGrids.years.upperBound && month == 12),
                        back: { step(-1) }, forward: { step(1) },
                        onTitle: { stage = .months }, titleHint: "눌러서 해와 달을 고릅니다")
            dayGrid(lead: lead, count: count, today: today, symbols: weekdaySymbols(calendar))
        }
    }

    /// 요일 줄 + 날 칸 — 한 식이 길면 컴파일러가 형식을 제때 못 맞춰 떼어 둔다(빌드 45 교훈).
    private func dayGrid(lead: Int, count: Int, today: DateComponents, symbols: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.scaled(12, weight: .semibold))
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .accessibilityHidden(true)
            }
            ForEach(0..<(lead + count), id: \.self) { slot in
                daySlot(slot - lead + 1, today: today)
            }
        }
    }

    @ViewBuilder
    private func daySlot(_ day: Int, today: DateComponents) -> some View {
        if day < 1 {
            Color.clear.frame(minHeight: 40).accessibilityHidden(true)
        } else {
            DayCell(day: day,
                    selected: year == selectedYear && month == selectedMonth && day == selectedDay,
                    isToday: today.year == year && today.month == month && today.day == day) {
                onPick(year, month, day)
            }
            .accessibilityLabel(Text(verbatim: "\(year)년 \(month)월 \(day)일"))
        }
    }

    /// 요일 글자 — 기기의 주 첫날부터.
    private func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    /// 달 넘기기 — 해가 바뀌면 해도 넘긴다.
    private func step(_ delta: Int) {
        var m = month + delta
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        guard DateGrids.years.contains(y) else { return }
        year = y
        month = m
    }

    // MARK: 달

    private var months: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(year)년",
                        canGoBack: year > DateGrids.years.lowerBound, canGoForward: year < DateGrids.years.upperBound,
                        back: { year -= 1 }, forward: { year += 1 },
                        onTitle: { stage = .years }, titleHint: "눌러서 해를 고릅니다")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    GridCell(text: "\(m)월", selected: year == selectedYear && m == selectedMonth) {
                        month = m
                        stage = .days
                    }
                    .accessibilityLabel(Text(verbatim: "\(year)년 \(m)월"))
                }
            }
        }
    }
}

/// 달력의 날 칸 — 고른 날은 옅은 강조 바탕 · 굵은 강조 글자, 오늘은 강조 글자.
private struct DayCell: View {
    let day: Int
    let selected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(day)")
                .font(.scaled(16, weight: selected || isToday ? .semibold : .regular))
                .foregroundStyle(selected || isToday ? Color.accent : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? Color.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
```

#### `App/Features/Shared/PrecisionPicker.swift`

```swift
import Core
import SwiftUI

/// 날짜의 정밀도 고르기 (FR-033) — 날짜까지 · 월까지 · 연도만. 바로 아래 날짜 칸(`ApproxDateField`)이 고른 정밀도의
/// 고르개(달력 · 열두 달 · 열두 해)를 띄우고, 저장했을 때 보일 글 그대로 값을 보인다 (빌드 39 · 이슈 60).
struct PrecisionPicker: View {
    @Binding var selection: DatePrecision

    var body: some View {
        Picker("정밀도", selection: $selection) {
            ForEach(DatePrecision.allCases) { precision in
                Text(precision.label).tag(precision)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("날짜를 얼마나 정확히 아나요")
        .padding(.vertical, 2)
    }
}
```

#### `App/Features/Shared/Keyboard.swift`

```swift
import UIKit

/// 떠 있는 키보드를 내린다 (빌드 40 · 1.1 · 이슈 61).
///
/// 입력 칸에 초점이 남은 채 날짜 말풍선을 열고 닫으면, 화면이 그 입력 칸을 다시 보이려고 위아래로 튀었다.
/// 날짜 · 시각을 고르기 **전에** 초점을 놓아 화면이 제자리에 머물게 한다. 어느 칸에 초점이 있는지 몰라도 된다.
enum Keyboard {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
```

#### `App/DesignSystem/DateText.swift`

```swift
import Core
import Foundation

extension Date {
    /// 정밀도를 따른 보이는 글 (FR-033) — 월까지 `2021년 3월`, 연도만 `2019년`(`Core.ApproximateDate`), 날짜까지는 기기 형식 그대로.
    func shown(precision: Int, style: Date.FormatStyle.DateStyle) -> String {
        ApproximateDate.label(of: self, precision: .of(precision)) ?? formatted(date: style, time: .omitted)
    }
}
```

#### `Packages/Core/Sources/Core/Dates/ApproximateDate.swift`

```swift
import Foundation

/// 날짜의 **정밀도** (FR-033 · D-52) — 처음 만난 날 · 기록 날짜를 `2019년`, `2021년 3월` 처럼 적는다.
/// 저장 칸의 값(0 · 1 · 2)이 곧 `rawValue` 다. 모르는 값은 날짜까지로 읽는다.
public enum DatePrecision: Int, Sendable, CaseIterable, Identifiable {
    case day = 0
    case month = 1
    case year = 2

    public var id: Int { rawValue }

    public static func of(_ raw: Int) -> DatePrecision {
        DatePrecision(rawValue: raw) ?? .day
    }

    /// 고르기 칩의 이름.
    public var label: String {
        switch self {
        case .day: return "날짜까지"
        case .month: return "월까지"
        case .year: return "연도만"
        }
    }
}

/// 대략 날짜 — 저장과 보이는 글.
///
/// - **저장**: 고른 날을 그날 정오(UTC)로 맞추는 규칙(`DayNormalizer.noon`)을 먼저 거치고, 월까지면 **그달 1일**, 연도만이면
///   **그해 1월 1일**로 접는다. 정렬 · 마지막 기록일 · 관계 셈은 이 접은 날을 쓴다 — 따로 셈하지 않는다.
/// - **보이는 글**: 월까지 `2021년 3월`, 연도만 `2019년`. 날짜까지는 `nil` — 화면이 지금처럼 기기 형식으로 쓴다.
/// 정답표 `approxDate` 가 대조한다.
public enum ApproximateDate {

    public static func noon(of date: Date, precision: DatePrecision, calendar: Calendar) -> Date {
        let noon = DayNormalizer.noon(of: date, calendar: calendar)
        guard precision != .day else { return noon }
        let utc = utcCalendar
        var parts = utc.dateComponents([.year, .month], from: noon)
        if precision == .year { parts.month = 1 }
        parts.day = 1
        parts.hour = 12
        return utc.date(from: parts) ?? noon
    }

    /// 정오(UTC)로 저장된 날의 보이는 글. 날짜까지는 `nil`.
    public static func label(of stored: Date, precision: DatePrecision) -> String? {
        let parts = utcCalendar.dateComponents([.year, .month], from: stored)
        guard let year = parts.year, let month = parts.month else { return nil }
        switch precision {
        case .day: return nil
        case .month: return "\(year)년 \(month)월"
        case .year: return "\(year)년"
        }
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
```

#### `Packages/Core/Sources/Core/Dates/DayNormalizer.swift`

```swift
import Foundation

/// 날짜만 뜻이 있는 칸(처음 만난 날짜 · 기록 날짜)을 **그날 정오(UTC)** 로 맞춘다 (요구사항 7.3 · 830).
///
/// 자정으로 두면 시간대가 바뀌는 순간 하루가 밀린다. 빌드 12 까지는 **기기 시간대의 정오**로 두었는데,
/// 그 정오는 적은 곳에서 ±12시간 안의 곳에서만 같은 날이다 — 서울(+9)에서 적은 3월 8일 정오는 03:00 UTC 라
/// LA(−7)에서 3월 7일 20시, 3월 7일로 보였다 (전수조사 이슈 20).
///
/// 그래서 **고른 날의 연 · 월 · 일은 부르는 쪽 달력(그 기기의 시간대)에서 읽고, 그 날의 12:00 UTC 로** 저장한다.
/// 12:00 UTC 는 UTC−11 부터 UTC+11 까지 어디서 보아도 같은 날이라, 화면은 기기 시간대 그대로 읽으면 된다.
/// 남는 틈: UTC+12 이상(뉴질랜드 서머타임 +13 · 키리바시 +14)과 UTC−12 에서는 하루 뒤 · 앞으로 보인다.
public enum DayNormalizer {

    public static func noon(of date: Date, calendar: Calendar) -> Date {
        // 연 · 월 · 일은 그레고리력으로 읽는다 — 부르는 쪽 달력이 불기 · 일본력이어도 날의 경계는 시간대만 따른다.
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        let day = local.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        var noon = DateComponents()
        noon.year = day.year
        noon.month = day.month
        noon.day = day.day
        noon.hour = 12
        return utc.date(from: noon) ?? local.startOfDay(for: date).addingTimeInterval(12 * 60 * 60)
    }

    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
```

#### `Packages/Core/Sources/Core/Dates/TimeOfDay.swift`

```swift
import Foundation

/// 기록의 **시각** (8판 · 빌드 39 · D-63) — 자정부터 센 분(0 ~ 1439). 날짜 칸과 따로 두어 시차에 흔들리지 않는다.
///
/// 시각은 고른 그 시계 숫자 그대로다(오후 2시 30분 = 870). 비어 있으면 시각이 없는 기록이고, 같은 날 안의 차례에서는
/// **그날의 끝**(`noTime` = 1440)으로 본다 (2026-11-01 사용자). 파이썬 정답표(`Tools/golden` 의 `timeOfDay`)와 같은 셈이다.
public enum TimeOfDay {
    public static let minutesPerDay = 24 * 60
    /// 시각 없는 기록이 차례에서 서는 자리 — 그날의 어느 시각보다도 뒤.
    public static let noTime = minutesPerDay

    /// 저장 전에 0 ~ 1439 로 자른다.
    public static func clamped(_ minute: Int?) -> Int? {
        minute.map { min(max($0, 0), minutesPerDay - 1) }
    }

    /// 차례에 쓰는 값 — 없으면 `noTime`.
    public static func sortKey(_ minute: Int?) -> Int {
        clamped(minute) ?? noTime
    }

    /// `오전 9:05` · `오후 2:30` · `오후 12:00`(정오) · `오전 12:00`(자정).
    public static func text(_ minute: Int) -> String {
        let m = min(max(minute, 0), minutesPerDay - 1)
        let hour = m / 60
        let half = hour < 12 ? "오전" : "오후"
        let shown = hour % 12 == 0 ? 12 : hour % 12
        return "\(half) \(shown):" + String(format: "%02d", m % 60)
    }
}
```

#### `Packages/Core/Sources/Core/Reminders/CivilDate.swift` (앞부분)

```swift
import Foundation

/// 시간대 없는 **달력의 날** (연 · 월 · 일, 그레고리력). 생일 · 처음 만난 날 · 알림 날짜를 셀 때 쓴다 (빌드 18).
///
/// 날짜 칸은 그날 12:00 UTC 로 저장한다(`DayNormalizer`) — 부르는 쪽이 그 연 · 월 · 일을 읽어 여기로 넘기면,
/// 여기서는 시간대 · 서머타임 없이 달력만으로 센다. 파이썬 정답표는 `datetime.date` 로 같은 셈을 한다.
public struct CivilDate: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (l: CivilDate, r: CivilDate) -> Bool {
        (l.year, l.month, l.day) < (r.year, r.month, r.day)
    }

    public static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// 그 해의 월 · 일 — 2월 29일은 평년이면 2월 28일로.
    public static func clamped(year: Int, month: Int, day: Int) -> CivilDate {
        CivilDate(year: year, month: month, day: min(day, daysIn(month: month, year: year)))
    }
    // … (addingMonths · nextOccurrence · dayNumber 등 — 날짜 입력에는 필요 없다)
}
```

#### `App/Persistence/DateConvention.swift`

```swift
import Core
import Foundation
import SwiftData

/// **날짜 칸을 UTC 정오로 한 번 옮긴다** (전수조사 이슈 20 · 빌드 13).
///
/// 빌드 12 까지 기록 날짜 · 처음 만난 날은 **기기 시간대의 정오**로 저장했다. 이제는 그 날의 **12:00 UTC** 다
/// (`Core.DayNormalizer.noon`). 이미 저장된 값은 앱을 처음 켤 때 한 번 옮긴다 — 저장된 순간을 지금 기기 시간대의
/// 달력으로 읽어 연 · 월 · 일을 얻고, 그 날의 12:00 UTC 로 바꾼다.
///
/// **두 번 돌아도 그대로다.** 이미 12:00 UTC 인 값은 UTC−11 ~ UTC+11 어디서 읽어도 같은 날(12:00 ± 11시간 =
/// 01:00 ~ 23:00)이라 같은 12:00 UTC 로 돌아온다. 옛 값(적은 곳의 정오)도 그 기기 시간대에서는 같은 날 정오라 날이
/// 바뀌지 않는다 — 여행 중에 처음 켜면 그곳 기준이지만, 그 경우도 ±12시간 안이면 같은 날이다.
/// 깃발(`UserDefaults`)은 진짜 저장소를 옮긴 뒤에만 세운다 — 실패하면 되돌리고 다음에 켤 때 다시 한다.
@MainActor
enum DateConvention {
    static let flagKey = "dates.utcNoon.v1"

    /// 옮겼으면 true. 이미 옮겼거나(깃발) 실패하면 false.
    @discardableResult
    static func migrateIfNeeded(_ context: ModelContext, defaults: UserDefaults = .standard,
                                calendar: Calendar = .current) -> Bool {
        guard !defaults.bool(forKey: flagKey) else { return false }
        do {
            for record in try context.fetch(FetchDescriptor<Record>()) {
                let moved = DayNormalizer.noon(of: record.occurredAt, calendar: calendar)
                if moved != record.occurredAt { record.occurredAt = moved }
            }
            for person in try context.fetch(FetchDescriptor<Person>()) {
                guard let met = person.firstMetDate else { continue }
                let moved = DayNormalizer.noon(of: met, calendar: calendar)
                if moved != met { person.firstMetDate = moved }
            }
            if context.hasChanges { try context.save() }
            defaults.set(true, forKey: flagKey)
            return true
        } catch {
            context.rollback()
            print("⚠️ 날짜 칸을 UTC 정오로 옮기지 못했습니다 — 다음에 켤 때 다시 합니다: \(error)")
            return false
        }
    }
}
```

#### 글꼴 (`App/DesignSystem/Typography.swift` 의 두 함수)

```swift
extension Font {
    /// 글자 크기 설정을 따르는 서체 — 설계 크기에 사용자 배율을 곱한다(AX5 까지).
    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight)
    }

    static func scaledLength(_ length: CGFloat) -> CGFloat {
        UIFontMetrics.default.scaledValue(for: length)
    }
}
```

#### 화면 시험 (`UITests/NavigationUITests.swift` 의 한 함수)

```swift
    func testDayCalendarClosesOnlyOnDay() {
        let app = launch(["-openPerson", "김하늘", "-addRecord"])
        XCTAssertTrue(app.navigationBars["기록 추가"].waitForExistence(timeout: 20), "기록 추가 창이 열리지 않았다\n\(screen(app))")
        let chip = app.buttons["dateChip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "날짜 칩이 보이지 않는다\n\(screen(app))")
        // 칩은 줄 오른쪽 끝에 있다. 찾은 요소가 줄 전체로 잡히면 가운데(빈 곳)를 눌러 달력이 뜨지 않는다(CI 136) —
        // 칩이든 줄이든 칩 위에 떨어지는 오른쪽 자리를 누른다.
        let chipSpot = chip.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        chipSpot.tap()
        // 달력이 떴는지부터 가른다 — 날 칸(`2026년 11월 5일`)이 보이면 떴다. 안 보이면 칩을 한 번 더 누른다(첫 누름이 초점만 옮겼을 때).
        // 칩 자신의 글도 `…일` 로 끝나 칩은 뺀다 — CI 132 · 134 는 칩을 날 칸으로 잘못 보고 다시 누르지 않았다.
        let anyDay = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND identifier != %@", "일", "dateChip")).firstMatch
        if !anyDay.waitForExistence(timeout: 5) {
            chipSpot.tap()
        }
        XCTAssertTrue(anyDay.waitForExistence(timeout: 10),
                      "날짜 칩을 눌러도 달력이 뜨지 않는다 — 칩 \(chip.frame)\n\(buttons(app))\n\(screen(app))")
        let title = app.buttons["calendarTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "달력은 떴는데 제목 단추(calendarTitle)를 못 찾는다\n\(buttons(app))\n\(screen(app))")
        // 단계마다 화면이 바뀐 것을 본 뒤에 누른다 — 바뀌는 동안 누르면 사라지던 칸(달)이 눌려 날로 돌아간다(CI 137).
        let thisYear = Calendar.current.component(.year, from: Date())
        title.tap()
        let monthCell = app.buttons["\(thisYear)년 1월"].firstMatch
        XCTAssertTrue(monthCell.waitForExistence(timeout: 5), "제목을 눌러도 열두 달이 아니다\n\(buttons(app))")
        app.buttons["calendarTitle"].firstMatch.tap()
        XCTAssertTrue(monthCell.waitForNonExistence(timeout: 5), "열두 달 제목을 눌러도 열두 해가 아니다\n\(buttons(app))")
        let year = app.buttons["2025년"].firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: 5), "열두 해에 2025년이 없다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        year.tap()
        let march = app.buttons["2025년 3월"].firstMatch
        XCTAssertTrue(march.waitForExistence(timeout: 5), "해를 고르자 닫혔다 — 열두 달이 보여야 한다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        march.tap()
        let day = app.buttons["2025년 3월 15일"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "달을 고르자 닫혔다 — 그달의 날이 보여야 한다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        day.tap()
        XCTAssertTrue(app.buttons["calendarTitle"].waitForNonExistence(timeout: 5), "날을 눌러도 닫히지 않았다\n\(buttons(app))")
        XCTAssertTrue(chip.label.contains("2025") && chip.label.contains("15"), "칩이 고른 날이 아니다: \(chip.label)\n\(screen(app))")
    }
```
