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

    /// 모임 하나 (D-30). 사람은 이름 순.
    struct Community: Sendable, Identifiable {
        let id: Int
        let name: String
        let memberIDs: [UUID]
        /// `people` 안의 자리 — 관계도가 테두리를 그린다.
        let memberIndices: [Int]
    }

    /// 모임을 보여 주는가, 아니면 왜 아닌가.
    enum CommunityStatus: Sendable {
        /// 진한 선 · 이어진 사람이 조건에 못 미친다.
        case notEnoughLinks
        /// 연결은 넉넉하지만 뚜렷하게 나뉘지 않는다 (모듈성 < 문턱, 또는 3명 이상 묶음이 없다).
        case noClearGroups
        case shown
    }

    /// 빈 칸이 있는 사람 · 기록 — **채울 것 목록** (D-31). 사람은 이름 순, 기록은 최근 것부터.
    struct Gaps: Sendable {
        var noRelationshipType: [UUID] = []
        var noMetThrough: [UUID] = []
        var noFirstMet: [UUID] = []
        var noRecord: [UUID] = []
        /// 진한 선이 하나도 없는 사람.
        var unlinked: [UUID] = []
        /// 나 말고 함께한 사람이 한 명뿐인 기록.
        var singleParticipantRecords: [UUID] = []
    }

    /// **지난 시점의 관계도** (D-32) — 분기 끝마다 창 12개월로 다시 센 진한 선 · 모임, 그리고 모임이 어떻게 변했나.
    /// 사람은 `people` 의 자리로 가리킨다. 자리(배치)는 화면이 시점을 고를 때 지금 자리에서 출발해 셈한다.
    struct Timeline: Sendable {
        struct Link: Sendable {
            let i: Int
            let j: Int
            let weight: Double
        }

        struct Slice: Sendable, Identifiable {
            let id: Int
            /// `2025년 3분기`
            let label: String
            let day: Int
            /// 앱을 쓰기 전 시기 — 적어 넣은 만큼만 되살아나므로 옅게 그린다.
            let beforeUse: Bool
            let status: TemporalNetwork.Status
            let present: [Int]
            let links: [Link]
            let communities: [Community]
            /// 앞 분기와 같은 모임 수 (`그대로` · 빌드 16) — 변화 목록에는 넣지 않고 시점 설명에 쓴다.
            var steady = 0
        }

        struct Change: Sendable, Identifiable {
            let id: Int
            let sliceLabel: String
            let phrase: String
            let name: String
            let memberIDs: [UUID]
            let beforeUse: Bool
        }

        var slices: [Slice] = []
        /// 최근 것부터.
        var changes: [Change] = []
    }

    let people: [PersonInfo]
    let meName: String?
    let today: Int
    let yearStart: Int
    let yearEnd: Int
    let edges: [GraphEdge]
    /// `people` 과 같은 차례, 맨 끝 하나가 나. 자리를 잡지 않은 자료(목록 맨 위 요약)는 비어 있다.
    let positions: [GraphLayout.Point]
    var communities: [Community] = []
    var communityStatus: CommunityStatus = .notEnoughLinks
    var readiness = ReadinessInput(people: 0, withFirstMet: 0, withRelationshipType: 0, withMetThrough: 0,
                                   withRecords: 0, strongEdges: 0, linkedPeople: 0)
    var gaps = Gaps()
    /// 지난 시점의 관계도 · 모임의 변화 (8번째 묶음 · D-32). 자리 잡기를 하는 자료에만.
    var timeline = Timeline()
    /// 아는 사이 후보 (빌드 16) — 이름 · 근거까지 만들어 둔다. 화면이 사람 전원에서 이름을 찾지 않게.
    var suggestions: [AcquaintanceSuggestionRoute.Item] = []
    /// 만들 때마다 새 값 — 화면은 이것으로 다시 셀 때를 안다. 사람 수만 보면 칸을 채운 뒤 돌아와도 그대로다.
    let generation = UUID()

    var isEmpty: Bool { people.isEmpty }

    /// 이 날 번호가 오늘에서 며칠 전인가를 말로.
    func phrase(forDay day: Int) -> String { RelativeDay.phrase(days: today - day) }

    static let empty = NetworkSnapshot(people: [], meName: nil, today: 0, yearStart: 0, yearEnd: 0, edges: [], positions: [])
}

