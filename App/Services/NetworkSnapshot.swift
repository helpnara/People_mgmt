import Core
import Foundation
import SwiftData

/// 날 번호 — 지표는 날 수로만 센다 (Core `MetricRecord`). 2001-01-01 부터 사용자 시간대의 날로 센다.
///
/// **산수로 센다 (이슈 15).** 빌드 9 는 `Calendar.dateComponents` 로 기록마다 셌다 — 50,000건이면 무겁다.
/// 그 시각의 시간대 차이(서머타임 포함)를 더해 하루 길이로 나누면 같은 날 번호가 나온다. 지표는 날 번호의
/// **차이**만 쓰므로(오늘 − 그날), 같은 함수로 센 값끼리면 기준일이 하루 어긋나는 시간대에서도 답이 같다.
enum DayIndex {
    static func of(_ date: Date, calendar: Calendar = .current) -> Int {
        let seconds = date.timeIntervalSinceReferenceDate + Double(calendar.timeZone.secondsFromGMT(for: date))
        return Int((seconds / 86_400).rounded(.down))
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
        // 단계마다 시간을 찍는다 (이슈 15) — 어디가 무거운지 로그로 보고 고친다. 큰 견본에서만 찍힌다.
        var started = Date()
        func lap(_ label: String) {
            LaunchTiming.log("  인맥 · \(label)", since: started)
            started = Date()
        }

        // 관계를 미리 읽는다 — 사람마다 · 기록마다 따로 읽으면 5,000 · 50,000 번이다 (이슈 15).
        var peopleDescriptor = FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false })
        peopleDescriptor.relationshipKeyPathsForPrefetching = [\.introducedBy]
        let others = (try? context.fetch(peopleDescriptor)) ?? []
        let me = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == true })))?.first
        lap("사람 읽기 \(others.count)명")
        var recordDescriptor = FetchDescriptor<Record>()
        recordDescriptor.relationshipKeyPathsForPrefetching = [\.participants]
        let records = (try? context.fetch(recordDescriptor)) ?? []
        lap("기록 읽기 \(records.count)건")
        var tieDescriptor = FetchDescriptor<Tie>()
        tieDescriptor.relationshipKeyPathsForPrefetching = [\.first, \.second]
        let ties = ((try? context.fetch(tieDescriptor)) ?? []).compactMap { tie -> (UUID, UUID)? in
            guard let a = tie.first, let b = tie.second, !a.isMe, !b.isMe else { return nil }
            return (a.uuid, b.uuid)
        }
        lap("아는 사이 읽기 \(ties.count)줄")

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
        lap("기록 돌기 (참여자 · 날)")

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
        lap("사람 값 만들기")
        let edges = RelationGraph.edges(people: graphPeople, records: participantLists, ties: ties)
        lap("선 \(edges.count)개")

        var index: [UUID: Int] = [:]
        for (i, person) in people.enumerated() { index[person.id] = i }
        let links = edges.compactMap { edge -> GraphLayout.Link? in
            guard let i = index[edge.a], let j = index[edge.b] else { return nil }
            // 진한 선은 함께한 기록이 많을수록 조금 더 당긴다(로그). 같은 소속만이면 약하게.
            let weight = edge.isStrong ? 1 + log(1 + Double(edge.together)) : 0.3
            return GraphLayout.Link(i: i, j: j, weight: weight)
        }
        let positions = GraphLayout.layout(nodeCount: people.count + 1, center: people.count, links: links)
        lap("자리 잡기")

        return NetworkSnapshot(people: people, meName: me?.name, today: today, yearStart: yearStart, yearEnd: yearEnd,
                               edges: edges, positions: positions)
    }
}
