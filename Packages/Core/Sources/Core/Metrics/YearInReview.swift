import Foundation

/// **한 해 돌아보기** (FR-059 · D-67 · 2026-11-03 사용자) — 내 인맥 → 돌아보기의 `2026년 돌아보기`.
///
/// 나 단위 집계만 둔다 — 사람 이름을 기록 수로 줄 세우는 순위는 두지 않는다(ADR-0004 · 조사 보고서 102행).
/// - 기록 · 함께한 사람: 그해 기록(오늘까지)의 수와 그 기록에 함께한 사람 수.
/// - 처음 만난 사람: 처음 만난 날이 그해인 사람 — 만난 날 차례(이름 순위가 아니다).
/// - 사람의 흐름: 그해 함께한 사람 중 **새로**(그해 처음 기록) · **다시**(그 앞 해에도 기록), 작년엔 있고 그해엔 없는 **쉬어 간** 사람 수
///   (조사 보고서 나중 18 — 수만, 이름 없이).
/// - 달마다 기록 수 · 기록 유형 나눔 · 작년 기록 수.
///
/// 날은 날 번호(`DayIndex`), 해 · 달은 부르는 쪽이 기기 달력으로 센다. 연도만 아는 기록은 달을 모른다(`month` nil).
/// 파이썬 정답표(`Tools/golden` 의 `yearInReview`)와 같은 셈이다.
public enum YearInReview {
    public struct Record: Sendable, Equatable {
        public let id: UUID
        public let day: Int
        public let year: Int
        /// 1 ~ 12. 연도만 아는 기록은 nil.
        public let month: Int?
        public let type: String
        /// 함께한 사람(나는 빼고).
        public let participants: [UUID]
        public init(id: UUID, day: Int, year: Int, month: Int?, type: String, participants: [UUID]) {
            self.id = id
            self.day = day
            self.year = year
            self.month = month
            self.type = type
            self.participants = participants
        }
    }

    public struct Person: Sendable, Equatable {
        public let id: UUID
        public let firstMetDay: Int?
        public let firstMetYear: Int?
        /// 같은 날 만난 사람끼리의 차례 — 부르는 쪽이 `NameSort.key` 로 만든다.
        public let sortKey: String
        public init(id: UUID, firstMetDay: Int?, firstMetYear: Int?, sortKey: String) {
            self.id = id
            self.firstMetDay = firstMetDay
            self.firstMetYear = firstMetYear
            self.sortKey = sortKey
        }
    }

    public struct TypeCount: Sendable, Equatable {
        public let type: String
        public let count: Int
    }

    public struct Summary: Sendable, Equatable {
        public let year: Int
        public let recordCount: Int
        public let previousRecordCount: Int
        public let peopleCount: Int
        /// 처음 만난 날이 그해인 사람 — 만난 날 · 이름 차례.
        public let newlyMet: [UUID]
        /// 그해 함께한 사람 중 그해 처음 기록한 사람 수.
        public let fresh: Int
        /// 그해 함께한 사람 중 그 앞 해에도 기록이 있던 사람 수.
        public let returning: Int
        /// 작년엔 함께했는데 그해엔 기록이 없는 사람 수.
        public let resting: Int
        /// 1월 ~ 12월 기록 수.
        public let monthly: [Int]
        /// 연도만 아는 기록 수(달 막대에 들지 않는다).
        public let unknownMonth: Int
        /// 기록이 가장 많은 달(같으면 이른 달). 기록이 없으면 nil.
        public let busiestMonth: Int?
        /// 기록 유형마다 수 — 많은 것부터, 같으면 유형 키 순.
        public let types: [TypeCount]

        public var isEmpty: Bool { recordCount == 0 && newlyMet.isEmpty }
    }

    /// 고를 수 있는 해 — 오늘까지의 기록 · 처음 만난 날이 있는 해와 올해, 이른 해부터. 올해보다 뒤는 없다.
    public static func years(records: [Record], people: [Person], today: Int, currentYear: Int) -> [Int] {
        var years: Set<Int> = [currentYear]
        for record in records where record.day <= today && record.year <= currentYear { years.insert(record.year) }
        for person in people {
            guard let year = person.firstMetYear, let day = person.firstMetDay, day <= today, year <= currentYear else { continue }
            years.insert(year)
        }
        return years.sorted()
    }

    public static func make(year: Int, records: [Record], people: [Person], today: Int) -> Summary {
        let past = records.filter { $0.day <= today }
        let inYear = past.filter { $0.year == year }
        let previous = past.filter { $0.year == year - 1 }

        var firstYear: [UUID: Int] = [:]
        for record in past {
            for id in record.participants {
                firstYear[id] = min(firstYear[id] ?? record.year, record.year)
            }
        }
        let met = Set(inYear.flatMap(\.participants))
        let metBefore = Set(previous.flatMap(\.participants))
        let fresh = met.filter { firstYear[$0] == year }.count

        let newlyMet = people
            .filter { $0.firstMetYear == year && ($0.firstMetDay ?? Int.min) <= today }
            .sorted {
                ($0.firstMetDay ?? Int.max, $0.sortKey, $0.id.uuidString) < ($1.firstMetDay ?? Int.max, $1.sortKey, $1.id.uuidString)
            }
            .map(\.id)

        var monthly = Array(repeating: 0, count: 12)
        var unknownMonth = 0
        var typeCounts: [String: Int] = [:]
        for record in inYear {
            if let month = record.month, (1...12).contains(month) {
                monthly[month - 1] += 1
            } else {
                unknownMonth += 1
            }
            typeCounts[record.type, default: 0] += 1
        }
        let top = monthly.max() ?? 0
        let busiest = top > 0 ? (monthly.firstIndex(of: top).map { $0 + 1 }) : nil
        let types = typeCounts
            .map { TypeCount(type: $0.key, count: $0.value) }
            .sorted { ($1.count, $0.type) < ($0.count, $1.type) }

        return Summary(year: year, recordCount: inYear.count, previousRecordCount: previous.count,
                       peopleCount: met.count, newlyMet: newlyMet, fresh: fresh, returning: met.count - fresh,
                       resting: metBefore.subtracting(met).count, monthly: monthly, unknownMonth: unknownMonth,
                       busiestMonth: busiest, types: types)
    }
}