enum NetworkSnapshotBuilder {
    /// 저장소를 **따로 연 문맥**에서 읽어 값으로 바꾸고 관계도 자리까지 잡는다. 주 스레드를 막지 않는다 (이슈 8 · 10).
    static func build(container: ModelContainer, now: Date = Date()) async -> NetworkSnapshot {
        await Task.detached(priority: .userInitiated) {
            LaunchTiming.measure("인맥 자료 만들기") { make(container: container, now: now, includesGraph: true) }
        }.value
    }

    /// 목록 맨 위 한 줄 요약용 — 자리 잡기 · 모임 찾기를 건너뛴다 (D-31).
    static func readiness(container: ModelContainer, now: Date = Date()) async -> ReadinessInput {
        await Task.detached(priority: .utility) {
            LaunchTiming.measure("입력 상태 세기") { make(container: container, now: now, includesGraph: false).readiness }
        }.value
    }

    private static func make(container: ModelContainer, now: Date, includesGraph: Bool) -> NetworkSnapshot {
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
        var hasRecord = Set<UUID>()
        var singles: [(day: Int, id: UUID)] = []
        var recordDays: [Int] = []
        recordDays.reserveCapacity(records.count)
        for record in records {
            let day = DayIndex.of(record.occurredAt, calendar: calendar)
            let ids = (record.participants ?? []).filter { !$0.isMe }.map(\.uuid)
            participantLists.append(ids)
            recordDays.append(day)
            if ids.count == 1 { singles.append((day: day, id: record.uuid)) }
            // 앞으로의 기록(예정)은 기록이 있다 · 마지막 기록일에 넣지 않는다 — 목록 · 돌아보기와 같은 기준 (이슈 20).
            guard day <= today else { continue }
            hasRecord.formUnion(ids)
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
        let strong = edges.filter(\.isStrong)
        let linked = Set(strong.flatMap { [$0.a, $0.b] })

        // 입력 상태 · 채울 것 (D-31). 사람은 이름 순 — 누가 더 모자란지 줄 세우지 않는다.
        let byName = NameSort.sorted(people, name: \.name, createdAt: { _ in Date.distantPast })
        var gaps = NetworkSnapshot.Gaps()
        gaps.noRelationshipType = byName.filter { ($0.relationshipType ?? "").isEmpty }.map(\.id)
        gaps.noMetThrough = byName.filter { ($0.metThrough ?? "").isEmpty }.map(\.id)
        gaps.noFirstMet = byName.filter { $0.firstMetDay == nil }.map(\.id)
        gaps.noRecord = byName.filter { !hasRecord.contains($0.id) }.map(\.id)
        gaps.unlinked = byName.filter { !linked.contains($0.id) }.map(\.id)
        gaps.singleParticipantRecords = singles.sorted { $0.day > $1.day }.map(\.id)
        let readiness = ReadinessInput(
            people: people.count,
            withFirstMet: people.count - gaps.noFirstMet.count,
            withRelationshipType: people.count - gaps.noRelationshipType.count,
            withMetThrough: people.count - gaps.noMetThrough.count,
            withRecords: people.count - gaps.noRecord.count,
            strongEdges: strong.count,
            linkedPeople: linked.count)
        lap("입력 상태 세기")

        var snapshot = NetworkSnapshot(people: people, meName: me?.name, today: today, yearStart: yearStart, yearEnd: yearEnd,
                                       edges: edges, positions: [])
        snapshot.readiness = readiness
        snapshot.gaps = gaps
        if includesGraph {
            var nameOf: [UUID: String] = [:]
            for person in graphPeople { nameOf[person.id] = person.name }
            snapshot.suggestions = AcquaintanceSuggestions.suggest(people: graphPeople, edges: edges, declined: DeclinedPairs.load())
                .map { suggestion in
                    AcquaintanceSuggestionRoute.Item(a: suggestion.a, b: suggestion.b,
                                                     aName: nameOf[suggestion.a] ?? "", bName: nameOf[suggestion.b] ?? "",
                                                     evidence: AcquaintanceSuggestionRoute.evidence(
                                                        together: suggestion.together,
                                                        introducer: suggestion.introducer.flatMap { nameOf[$0] }))
                }
            lap("아는 사이 후보 \(snapshot.suggestions.count)쌍")
        }
        guard includesGraph else { return snapshot }

        let links = edges.compactMap { edge -> GraphLayout.Link? in
            guard let i = index[edge.a], let j = index[edge.b] else { return nil }
            // 진한 선은 함께한 기록이 많을수록 조금 더 당긴다(로그). 같은 소속만이면 약하게.
            let weight = edge.isStrong ? 1 + log(1 + edge.togetherWeight) : 0.3
            return GraphLayout.Link(i: i, j: j, weight: weight)
        }
        let positions = GraphLayout.layout(nodeCount: people.count + 1, center: people.count, links: links)
        lap("자리 잡기")

        let (communities, status) = findCommunities(people: people, strong: strong, index: index,
                                                    readiness: readiness, nameOrder: byName.map(\.id))
        lap("모임 찾기 \(communities.count)개")

        let usageStart = others.map(\.createdAt).min().map { DayIndex.of($0, calendar: calendar) } ?? today
        let timeline = makeTimeline(people: people, nameOrder: byName.map(\.id), index: index,
                                    introducedBy: Dictionary(others.compactMap { person in
                                        person.introducedBy.map { (person.uuid, $0.uuid) }
                                    }, uniquingKeysWith: { first, _ in first }),
                                    recordDays: recordDays, participantLists: participantLists, ties: ties,
                                    now: now, today: today, usageStart: usageStart, calendar: calendar)
        lap("시점 \(timeline.slices.count)개 · 변화 \(timeline.changes.count)개")

        var result = NetworkSnapshot(people: people, meName: me?.name, today: today, yearStart: yearStart, yearEnd: yearEnd,
                                     edges: edges, positions: positions)
        result.readiness = readiness
        result.gaps = gaps
        result.communities = communities
        result.communityStatus = status
        result.timeline = timeline
        result.suggestions = snapshot.suggestions
        return result
    }

    /// 분기 끝마다 지난 시점의 관계도를 센다 (D-32). 첫 기록의 분기부터 지난 분기까지, 많아야 40개(10년).
    /// 번호는 **이름 순** — 점 차례가 늘 같게. 지난 시점의 모임 이름은 소속을 쓰지 않는다(소속에는 날짜가 없다).
    private static func makeTimeline(people: [NetworkSnapshot.PersonInfo], nameOrder: [UUID], index: [UUID: Int],
                                     introducedBy: [UUID: UUID], recordDays: [Int], participantLists: [[UUID]],
                                     ties: [(UUID, UUID)], now: Date, today: Int, usageStart: Int,
                                     calendar: Calendar) -> NetworkSnapshot.Timeline {
        guard let firstDay = recordDays.min() else { return NetworkSnapshot.Timeline() }
        // 분기 끝 날 — 오늘 이전에 끝난 분기만. `Calendar` 의 분기(.quarter)는 믿기 어려워 해 · 달로 센다.
        var ends: [(day: Int, label: String)] = []
        let firstDate = Date(timeIntervalSinceReferenceDate: Double(firstDay) * 86_400 + 43_200)
        var year = calendar.component(.year, from: firstDate)
        var number = (calendar.component(.month, from: firstDate) - 1) / 3 + 1
        while ends.count < 400 {
            // 다음 분기 첫날 0시 − 1초 = 이 분기의 마지막 순간.
            let nextYear = number == 4 ? year + 1 : year
            let nextMonth = number == 4 ? 1 : number * 3 + 1
            guard let nextStart = calendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: 1)),
                  nextStart <= now else { break }
            ends.append((DayIndex.of(nextStart.addingTimeInterval(-1), calendar: calendar), "\(year)년 \(number)분기"))
            year = nextYear
            number = number == 4 ? 1 : number + 1
        }
        ends = Array(ends.suffix(40))
        guard !ends.isEmpty else { return NetworkSnapshot.Timeline() }

