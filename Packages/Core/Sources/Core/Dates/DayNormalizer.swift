import Foundation

/// 날짜만 뜻이 있는 칸(처음 만난 날짜 · 기록 날짜)을 **그날 정오**로 맞춘다 (요구사항 7.3).
///
/// 자정으로 두면 시간대가 바뀌는 순간 하루가 밀린다 — 서울에서 적은 3월 8일이
/// 뉴욕에서 3월 7일로 보인다. 정오는 어느 시간대에서 봐도 같은 날이다.
public enum DayNormalizer {

    public static func noon(of date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date).addingTimeInterval(12 * 60 * 60)
    }

    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
