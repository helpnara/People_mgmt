import Foundation

/// **반복 약속** (1.1.9 · 이슈 94 · FR-069 · D-79 · 2026-11-06 사용자) — 날짜까지 정한 기록의 반복 규칙.
///
/// 다음 회차 **하나만** 만든다(미래 예정이 쌓이지 않게). 이 셈은 그 다음 날짜만 정한다 — 언제 만들지는 부르는 쪽이 본다.
/// - 매주 · 2주마다 — 7 · 14일 뒤.
/// - 매달 같은 날 — 다음 달의 그날. 그달에 없으면 그달 마지막 날. `anchorDay`(처음 정한 날)를 주면 그 날로 되돌아온다
///   (1월 31일 → 2월 28일 → 3월 31일).
/// - 매달 같은 주 요일 — 그 날이 그달의 몇째 그 요일인지(1 ~ 5)를 다음 달에 그대로. 다섯째는 다음 달의 **마지막** 그 요일.
/// 파이썬 정답표(`repeatRule`)와 같은 셈이다.
public enum RepeatRule: Int, CaseIterable, Sendable, Identifiable {
    case none = 0
    case weekly = 1
    case biweekly = 2
    case monthlyDay = 3
    case monthlyWeekday = 4

    public var id: Int { rawValue }

    /// 저장된 수에서 — 모르는 수는 반복 안 함.
    public static func of(_ raw: Int) -> RepeatRule { RepeatRule(rawValue: raw) ?? .none }

    static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
    static let ordinalNames = ["첫째", "둘째", "셋째", "넷째"]

    /// 그 날이 그달의 몇째 그 요일인가 (1 ~ 5).
    public static func ordinal(of date: CivilDate) -> Int { (date.day - 1) / 7 + 1 }

    /// 고르는 칸 · 상세에 보이는 말 — 그 날에 맞춰 `매주 화요일` · `매달 둘째 화요일` · `매달 31일`.
    public static func describe(_ rule: RepeatRule, on date: CivilDate, anchorDay: Int? = nil) -> String {
        let weekday = weekdayNames[date.weekday] + "요일"
        switch rule {
        case .none: return "반복 안 함"
        case .weekly: return "매주 " + weekday
        case .biweekly: return "2주마다 " + weekday
        case .monthlyDay: return "매달 \(anchorDay ?? date.day)일"
        case .monthlyWeekday:
            let n = ordinal(of: date)
            return "매달 " + (n >= 5 ? "마지막" : ordinalNames[n - 1]) + " " + weekday
        }
    }

    /// 이 회차의 다음 회차를 만들 때인가 — 그날이 지났거나(오늘보다 앞), 그날이 왔고 그날 이후 고쳤으면(결과를 적음 ·
    /// `그대로 만났어요`). 날은 모두 같은 날 번호.
    public static func isDue(day: Int, updatedDay: Int, today: Int) -> Bool {
        day < today || (day <= today && updatedDay >= day)
    }

    /// 오늘보다 뒤의 첫 회차 — 여러 회차를 건너뛰었으면(앱을 오래 안 열었으면) 지난 회차는 만들지 않고 오늘 뒤로 넘긴다.
    /// 반복 안 함이면 nil.
    public func nextUpcoming(after date: CivilDate, anchorDay: Int? = nil, today: CivilDate) -> CivilDate? {
        guard var next = self.next(after: date, anchorDay: anchorDay) else { return nil }
        var guardCount = 0
        while next.dayNumber <= today.dayNumber && guardCount < 2_000 {
            guard let later = self.next(after: next, anchorDay: anchorDay) else { return nil }
            next = later
            guardCount += 1
        }
        return next
    }

    /// 다음 회차의 날. 반복 안 함이면 nil.
    public func next(after date: CivilDate, anchorDay: Int? = nil) -> CivilDate? {
        switch self {
        case .none:
            return nil
        case .weekly:
            return CivilDate(dayNumber: date.dayNumber + 7)
        case .biweekly:
            return CivilDate(dayNumber: date.dayNumber + 14)
        case .monthlyDay:
            let month = date.addingMonths(1)
            return CivilDate.clamped(year: month.year, month: month.month, day: anchorDay ?? date.day)
        case .monthlyWeekday:
            let month = date.addingMonths(1)
            let weekday = date.weekday
            let first = CivilDate(year: month.year, month: month.month, day: 1)
            let firstMatch = 1 + (weekday - first.weekday + 7) % 7
            let n = RepeatRule.ordinal(of: date)
            if n >= 5 {
                let days = CivilDate.daysIn(month: month.month, year: month.year)
                var day = firstMatch
                while day + 7 <= days { day += 7 }
                return CivilDate(year: month.year, month: month.month, day: day)
            }
            return CivilDate(year: month.year, month: month.month, day: firstMatch + (n - 1) * 7)
        }
    }
}

extension CivilDate {
    /// 1970-01-01 부터의 날 수에서 (Howard Hinnant 의 civil_from_days) — `dayNumber` 의 거꾸로.
    public init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        let year = yoe + era * 400 + (month <= 2 ? 1 : 0)
        self.init(year: year, month: month, day: day)
    }

    /// 요일 — 0 일요일 ~ 6 토요일 (1970-01-01 은 목요일).
    public var weekday: Int { ((dayNumber % 7) + 7 + 4) % 7 }
}
