import SwiftData
import XCTest
@testable import SlowConnection

/// **빌드 16** — 아는 사이 후보(조사 보고서 지금 5): 같은 기록에 함께 나온 두 사람이 후보로 뜨고, 이으면 한 줄만 생기고
/// 후보에서 빠지는가, `아니요` 한 쌍은 다시 묻지 않는가. 후보의 차례 · 근거 셈은 Core 정답표(`acquaintanceSuggestions`)가 본다.
@MainActor
final class Build16Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func makePair() throws -> (ModelContainer, Person, Person) {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        let context = container.mainContext
        let people = PersonStore(context: context)
        var first = PersonDraft()
        first.name = "가람"
        let a = try people.create(first)
        var second = PersonDraft()
        second.name = "나래"
        let b = try people.create(second)
        var draft = RecordDraft(anchor: a)
        draft.title = "함께한 점심"
        draft.participants = [a, b]
        _ = try RecordStore(context: context).create(draft)
        return (container, a, b)
    }

    func testLinkingMakesOneTieAndTheSuggestionGoesAway() async throws {
        let (container, a, b) = try makePair()
        let before = await NetworkSnapshotBuilder.build(container: container)
        XCTAssertEqual(before.suggestions.map { [$0.a, $0.b] }, [[a.uuid, b.uuid]], "함께 나온 두 사람이 후보로 (이름 순)")
        XCTAssertEqual(before.suggestions.first?.aName, "가람")

        let store = PersonStore(context: container.mainContext)
        try store.link(a, b)
        try store.link(b, a)   // 이미 이어져 있으면 아무것도 하지 않는다
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Tie>()), 1, "같은 두 사람은 한 줄")

        let after = await NetworkSnapshotBuilder.build(container: container)
        XCTAssertTrue(after.suggestions.isEmpty, "이은 쌍은 다시 묻지 않는다")
    }

    func testDeclinedPairIsNotAskedAgain() async throws {
        let (container, a, b) = try makePair()
        DeclinedPairs.add(b.uuid, a.uuid)   // 차례가 달라도 같은 쌍
        let snapshot = await NetworkSnapshotBuilder.build(container: container)
        XCTAssertTrue(snapshot.suggestions.isEmpty, "아니요 한 쌍은 다시 묻지 않는다")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Tie>()), 0, "아니요는 잇지 않는다")
    }
}
