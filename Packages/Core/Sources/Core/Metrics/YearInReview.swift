import Foundation

/// **한 해 돌아보기** (FR-059 · D-67 · 2026-11-03 사용자) — 내 인맥 → 돌아보기의 `2026년 돌아보기`.
///
/// 나 단위 집계만 둔다 — 사람 이름을 기록 수로 줄 세우는 순위는 두지 않는다(ADR-0004 · 조사 보고서 102행).
/// - 기록 · 함께한 사람: 그해 기록(오늘까지)의 수와 그 기록에 함께한 사람 수.
/// - 처음 만난 사람: 처음 만난 날이 그해인 사람 — 만난 날 차례(이름 순위가 아니다).
/// - 사람의 흐름: 그해 함께한 사람 중 **새로**(그해 처음 기록) · **다시**(그 앞 해에도 기록), 작년엔 있고 그해엔 없는 **쉬어 간** 사람.
///   빌드 52 까지는 수만 보였다 → **누르면 명단**(이슈 78 · D-72 · 2026-11-04 사용자). 명단은 **날짜 차례**다 — 기록 수로 줄 세우지 않는다:
///   함께한 사람은 이름 순, 새로는 그해 처음 함께한 날이 이른 사람부터, 다시는 그해 마지막으로 함께한 날이 최근인 사람부터,
///   쉬어 간 사람은 앞 해 마지막으로 함께한 날이 오래된 사람부터. 같으면 이름 열쇠 · 사람 id 순.
///   사람마다 그 날을 정한 기록(`Entry.record`)을 함께 준다 — 화면은 그 기록의 날짜를 정밀도대로 적는다.
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

    /// 명단의 한 사람 — 그 사람의 날을 정한 기록과 그 날.
    /// 처음(새로)은 날이 가장 이른 기록, 마지막(함께한 · 다시 · 쉬어 간)은 날이 가장 늦은 기록이다. 같은 날이면 기록 id 가 작은 것.
    public struct Entry: Sendable, Equatable {
        public let id: UUID
        public let record: UUID
        public let day: Int
        public init(id: UUID, record: UUID, day: Int) {
            self.id = id
            self.record = record
            self.day = day
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
        /// 1월 ~ 12월 기록 — 날이 이른 것부터, 같은 날이면 기록 id 순. 막대를 누르면 그달 기록을 아래에 보인다(이슈 79 · 2026-11-04 사용자).
        public let monthRecords: [[UUID]]
        /// 연도만 아는 기록 수(달 막대에 들지 않는다).
        public let unknownMonth: Int
        /// 기록이 가장 많은 달(같으면 이른 달). 기록이 없으면 nil.
        public let busiestMonth: Int?
        /// 기록 유형마다 수 — 많은 것부터, 같으면 유형 키 순.
        public let types: [TypeCount]
        /// 그해 함께한 사람 — 이름 순 · 그해 마지막으로 함께한 기록.
        public let together: [Entry]
        /// 새로 함께한 사람 — 그해 처음 함께한 날이 이른 사람부터.
        public let freshPeople: [Entry]
        /// 다시 함께한 사람 — 그해 마지막으로 함께한 날이 최근인 사람부터.
        public let returningPeople: [Entry]
        /// 쉬어 간 사람 — 앞 해 마지막으로 함께한 날이 오래된 사람부터.
        public let restingPeople: [Entry]

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

        // 사람마다 처음 · 마지막 기록 — 같은 날이면 기록 id 가 작은 것.
        func earliest(_ records: [Record]) -> [UUID: Entry] {
            var out: [UUID: Entry] = [:]
            for record in records {
                for id in record.participants {
                    if let held = out[id], (held.day, held.record.uuidString) <= (record.day, record.id.uuidString) { continue }
                    out[id] = Entry(id: id, record: record.id, day: record.day)
                }
            }
            return out
        }
        func latest(_ records: [Record]) -> [UUID: Entry] {
            var out: [UUID: Entry] = [:]
            for record in records {
                for id in record.participants {
                    if let held = out[id], held.day > record.day || (held.day == record.day && held.record.uuidString <= record.id.uuidString) {
                        continue
                    }
                    out[id] = Entry(id: id, record: record.id, day: record.day)
                }
            }
            return out
        }
        var sortKeys: [UUID: String] = [:]
        for person in people where sortKeys[person.id] == nil { sortKeys[person.id] = person.sortKey }
        func key(_ entry: Entry) -> String { sortKeys[entry.id] ?? "" }
        let firstIn = earliest(inYear)
        let lastIn = latest(inYear)
        let lastBefore = latest(previous)

        let together = met.compactMap { lastIn[$0] }
            .sorted { (key($0), $0.id.uuidString) < (key($1), $1.id.uuidString) }
        let freshPeople = met.filter { firstYear[$0] == year }.compactMap { firstIn[$0] }
            .sorted { ($0.day, key($0), $0.id.uuidString) < ($1.day, key($1), $1.id.uuidString) }
        let returningPeople = met.filter { firstYear[$0] != year }.compactMap { lastIn[$0] }
            .sorted { (-$0.day, key($0), $0.id.uuidString) < (-$1.day, key($1), $1.id.uuidString) }
        let restingPeople = metBefore.subtracting(met).compactMap { lastBefore[$0] }
            .sorted { ($0.day, key($0), $0.id.uuidString) < ($1.day, key($1), $1.id.uuidString) }

        let newlyMet = people
            .filter { $0.firstMetYear == year && ($0.firstMetDay ?? Int.min) <= today }
            .sorted {
                ($0.firstMetDay ?? Int.max, $0.sortKey, $0.id.uuidString) < ($1.firstMetDay ?? Int.max, $1.sortKey, $1.id.uuidString)
            }
            .map(\.id)

        var monthly = Array(repeating: 0, count: 12)
        var monthRecords: [[Record]] = Array(repeating: [], count: 12)
        var unknownMonth = 0
        var typeCounts: [String: Int] = [:]
        for record in inYear {
            if let month = record.month, (1...12).contains(month) {
                monthly[month - 1] += 1
                monthRecords[month - 1].append(record)
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
                       peopleCount: met.count, newlyMet: newlyMet, fresh: freshPeople.count, returning: returningPeople.count,
                       resting: restingPeople.count, monthly: monthly,
                       monthRecords: monthRecords.map { month in
                           month.sorted { ($0.day, $0.id.uuidString) < ($1.day, $1.id.uuidString) }.map(\.id)
                       },
                       unknownMonth: unknownMonth,
                       busiestMonth: busiest, types: types, together: together, freshPeople: freshPeople,
                       returningPeople: returningPeople, restingPeople: restingPeople)
    }
}
