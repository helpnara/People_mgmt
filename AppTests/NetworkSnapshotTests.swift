import SwiftData
import XCTest
@testable import SlowConnection

/// **내 인맥 자료** (6번째 묶음) — 따로 연 문맥에서 저장소를 읽어 값으로 만드는 길이 서는가.
/// 셈 규칙은 Core 정답표(`dyadMetrics` · `networkOverview` · `traitBuckets` · `graphEdges`)가 대조한다.
/// 여기는 SwiftData 에서 값으로 옮기는 부분만 본다 — 나는 빠지고, 함께한 기록이 선이 되고, 자리가 사람 수 + 1(나)인가.
@MainActor
final class NetworkSnapshotTests: XCTestCase {

    func testSnapshotLeavesMeOutAndLinksPeopleWhoShareARecord() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let store = PersonStore(context: context)
        let records = RecordStore(context: context)

        var mine = PersonDraft()
        mine.name = "나"
        _ = try store.create(mine, isMe: true)

        var first = PersonDraft()
        first.name = "첫째"
        first.organization = "같은 회사"
        let a = try store.create(first)
        var second = PersonDraft()
        second.name = "둘째"
        second.organization = "같은 회사"
        let b = try store.create(second)
        var third = PersonDraft()
        third.name = "셋째"
        let c = try store.create(third)

        var draft = RecordDraft(anchor: a)
        draft.title = "함께한 점심"
        draft.participants = [a, b]
        _ = try records.create(draft)

        let snapshot = await NetworkSnapshotBuilder.build(container: container)
        XCTAssertEqual(Set(snapshot.people.map(\.name)), ["첫째", "둘째", "셋째"], "나는 사람 목록에 없다")
        XCTAssertEqual(snapshot.meName, "나")
        XCTAssertEqual(snapshot.positions.count, 4, "자리는 사람 수 + 나")

        let strong = snapshot.edges.filter(\.isStrong)
        XCTAssertEqual(strong.count, 1, "함께한 기록 하나가 진한 선 하나")
        XCTAssertEqual(strong.first?.together, 1)
        XCTAssertTrue(strong.first?.sameOrganization ?? false, "같은 회사라 옅은 선도 겹친다")
        XCTAssertNotNil(snapshot.people.first { $0.id == a.uuid }?.lastDay, "기록이 있는 사람은 마지막 기록일이 있다")
        XCTAssertNil(snapshot.people.first { $0.id == c.uuid }?.lastDay, "기록이 없는 사람은 없다")
    }

    /// 입력 상태 · 채울 것 (D-31) — 따로 연 문맥에서 센 수와 목록이 저장한 것과 맞는가.
    func testSnapshotCountsReadinessAndGaps() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let store = PersonStore(context: context)
        let records = RecordStore(context: context)

        var first = PersonDraft()
        first.name = "첫째"
        first.relationshipType = "동료"
        first.hasFirstMetDate = true
        first.firstMetDate = Date(timeIntervalSince1970: 1_600_000_000)
        let a = try store.create(first)
        var second = PersonDraft()
        second.name = "둘째"
        let b = try store.create(second)
        var third = PersonDraft()
        third.name = "셋째"
        let c = try store.create(third)

        var together = RecordDraft(anchor: a)
        together.title = "함께한 점심"
        together.participants = [a, b]
        _ = try records.create(together)
        var alone = RecordDraft(anchor: a)
        alone.title = "둘이 차"
        let single = try records.create(alone)

        let snapshot = await NetworkSnapshotBuilder.build(container: container)
        let readiness = snapshot.readiness
        XCTAssertEqual(readiness.people, 3)
        XCTAssertEqual(readiness.withFirstMet, 1)
        XCTAssertEqual(readiness.withRelationshipType, 1)
        XCTAssertEqual(readiness.withRecords, 2, "기록이 있는 사람은 첫째 · 둘째")
        XCTAssertEqual(readiness.strongEdges, 1)
        XCTAssertEqual(readiness.linkedPeople, 2)
        XCTAssertEqual(snapshot.gaps.noRecord, [c.uuid])
        XCTAssertEqual(snapshot.gaps.unlinked, [c.uuid])
        XCTAssertEqual(snapshot.gaps.singleParticipantRecords, [single.uuid], "함께한 사람이 한 명뿐인 기록")
        XCTAssertEqual(Set(snapshot.gaps.noFirstMet), [b.uuid, c.uuid])
        XCTAssertEqual(snapshot.communityStatus, .notEnoughLinks, "진한 선 하나로는 모임을 찾지 않는다")

        let light = await NetworkSnapshotBuilder.readiness(container: container)
        XCTAssertEqual(light, readiness, "목록 맨 위 요약도 같은 수를 낸다")
    }

    /// 모임 찾기 (D-30) — 다섯씩 촘촘한 세 무리를 한 줄로만 이으면 세 모임으로 나뉘고, 이름은 소속 · 태그에서 제안된다.
    /// 무리 모양은 정답표의 Louvain(파이썬)으로 같은 그래프를 돌려 세 모임이 나오는 것을 확인했다.
    func testSnapshotFindsCommunitiesFromAcquaintances() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let store = PersonStore(context: context)

        var groups: [[Person]] = []
        for (prefix, organization, tag) in [("가", nil, "독서모임"), ("나", "나비랩스", nil), ("다", nil, nil)] as [(String, String?, String?)] {
            var members: [Person] = []
            for i in 1...5 {
                var draft = PersonDraft()
                draft.name = "\(prefix)\(i)"
                draft.organization = organization ?? ""
                draft.tags = tag.map { [$0] } ?? []
                members.append(try store.create(draft))
            }
            groups.append(members)
        }
        for members in groups {
            for i in 0..<5 {
                let tie = Tie()
                context.insert(tie)
                tie.first = members[i]
                tie.second = members[(i + 1) % 5]
            }
            for (x, y) in [(0, 2), (1, 3)] {
                let tie = Tie()
                context.insert(tie)
                tie.first = members[x]
                tie.second = members[y]
            }
        }
        let bridge = Tie()
        context.insert(bridge)
        bridge.first = groups[0][0]
        bridge.second = groups[1][1]
        try context.save()

        let snapshot = await NetworkSnapshotBuilder.build(container: container)
        XCTAssertEqual(snapshot.readiness.strongEdges, 22)
        XCTAssertEqual(snapshot.communityStatus, .shown)
        XCTAssertEqual(snapshot.communities.map(\.name), ["#독서모임", "나비랩스", "묶음 1"])
        XCTAssertEqual(snapshot.communities.map { Set($0.memberIDs) }, groups.map { Set($0.map(\.uuid)) })
    }
}
