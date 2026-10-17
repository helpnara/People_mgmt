import SwiftData
import XCTest
@testable import SlowConnection

/// 저장소를 쓰는 규칙을 인메모리 저장소로 시험한다. 순수 셈은 Core 의 골든 테스트가 맡고,
/// 여기는 **SwiftData 가 있어야만** 보이는 것만 둔다 — 삭제 규칙 · 소개자 nullify · 같은 이름.
@MainActor
final class PersonStoreTests: XCTestCase {

    private struct Fixture {
        let container: ModelContainer
        let store: PersonStore
    }

    private func makeFixture() throws -> Fixture {
        let container = try Persistence.makeContainer(inMemory: true)
        return Fixture(container: container, store: PersonStore(context: container.mainContext))
    }

    func testCreateWithNameOnlyTrimsAndNormalizes() throws {
        let fixture = try makeFixture()
        var draft = PersonDraft()
        draft.name = "  홍길동 "
        let person = try fixture.store.create(draft)
        XCTAssertEqual(person.name, "홍길동")
        XCTAssertNil(person.firstMetDate)
        XCTAssertNil(person.organization)
        XCTAssertEqual(try fixture.store.sortedPeople().count, 1)
    }

    func testFirstMetDateIsStoredAtNoon() throws {
        let fixture = try makeFixture()
        var draft = PersonDraft()
        draft.name = "김하늘"
        draft.hasFirstMetDate = true
        draft.firstMetDate = Date(timeIntervalSince1970: 1_772_922_600) // 2026-03-08 08:30 KST 쯤 — 시간대는 기기 것
        let person = try fixture.store.create(draft)
        let stored = try XCTUnwrap(person.firstMetDate)
        let components = Calendar.current.dateComponents([.hour, .minute], from: stored)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
    }

    func testDeleteRemovesSoleRecordsAndLeavesSharedOnes() throws {
        let fixture = try makeFixture()
        let context = fixture.store.context
        let a = Person(name: "A")
        let b = Person(name: "B")
        context.insert(a)
        context.insert(b)
        let sole = Record(recordType: "meal", title: "둘이", note: nil)
        let shared = Record(recordType: "meeting", title: "셋이", note: nil)
        context.insert(sole)
        context.insert(shared)
        sole.participants = [b]
        shared.participants = [a, b]
        try context.save()

        let summary = fixture.store.deletionSummary(for: b)
        XCTAssertEqual(summary.sole, 1)
        XCTAssertEqual(summary.shared, 1)
        XCTAssertTrue(fixture.store.deletionMessage(for: b).contains("기록 1건이 삭제되고"))

        try fixture.store.delete(b)

        let records = try context.fetch(FetchDescriptor<Record>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.title, "셋이")
        XCTAssertEqual(records.first?.participants?.count, 1)
        XCTAssertEqual(records.first?.participants?.first?.name, "A")
        XCTAssertEqual(try fixture.store.sortedPeople().map(\.name), ["A"])
    }

    func testDeletingIntroducerClearsIntroducedBy() throws {
        let fixture = try makeFixture()
        let context = fixture.store.context
        let introducer = Person(name: "소개자")
        let newcomer = Person(name: "소개받은 사람")
        context.insert(introducer)
        context.insert(newcomer)
        newcomer.metThrough = "소개"
        newcomer.introducedBy = introducer
        try context.save()
        XCTAssertEqual(introducer.introduced?.count, 1)

        try fixture.store.delete(introducer)

        XCTAssertNil(newcomer.introducedBy)
        XCTAssertEqual(try fixture.store.sortedPeople().map(\.name), ["소개받은 사람"])
    }

    func testSameNameIgnoresCaseAndSurroundingSpaces() throws {
        let fixture = try makeFixture()
        var first = PersonDraft()
        first.name = "Alice Park"
        let alice = try fixture.store.create(first)
        XCTAssertEqual(fixture.store.sameName(as: " alice park ").map(\.name), ["Alice Park"])
        XCTAssertTrue(fixture.store.sameName(as: "alice park", excluding: alice).isEmpty)
        XCTAssertTrue(fixture.store.sameName(as: "   ").isEmpty)
    }

    func testApplyDraftDropsIntroducerWhenPathIsNotIntroduction() throws {
        let fixture = try makeFixture()
        let context = fixture.store.context
        let introducer = Person(name: "소개자")
        context.insert(introducer)
        var draft = PersonDraft()
        draft.name = "새 사람"
        draft.metThrough = "직장"
        draft.introducedBy = introducer
        let person = try fixture.store.create(draft)
        XCTAssertNil(person.introducedBy, "경로가 소개가 아니면 소개자를 저장하지 않는다")

        draft.metThrough = "소개"
        try fixture.store.apply(draft, to: person)
        XCTAssertTrue(person.introducedBy === introducer)
    }
}
