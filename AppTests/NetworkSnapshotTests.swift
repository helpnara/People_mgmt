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
}
