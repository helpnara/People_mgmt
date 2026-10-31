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
