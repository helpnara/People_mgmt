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
