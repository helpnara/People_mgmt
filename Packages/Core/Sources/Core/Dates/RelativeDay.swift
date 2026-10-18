import Foundation

/// 날짜만 뜻이 있는 칸을 **달력의 날 수**로 말한다 (이슈 7 · FR-040).
///
/// 기록 날짜는 그날 정오로 저장한다. 그것을 지금 시각과의 차이(상대 시간)로 말하면 오전에 오늘 기록이
/// `3시간 후` 가 된다. 그래서 시각은 버리고 두 날의 차이만 센다 — 오늘 · 어제 · N일 · N주 · N개월 · N년.
/// 개월 · 년은 30일 · 365일로 어림한다 (달마다 길이가 달라 생기는 경계 차이를 정답표와 맞추려고).
public enum RelativeDay {

    /// `from` 이 `to` 보다 며칠 앞인가. 같은 날이면 0, `from` 이 미래면 음수.
    public static func days(from: Date, to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// 예: `오늘` · `어제` · `내일` · `5일 전` · `3주 전` · `2개월 전` · `1년 전` · `4일 후`.
    public static func phrase(from: Date, to: Date, calendar: Calendar) -> String {
        phrase(days: days(from: from, to: to, calendar: calendar))
    }

    public static func phrase(days: Int) -> String {
        switch days {
        case 0: return "오늘"
        case 1: return "어제"
        case -1: return "내일"
        default: break
        }
        let n = abs(days)
        let suffix = days > 0 ? "전" : "후"
        if n < 7 { return "\(n)일 \(suffix)" }
        if n < 30 { return "\(n / 7)주 \(suffix)" }
        if n < 365 { return "\(n / 30)개월 \(suffix)" }
        return "\(n / 365)년 \(suffix)"
    }
}
