import SwiftData
import XCTest
@testable import SlowConnection

/// 기록 저장 규칙을 인메모리 저장소로 시험한다 — 참여자 N:M · 제목/메모 규칙 · 정오 정규화 · 삭제.
@MainActor
final class RecordStoreTests: XCTestCase {

    private struct Fixture {
        let container: ModelContainer
        let records: RecordStore
        let people: PersonStore
        let a: Person
        let b: Person
    }

    private func makeFixture() throws -> Fixture {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let a = Person(name: "A")
        let b = Person(name: "B")
        context.insert(a)
        context.insert(b)
        try context.save()
        return Fixture(container: container, records: RecordStore(context: context),
                       people: PersonStore(context: context), a: a, b: b)
    }

    func testCreateWithNoteOnlyUsesFirstLineAsDisplayTitle() throws {
        let f = try makeFixture()
        var draft = RecordDraft(anchor: f.a)
        draft.note = "\n점심 먹으며 이직 고민 들음\n둘째 줄"
        let record = try f.records.create(draft)
        XCTAssertNil(record.title)
        XCTAssertEqual(record.displayTitle, "점심 먹으며 이직 고민 들음")
        XCTAssertEqual(record.participants?.count, 1)
        XCTAssertEqual(f.a.records?.count, 1, "역방향 관계가 채워진다")
    }

    func testDraftNeedsTitleOrNoteAndAParticipant() throws {
        let f = try makeFixture()
        var draft = RecordDraft(anchor: f.a)
        XCTAssertFalse(draft.canSave)
        draft.title = "  "
        XCTAssertFalse(draft.canSave)
        draft.title = "회의"
        XCTAssertTrue(draft.canSave)
        draft.participants = []
        XCTAssertFalse(draft.canSave)
    }

    func testSharedRecordAppearsInBothTimelines() throws {
        let f = try makeFixture()
        var draft = RecordDraft(anchor: f.a)
        draft.title = "셋이 회의"
        draft.participants = [f.a, f.b, f.a]  // 같은 사람 두 번 → 한 번만
        let record = try f.records.create(draft)
        XCTAssertEqual(record.participants?.count, 2)
        XCTAssertEqual(RecordStore.timeline(of: f.a).map(\.displayTitle), ["셋이 회의"])
        XCTAssertEqual(RecordStore.timeline(of: f.b).map(\.displayTitle), ["셋이 회의"])
        XCTAssertEqual(record.otherParticipantCount(besides: f.a), 1)
    }

    func testTimelineIsNewestFirstThenNewestCreated() throws {
        let f = try makeFixture()
        func add(_ title: String, _ day: Int) throws {
            var draft = RecordDraft(anchor: f.a)
            draft.title = title
            draft.occurredAt = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
            _ = try f.records.create(draft)
        }
        try add("옛날", 100)
        try add("같은 날 먼저", 300)
        try add("같은 날 나중", 300)
        try add("중간", 200)
        XCTAssertEqual(RecordStore.timeline(of: f.a).map(\.displayTitle), ["같은 날 나중", "같은 날 먼저", "중간", "옛날"])
    }

    func testOccurredAtIsStoredAtNoon() throws {
        let f = try makeFixture()
        var draft = RecordDraft(anchor: f.a)
        draft.note = "x"
        let record = try f.records.create(draft)
        let components = Calendar.current.dateComponents([.hour, .minute], from: record.occurredAt)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
    }

    func testDeletingRecordKeepsPeopleAndApplyUpdatesFields() throws {
        let f = try makeFixture()
        var draft = RecordDraft(anchor: f.a)
        draft.title = "처음"
        draft.tags = ["#업무", "업무 ", "Work"]
        let record = try f.records.create(draft)
        XCTAssertEqual(record.tags, ["업무", "Work"])

        draft.title = "고침"
        draft.recordType = "nope"
        draft.participants = [f.b]
        try f.records.apply(draft, to: record)
        XCTAssertEqual(record.title, "고침")
        XCTAssertEqual(record.recordType, "other", "모르는 유형 키는 기타로")
        XCTAssertEqual(RecordStore.timeline(of: f.a).count, 0)
        XCTAssertEqual(RecordStore.timeline(of: f.b).count, 1)

        try f.records.delete(record)
        XCTAssertEqual(try f.people.sortedPeople().map(\.name), ["A", "B"])
        XCTAssertEqual(try f.records.context.fetch(FetchDescriptor<Record>()).count, 0)
    }
}
