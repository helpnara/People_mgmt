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

    func testRecentSortPutsLatestRecordFirstAndPeopleWithoutRecordsLast() throws {
        let fixture = try makeFixture()
        let context = fixture.store.context
        let quiet = Person(name: "가만")
        let old = Person(name: "옛날")
        let fresh = Person(name: "최근")
        for person in [quiet, old, fresh] { context.insert(person) }
        let oldRecord = Record(recordType: "meal", occurredAt: Date(timeIntervalSince1970: 1_000_000), title: "옛 기록")
        let freshRecord = Record(recordType: "meal", occurredAt: Date(timeIntervalSince1970: 2_000_000), title: "새 기록")
        context.insert(oldRecord)
        context.insert(freshRecord)
        oldRecord.participants = [old]
        freshRecord.participants = [fresh]
        try context.save()

        XCTAssertEqual(PersonStore.sorted([quiet, old, fresh], by: .recent).map(\.name), ["최근", "옛날", "가만"])
        XCTAssertEqual(PersonStore.sorted([quiet, old, fresh], by: .name).map(\.name), ["가만", "옛날", "최근"])
        XCTAssertEqual(fresh.lastRecordAt, Date(timeIntervalSince1970: 2_000_000))
        XCTAssertNil(quiet.lastRecordAt)
    }

    func testCardAndContactNoteAreSavedAndCleared() throws {
        let fixture = try makeFixture()
        var draft = PersonDraft()
        draft.name = "명함 있는 사람"
        draft.contactNote = "  010-1111-2222 · a@example.com  "
        draft.businessCard = Data([1, 2, 3])
        let person = try fixture.store.create(draft)
        XCTAssertEqual(person.contactNote, "010-1111-2222 · a@example.com")
        XCTAssertEqual(person.businessCard, Data([1, 2, 3]))

        var edit = PersonDraft(person: person)
        XCTAssertEqual(edit.businessCard, Data([1, 2, 3]))
        edit.businessCard = nil
        edit.contactNote = " "
        try fixture.store.apply(edit, to: person)
        XCTAssertNil(person.businessCard)
        XCTAssertNil(person.contactNote)
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

    /// 연락 수단 네 칸이 저장되고, 빈칸으로 고치면 비워진다 (이슈 11).
    func testContactFieldsAreSavedTrimmedAndCleared() throws {
        let fixture = try makeFixture()
        var draft = PersonDraft()
        draft.name = "연락 칸"
        draft.mobilePhone = " 010-1111-2222 "
        draft.officePhone = "02-333-4444"
        draft.faxNumber = "02-333-4445"
        draft.email = " a@example.com"
        let person = try fixture.store.create(draft)
        XCTAssertEqual(person.mobilePhone, "010-1111-2222")
        XCTAssertEqual(person.officePhone, "02-333-4444")
        XCTAssertEqual(person.faxNumber, "02-333-4445")
        XCTAssertEqual(person.email, "a@example.com")

        var edit = PersonDraft(person: person)
        XCTAssertEqual(edit.mobilePhone, "010-1111-2222", "수정 화면이 저장된 값을 읽는다")
        edit.mobilePhone = " "
        edit.email = ""
        try fixture.store.apply(edit, to: person)
        XCTAssertNil(person.mobilePhone)
        XCTAssertNil(person.email)
        XCTAssertEqual(person.officePhone, "02-333-4444", "건드리지 않은 칸은 그대로")
    }

    /// **나** 는 하나뿐이고, 사람 목록 · 같은 이름 안내에서 빠진다 (이슈 12).
    func testMeIsSingleAndLeftOutOfPeople() throws {
        let fixture = try makeFixture()
        var mine = PersonDraft()
        mine.name = "나의 이름"
        let me = try fixture.store.create(mine, isMe: true)
        XCTAssertTrue(me.isMe)

        mine.name = "고친 내 이름"
        let again = try fixture.store.create(mine, isMe: true)
        XCTAssertTrue(again === me, "나를 또 만들면 있던 나를 고친다")
        XCTAssertEqual(me.name, "고친 내 이름")

        var other = PersonDraft()
        other.name = "고친 내 이름"
        _ = try fixture.store.create(other)

        XCTAssertTrue(try fixture.store.me() === me)
        XCTAssertEqual(try fixture.store.allPeople().count, 1, "나는 사람 수에 들지 않는다")
        XCTAssertEqual(try fixture.store.sortedPeople().map(\.isMe), [false])
        XCTAssertEqual(fixture.store.sameName(as: "고친 내 이름").count, 1, "같은 이름 안내에 나는 없다")
    }

    /// **아는 사이** (D-30) — 고른 대로 연결이 생기고 빠지며, 양쪽에서 보이고, 사람을 지우면 연결만 지워진다.
    func testAcquaintancesAreSymmetricAndFollowTheDraft() throws {
        let fixture = try makeFixture()
        var draftA = PersonDraft()
        draftA.name = "가"
        let a = try fixture.store.create(draftA)
        var draftB = PersonDraft()
        draftB.name = "나"
        let b = try fixture.store.create(draftB)
        var draftC = PersonDraft()
        draftC.name = "다"
        let c = try fixture.store.create(draftC)

        var edit = PersonDraft(person: a)
        edit.acquaintances = [b, c, b, a]
        try fixture.store.apply(edit, to: a)
        XCTAssertEqual(Set(a.acquaintances.map(\.name)), ["나", "다"], "겹침 · 자기 자신은 빠진다")
        XCTAssertEqual(b.acquaintances.map(\.name), ["가"], "상대 쪽에서도 보인다")

        var again = PersonDraft(person: b)
        XCTAssertEqual(again.acquaintances.map(\.name), ["가"])
        again.acquaintances = []
        try fixture.store.apply(again, to: b)
        XCTAssertEqual(a.acquaintances.map(\.name), ["다"], "한쪽에서 빼면 연결이 지워진다")

        try fixture.store.delete(c)
        XCTAssertTrue(a.acquaintances.isEmpty, "사람을 지우면 그 사람의 연결도 지워진다")
        XCTAssertFalse(a.isGone, "상대 사람은 남는다")
        let ties = try fixture.container.mainContext.fetch(FetchDescriptor<Tie>())
        XCTAssertTrue(ties.isEmpty, "남은 연결이 없다")
    }
}

