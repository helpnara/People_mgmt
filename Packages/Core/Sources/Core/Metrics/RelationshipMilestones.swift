import Foundation

/// **인연 연표** (빌드 41 · 1.1 · FR-056 · 2026-11-02 사용자) — 사람 상세 맨 위의 마일스톤 선.
///
/// 이 사람과 쌓은 시간을 한눈에 — 처음 만남 · 첫 기록 · n번째 기록 · 가장 많이 만난 해 · 마지막 기록 · 다가오는 만남.
/// 점수 · 순위가 아니다(ADR-0004). 기록에서 센 사실만 표식으로 둔다.
///
/// - **처음 만남**: 처음 만난 날을 적었으면.
/// - **첫 기록**: 오늘까지의 가장 이른 기록. 처음 만난 날과 같은 날이면 빼고 처음 만남 하나로.
/// - **n번째 기록**: 오늘까지의 기록이 10 · 50 · 100 · 200 · 500 · 1000건에 닿은 그 기록.
/// - **가장 많이 만난 해**: 오늘까지의 기록이 3건 이상이고 두 해 이상에 걸쳐 있을 때. 같으면 늦은 해. 그해 마지막 기록 날에 선다.
/// - **마지막 기록**: 오늘까지의 기록이 2건 이상일 때 가장 늦은 기록.
/// - **다가오는 만남**: 오늘보다 뒤의 가장 이른 기록.
///
/// 차례는 날 → 종류(위 차례) → 만든 순서. 날은 날 번호(`DayIndex`), 해는 부르는 쪽이 기기 달력으로 센 연도다.
/// 파이썬 정답표(`Tools/golden` 의 `milestones`)와 같은 셈이다.
public enum RelationshipMilestones {
    public static let countThresholds = [10, 50, 100, 200, 500, 1000]
    public static let busiestMinimum = 3

    public enum Kind: String, Sendable, CaseIterable {
        case firstMet, firstRecord, countReached, busiestYear, lastRecord, upcoming

        var order: Int { Kind.allCases.firstIndex(of: self) ?? 0 }
    }

    public struct Record: Sendable, Equatable {
        public let id: UUID
        public let day: Int
        public let year: Int
        public init(id: UUID, day: Int, year: Int) {
            self.id = id
            self.day = day
            self.year = year
        }
    }

    public struct Milestone: Sendable, Equatable, Identifiable {
        public let kind: Kind
        public let day: Int
        public let year: Int
        /// n번째 기록의 n · 가장 많이 만난 해의 기록 수.
        public let count: Int?
        /// 표식이 가리키는 기록(처음 만남 · 가장 많이 만난 해는 없다).
        public let recordID: UUID?

        public var id: String { "\(kind.rawValue)-\(day)-\(count ?? 0)" }

        /// 표식 이름.
        public var title: String {
            switch kind {
            case .firstMet: return "처음 만남"
            case .firstRecord: return "첫 기록"
            case .countReached: return "\(count ?? 0)번째 기록"
            case .busiestYear: return "가장 많이 만난 해"
            case .lastRecord: return "마지막 기록"
            case .upcoming: return "다가오는 만남"
            }
        }
    }

    public static func make(records: [Record], firstMetDay: Int?, firstMetYear: Int?, today: Int) -> [Milestone] {
        let past = records.filter { $0.day <= today }.sorted { ($0.day, $0.id.uuidString) < ($1.day, $1.id.uuidString) }
        let future = records.filter { $0.day > today }.sorted { ($0.day, $0.id.uuidString) < ($1.day, $1.id.uuidString) }
        var out: [Milestone] = []

        if let firstMetDay {
            out.append(Milestone(kind: .firstMet, day: firstMetDay, year: firstMetYear ?? 0, count: nil, recordID: nil))
        }
        if let first = past.first, first.day != firstMetDay {
            out.append(Milestone(kind: .firstRecord, day: first.day, year: first.year, count: nil, recordID: first.id))
        }
        for threshold in countThresholds where past.count >= threshold {
            let record = past[threshold - 1]
            out.append(Milestone(kind: .countReached, day: record.day, year: record.year, count: threshold, recordID: record.id))
        }
        let years = Dictionary(grouping: past, by: \.year)
        if past.count >= busiestMinimum, years.count >= 2,
           let best = years.max(by: { ($0.value.count, $0.key) < ($1.value.count, $1.key) }),
           let lastInYear = best.value.map(\.day).max() {
            out.append(Milestone(kind: .busiestYear, day: lastInYear, year: best.key, count: best.value.count, recordID: nil))
        }
        if past.count >= 2, let last = past.last {
            out.append(Milestone(kind: .lastRecord, day: last.day, year: last.year, count: nil, recordID: last.id))
        }
        if let next = future.first {
            out.append(Milestone(kind: .upcoming, day: next.day, year: next.year, count: nil, recordID: next.id))
        }
        return out.enumerated()
            .sorted { ($0.element.day, $0.element.kind.order, $0.offset) < ($1.element.day, $1.element.kind.order, $1.offset) }
            .map(\.element)
    }

    /// 연표 위 한 줄 — `2019년부터 · 인연 7년 2개월 · 기록 24건`. 시작은 처음 만난 날, 없으면 첫 기록. 아무것도 없으면 nil.
    public static func summary(records: [Record], firstMetDay: Int?, firstMetYear: Int?, today: Int) -> String? {
        let past = records.filter { $0.day <= today }
        let firstRecord = past.min { ($0.day, $0.id.uuidString) < ($1.day, $1.id.uuidString) }
        let start: (day: Int, year: Int)?
        if let firstMetDay, let firstMetYear {
            start = (firstMetDay, firstMetYear)
        } else if let firstRecord {
            start = (firstRecord.day, firstRecord.year)
        } else {
            start = nil
        }
        guard let start else { return nil }
        return "\(start.year)년부터 · 인연 \(MetricText.span(days: today - start.day)) · 기록 \(past.count)건"
    }
}