        var node: [UUID: Int] = [:]
        for (k, id) in nameOrder.enumerated() { node[id] = k }
        let personAt = nameOrder.compactMap { index[$0] }   // 번호 → people 자리
        let members = nameOrder.map { id -> TemporalNetwork.Member in
            let info = index[id].map { people[$0] }
            return TemporalNetwork.Member(firstMetDay: info?.firstMetDay, introducedBy: introducedBy[id].flatMap { node[$0] })
        }
        let meetings = zip(recordDays, participantLists).map { pair in
            TemporalNetwork.Meeting(day: pair.0, participants: pair.1.compactMap { node[$0] })
        }
        let tieNodes = ties.compactMap { pair -> (Int, Int)? in
            guard let x = node[pair.0], let y = node[pair.1] else { return nil }
            return (x, y)
        }
        let computed = TemporalNetwork.slices(members: members, meetings: meetings, ties: tieNodes, sliceDays: ends.map(\.day))

        func name(_ group: [Int], _ used: inout Set<String>, _ unnamed: inout Int) -> String {
            let suggested = CommunityNaming.suggest(group.map {
                CommunityNaming.Member(organization: nil, tags: people[personAt[$0]].tags, metThrough: people[personAt[$0]].metThrough)
            })
            var result: String
            if let suggested {
                result = suggested
            } else {
                unnamed += 1
                result = "모임 \(unnamed)"
            }
            if used.contains(result) {
                unnamed += 1
                result += " · 모임 \(unnamed)"
            }
            used.insert(result)
            return result
        }

