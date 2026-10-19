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

    /// 몇 달 뒤 — 그 달에 없는 날이면 그 달 마지막 날 (1월 31일 + 1개월 = 2월 28 · 29일).
    public func addingMonths(_ months: Int) -> CivilDate {
        let index = year * 12 + (month - 1) + months
        let y = Int((Double(index) / 12).rounded(.down))
        let m = index - y * 12 + 1
        return CivilDate.clamped(year: y, month: m, day: day)
    }

    /// 이 날 또는 그 뒤로 처음 오는 월 · 일.
    public func nextOccurrence(month: Int, day: Int) -> CivilDate {
        let thisYear = CivilDate.clamped(year: year, month: month, day: day)
        return thisYear < self ? CivilDate.clamped(year: year + 1, month: month, day: day) : thisYear
    }

    /// 1970-01-01 부터의 날 수 (Howard Hinnant 의 days_from_civil) — 두 날의 차이를 셀 때.
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}

/// **생일** (빌드 18 · D-40) — 월 · 일은 있어야 하고 연도는 선택.
public enum BirthdayRule {
    /// 그 월에 있는 날인가. 연도를 모르면 2월 29일을 받는다(윤년생일 수 있다).
    public static func isValid(month: Int, day: Int, year: Int?) -> Bool {
        guard (1...12).contains(month), day >= 1 else { return false }
        let limit = year.map { CivilDate.daysIn(month: month, year: $0) } ?? (month == 2 ? 29 : CivilDate.daysIn(month: month, year: 2001))
        return day <= limit
    }

    /// `3월 14일` · `1990년 3월 14일`.
    public static func text(month: Int, day: Int, year: Int?) -> String {
        let monthDay = "\(month)월 \(day)일"
        return year.map { "\($0)년 " + monthDay } ?? monthDay
    }
}
