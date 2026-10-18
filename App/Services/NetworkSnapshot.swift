import Core
import Foundation
import SwiftData

/// 날 번호 — 지표는 날 수로만 센다 (Core `MetricRecord`). 기준일은 2001-01-01, 사용자 달력의 날로 센다.
enum DayIndex {
    static let reference = Date(timeIntervalSinceReferenceDate: 0)

    static func of(_ date: Date, calendar: Calendar = .current) -> Int {
        RelativeDay.days(from: reference, to: date, calendar: calendar)
    }
}

/// **내 인맥** 화면이 그리는 값 (6번째 묶음 · FR-045 · 047 · 048). SwiftData 객체가 아니라 값이다 — 주 스레드 밖에서 만든다.
///
/// 나는 넣지 않는다. 관계도에서는 나를 맨 끝 자리(`people.count`)에 두고 가운데에 고정한다.
struct NetworkSnapshot: Sendable {
    struct PersonInfo: Sendable, Identifiable {
        let id: UUID
        let name: String
        let subtitle: String?
        let relationshipType: String?
        let metThrough: String?
        let organization: String?
        let tags: [String]
        let firstMetDay: Int?
        /// 오늘까지의 마지막 기록일.
        let lastDay: Int?
    }

    let people: [PersonInfo]
    let meName: String?
    let today: Int
    let yearStart: Int
    let yearEnd: Int
    let edges: [GraphEdge]
    /// `people` 과 같은 차례, 맨 끝 하나가 나.
    let positions: [GraphLayout.Point]

    var isEmpty: Bool { people.isEmpty }

    /// 이 날 번호가 오늘에서 며칠 전인가를 말로.
    func phrase(forDay day: Int) -> String { RelativeDay.phrase(days: today - day) }

    static let empty = NetworkSnapshot(people: [], meName: nil, today: 0, yearStart: 0, yearEnd: 0, edges: [], positions: [])
}

enum NetworkSnapshotBuilder {
    /// 저장소를 **따로 연 문맥**에서 읽어 값으로 바꾸고 관계도 자리까지 잡는다. 주 스레드를 막지 않는다 (이슈 8 · 10).
    static func build(container: ModelContainer, now: Date = Date()) async -> NetworkSnapshot {
        await Task.detached(priority: .userInitiated) {
            LaunchTiming.measure("인맥 자료 만들기") { make(container: container, now: now) }
        }.value
    }

    private static func make(container: ModelContainer, now: Date) -> NetworkSnapshot {
        let calendar = Calendar.current
        let context = ModelContext(container)
        let others = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? []
        let me = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == true })))?.first
        let records = (try? context.fetch(FetchDescriptor<Record>())) ?? []

        let today = DayIndex.of(now, calendar: calendar)
        let year = calendar.dateInterval(of: .year, for: now)
        let yearStart = year.map { DayIndex.of($0.start, calendar: calendar) } ?? today
        let yearEnd = year.map { DayIndex.of($0.end.addingTimeInterval(-1), calendar: calendar) } ?? today

        // 기록을 한 번만 돈다 — 사람마다 `records` 를 열면 5,000명에서 관계를 5,000번 읽는다.
        var lastDay: [UUID: Int] = [:]
        var participantLists: [[UUID]] = []
        participantLists.reserveCapacity(records.count)
        for record in records {
            let day = DayIndex.of(record.occurredAt, calendar: calendar)
            let ids = (record.participants ?? []).filter { !$0.isMe }.map(\.uuid)
            participantLists.append(ids)
            guard day <= today else { continue }
            for id in ids where (lastDay[id] ?? Int.min) < day { lastDay[id] = day }
        }

        let people = others.map { person in
            NetworkSnapshot.PersonInfo(
                id: person.uuid, name: person.name, subtitle: person.subtitle,
                relationshipType: person.relationshipType, metThrough: person.metThrough,
                organization: person.organization, tags: person.tags,
                firstMetDay: person.firstMetDate.map { DayIndex.of($0, calendar: calendar) },
                lastDay: lastDay[person.uuid])
        }
        let graphPeople = others.map {
            GraphPerson(id: $0.uuid, name: $0.name, organization: $0.organization, introducedBy: $0.introducedBy?.uuid)
        }
        let edges = RelationGraph.edges(people: graphPeople, records: participantLists)

        var index: [UUID: Int] = [:]
        for (i, person) in people.enumerated() { index[person.id] = i }
        let links = edges.compactMap { edge -> GraphLayout.Link? in
            guard let i = index[edge.a], let j = index[edge.b] else { return nil }
            // 진한 선은 함께한 기록이 많을수록 조금 더 당긴다(로그). 같은 소속만이면 약하게.
            let weight = edge.isStrong ? 1 + log(1 + Double(edge.together)) : 0.3
            return GraphLayout.Link(i: i, j: j, weight: weight)
        }
        let positions = GraphLayout.layout(nodeCount: people.count + 1, center: people.count, links: links)

        return NetworkSnapshot(people: people, meName: me?.name, today: today, yearStart: yearStart, yearEnd: yearEnd,
                               edges: edges, positions: positions)
    }
}