        var slices: [NetworkSnapshot.Timeline.Slice] = []
        var namesBySlice: [[String]] = []
        for (k, slice) in computed.enumerated() {
            var used = Set<String>()
            var unnamed = 0
            var groups: [NetworkSnapshot.Community] = []
            var names: [String] = []
            for group in slice.communities {
                let title = name(group, &used, &unnamed)
                names.append(title)
                let indices = group.map { personAt[$0] }
                groups.append(NetworkSnapshot.Community(id: groups.count, name: title,
                                                        memberIDs: indices.map { people[$0].id }, memberIndices: indices))
            }
            namesBySlice.append(names)
            slices.append(NetworkSnapshot.Timeline.Slice(
                id: k, label: ends[k].label, day: slice.day, beforeUse: slice.day < usageStart, status: slice.status,
                present: slice.present.map { personAt[$0] },
                links: slice.edges.map { NetworkSnapshot.Timeline.Link(i: personAt[$0.a], j: personAt[$0.b], weight: $0.weight) },
                communities: groups))
        }

        var changes: [NetworkSnapshot.Timeline.Change] = []
        for change in TemporalNetwork.changes(computed, threshold: GroupMatchSetting.current.threshold) {
            // 그대로는 변화가 아니다 — 목록에 넣지 않고 그 시점의 설명에 수로만 (빌드 16 · 조사 보고서 지금 2).
            if change.kind == .steady {
                slices[change.slice].steady += 1
                continue
            }
            // 이름은 그 모임이 보인 시점의 이름 — 나뉨 · 최근 기록 없음은 앞 시점의 모임이다.
            let at = (change.kind == .split || change.kind == .faded) ? change.slice - 1 : change.slice
            let position = computed[at].communities.firstIndex(of: change.members)
            let title = position.map { namesBySlice[at][$0] } ?? "모임"
            changes.append(NetworkSnapshot.Timeline.Change(
                id: changes.count, sliceLabel: ends[change.slice].label, phrase: change.kind.phrase, name: title,
                memberIDs: change.members.map { people[personAt[$0]].id }, beforeUse: computed[change.slice].day < usageStart))
        }
        var timeline = NetworkSnapshot.Timeline()
        timeline.slices = slices
        timeline.changes = changes.reversed()
        return timeline
    }

    /// 모임 찾기 (D-30) — **진한 선만** 쓴다. 무게는 함께한 기록 무게(n명 기록은 쌍마다 1/(n−1)) + 소개 1 + 아는 사이 1. 같은 소속은 넣지 않는다
    /// (소속으로 묶으면 이미 아는 것을 다시 보여 줄 뿐이다). 조건에 못 미치거나 뚜렷하게 나뉘지 않으면 묶지 않는다.
    private static func findCommunities(people: [NetworkSnapshot.PersonInfo], strong: [GraphEdge], index: [UUID: Int],
                                        readiness: ReadinessInput, nameOrder: [UUID])
        -> ([NetworkSnapshot.Community], NetworkSnapshot.CommunityStatus) {
        guard readiness.strongEdges >= InputReadiness.groupsMinimumStrongEdges,
              readiness.linkedPeople >= InputReadiness.groupsMinimumLinkedPeople else { return ([], .notEnoughLinks) }
        // 점 번호를 **이름 순**으로 매긴다 — 저장소가 내주는 차례는 정해져 있지 않아, 그대로 쓰면 켤 때마다 모임이 달라질 수 있다.
        var nodeOf: [Int: Int] = [:]          // people 자리 → 점 번호
        var personAt: [Int] = []              // 점 번호 → people 자리
        for id in nameOrder {
            guard let i = index[id] else { continue }
            nodeOf[i] = personAt.count
            personAt.append(i)
        }
        let links = strong.compactMap { edge -> CommunityDetection.Link? in
            guard let i = index[edge.a].flatMap({ nodeOf[$0] }), let j = index[edge.b].flatMap({ nodeOf[$0] }) else { return nil }
            // 함께한 기록은 n명 기록의 쌍마다 1/(n−1) (빌드 16) — 큰 회식 하나가 모임을 덮지 않게.
            let weight = edge.togetherWeight + (edge.introduced ? 1 : 0) + (edge.acquainted ? 1 : 0)
            return CommunityDetection.Link(i: i, j: j, weight: weight)
        }
        let found = CommunityDetection.louvain(nodeCount: personAt.count, links: links)
        guard found.modularity >= CommunityDetection.minimumModularity else { return ([], .noClearGroups) }

        var used = Set<String>()
        var unnamed = 0
        var communities: [NetworkSnapshot.Community] = []
        for nodes in found.communities where nodes.count >= CommunityDetection.minimumGroupSize {
            // 점 번호가 이름 순이라 오름차순이면 곧 이름 순이다.
            let members = nodes.map { personAt[$0] }
            let suggested = CommunityNaming.suggest(members.map {
                CommunityNaming.Member(organization: people[$0].organization, tags: people[$0].tags,
                                       metThrough: people[$0].metThrough)
            })
            var name: String
            if let suggested {
                name = suggested
            } else {
                unnamed += 1
                name = "모임 \(unnamed)"
            }
            // 같은 이름이 둘이면 뒤의 것에 번호를 붙인다.
            if used.contains(name) {
                unnamed += 1
                name += " · 모임 \(unnamed)"
            }
            used.insert(name)
            communities.append(NetworkSnapshot.Community(id: communities.count, name: name,
                                                         memberIDs: members.map { people[$0].id }, memberIndices: members))
        }
        return (communities, communities.isEmpty ? .noClearGroups : .shown)
    }
}

