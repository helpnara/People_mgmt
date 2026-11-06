import Foundation

/// **기간 · 장소로 찾기** (1.1.9 · 이슈 97 · FR-072 · D-79 · 2026-11-06 사용자) — 홈 검색 아래 칩.
///
/// 날은 `CivilDate.dayNumber`(달력의 날 번호). 기간 · 장소 · 글자를 모두 만족하는 기록만.
/// - 기간: 지난 7일 · 지난 30일(오늘 포함) · 올해 · 지난해(1월 1일 ~ 12월 31일 · 올해는 앞날짜 예정도 든다).
/// - 장소: 기록 장소에 고른 장소 글자가 들어 있으면(대소문자 · 발음 구별 기호 무시).
/// - 글자: 띄어 쓴 낱말이 **모두** 제목 · 메모 · 장소 · 태그 어딘가에 있으면. 비면 거르지 않는다.
/// 파이썬 정답표(`recordFinder`)와 같은 셈이다.
public enum RecordPeriod: String, CaseIterable, Sendable, Identifiable {
    case week
    case month
    case thisYear
    case lastYear

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .week: return "지난 7일"
        case .month: return "지난 30일"
        case .thisYear: return "올해"
        case .lastYear: return "지난해"
        }
    }
}

public enum RecordFinder {
    public struct Item: Sendable {
        public let day: Int
        public let location: String?
        public let title: String?
        public let note: String?
        public let tags: [String]
        public init(day: Int, location: String?, title: String?, note: String?, tags: [String]) {
            self.day = day
            self.location = location
            self.title = title
            self.note = note
            self.tags = tags
        }
    }

    public static func range(_ period: RecordPeriod, today: CivilDate) -> ClosedRange<Int> {
        switch period {
        case .week: return (today.dayNumber - 6)...today.dayNumber
        case .month: return (today.dayNumber - 29)...today.dayNumber
        case .thisYear:
            return CivilDate(year: today.year, month: 1, day: 1).dayNumber...CivilDate(year: today.year, month: 12, day: 31).dayNumber
        case .lastYear:
            return CivilDate(year: today.year - 1, month: 1, day: 1).dayNumber...CivilDate(year: today.year - 1, month: 12, day: 31).dayNumber
        }
    }

    public static func matches(_ item: Item, range: ClosedRange<Int>?, place: String?, query: String) -> Bool {
        if let range, !range.contains(item.day) { return false }
        let wantedPlace = TextNormalization.folded(TextNormalization.collapsedSpaces(TextNormalization.normalized(place ?? "")))
        if !wantedPlace.isEmpty {
            guard let location = item.location,
                  TextNormalization.folded(TextNormalization.collapsedSpaces(location)).contains(wantedPlace) else { return false }
        }
        let words = TextNormalization.collapsedSpaces(TextNormalization.normalized(query)).split(separator: " ").map {
            TextNormalization.folded(String($0))
        }
        guard !words.isEmpty else { return true }
        let haystack = TextNormalization.folded(([item.title, item.note, item.location].compactMap { $0 } + item.tags).joined(separator: "\n"))
        return words.allSatisfy { haystack.contains($0) }
    }
}

/// **자주 쓴 장소** (1.1.9 · FR-072) — 검색 아래 장소 칩. 빈칸을 정리해 같은 장소끼리(대소문자 · 발음 구별 기호 무시) 세고,
/// 많이 쓴 차례 · 같으면 먼저 나온 차례로 `limit` 개. 이름은 처음 나온 모양 그대로. 부르는 쪽은 최근 기록부터 넘긴다.
/// 파이썬 정답표(`placeCatalog`)와 같은 셈이다.
public enum PlaceCatalog {
    public static let limit = 6

    public static func top(_ locations: [String?], limit: Int = limit) -> [String] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var shown: [String: String] = [:]
        for raw in locations {
            let clean = TextNormalization.collapsedSpaces(TextNormalization.normalized(raw ?? ""))
            guard !clean.isEmpty else { continue }
            let key = TextNormalization.folded(clean)
            if counts[key] == nil {
                order.append(key)
                shown[key] = clean
            }
            counts[key, default: 0] += 1
        }
        let first = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { a, _ in a })
        return order.sorted {
            let l = counts[$0] ?? 0, r = counts[$1] ?? 0
            return l != r ? l > r : (first[$0] ?? 0) < (first[$1] ?? 0)
        }
        .prefix(limit)
        .compactMap { shown[$0] }
    }
}