/// **모임 짝짓기 문턱** (설정 · D-39) — 앞 분기 모임과 이번 분기 모임을 같은 모임으로 볼 겹침 정도.
///
/// 작은 쪽의 절반 이상이 겹치면 이 설정과 상관없이 같은 모임이다(`TemporalNetwork.inclusionThreshold`). 이 설정은 겹침이
/// 절반이 안 될 때만 판정을 바꾼다. 기본은 0.3 — 비교 표(`Tools/golden/compare-thresholds.py`)를 보고 사용자가 골랐다.
/// 기기 편의라 UserDefaults. 내 인맥을 열 때마다 자료를 다시 만들므로 바꾸면 다음에 열 때 반영된다.
enum GroupMatchSetting: String, CaseIterable, Identifiable, Sendable {
    case standard
    case loose
    case looser

    static let key = "network.groupMatch"

    var id: String { rawValue }

    var threshold: Double {
        switch self {
        case .standard: return TemporalNetwork.matchThreshold   // 0.3
        case .loose: return 0.2
        case .looser: return 0.1
        }
    }

    var title: String {
        switch self {
        case .standard: return "보통 (기본)"
        case .loose: return "느슨하게"
        case .looser: return "아주 느슨하게"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "사람이 절반 넘게 바뀌면 다른 모임으로 봅니다. 열 명 모임이면 다섯 명 넘게 남아야 이어집니다."
        case .loose: return "열 명 모임에서 네 명만 남아도 같은 모임으로 이어 줍니다."
        case .looser: return "조금만 겹쳐도 이어 줍니다. 네 명 모임 둘이 한 사람만 겹쳐도 같은 모임으로 볼 수 있습니다."
        }
    }

    static var current: GroupMatchSetting {
        UserDefaults.standard.string(forKey: key).flatMap(GroupMatchSetting.init(rawValue:)) ?? .standard
    }
}
