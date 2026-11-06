import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **1.1.8 (빌드 61 · 스키마 11판)** — 기억할 것(FR-062) · 다음에 이야기할 것(FR-063) · 사람 고정(FR-066)의 저장 규칙,
/// 기념일이 든 vCard 왕복(FR-068), 10판 → 11판 옮기기.
@MainActor
final class Build61Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func makeContainer() throws -> ModelContainer {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        return container
    }

    func testKeyNoteSavesTrimmedAndClears() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "기억 견본"
        draft.keyNote = "  커피는 디카페인  "
        let person = try store.create(draft)
        XCTAssertEqual(person.keyNote, "커피는 디카페인", "앞뒤 빈칸은 지운다")
        XCTAssertEqual(PersonDraft(person: person).keyNote, "커피는 디카페인", "편집으로 다시 읽힌다")

        var edit = PersonDraft(person: person)
        edit.keyNote = " "
        try store.apply(edit, to: person)
        XCTAssertNil(person.keyNote, "비우면 없앤다")
    }

    func testPinningDoesNotTouchUpdatedAt() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "고정 견본"
        let person = try store.create(draft)
        let updated = person.updatedAt
        try store.setPinned(person, true)
        XCTAssertTrue(person.isPinned)
        XCTAssertEqual(person.updatedAt, updated, "고정은 내용을 고친 것이 아니다")
        try store.setPinned(person, false)
        XCTAssertFalse(person.isPinned)
    }

    func testTalkItemsAddToggleAndRemove() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "이야기 견본"
        let person = try store.create(draft)

        XCTAssertNil(try store.addTalkItem("   ", to: person), "빈 글은 더하지 않는다")
        let first = try XCTUnwrap(try store.addTalkItem("입학 선물 물어보기", to: person))
        let second = try XCTUnwrap(try store.addTalkItem("책 돌려주기", to: person))
        XCTAssertEqual(person.openTalkItems.map(\.text), ["입학 선물 물어보기", "책 돌려주기"], "더한 차례대로")

        try store.setTalkItem(first, done: true)
        XCTAssertEqual(person.openTalkItems.map(\.text), ["책 돌려주기"])
        XCTAssertEqual(person.doneTalkItems.map(\.text), ["입학 선물 물어보기"])
        XCTAssertNotNil(first.doneAt)
        try store.setTalkItem(first, done: false)
        XCTAssertNil(first.doneAt, "다시 열면 끝낸 때를 지운다")

        try store.removeTalkItem(second)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TalkItem>()), 1)
        XCTAssertEqual(person.openTalkItems.map(\.text), ["입학 선물 물어보기"])

        let long = String(repeating: "가", count: Limits.talkItem + 20)
        let clipped = try XCTUnwrap(try store.addTalkItem(long, to: person))
        XCTAssertEqual(clipped.text.count, Limits.talkItem, "한도로 자른다")
    }

    func testDeletingPersonDeletesTalkItemsAndUndoBringsThemBack() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "지울 사람"
        draft.keyNote = "매운 음식은 피한다"
        let person = try store.create(draft)
        try store.setPinned(person, true)
        let done = try XCTUnwrap(try store.addTalkItem("끝낸 이야기", to: person))
        try store.setTalkItem(done, done: true)
        try store.addTalkItem("남은 이야기", to: person)

        let undo = DeletionUndo.shared
        undo.finish()
        defer { undo.finish() }
        try undo.delete(person, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TalkItem>()), 0, "사람과 함께 지운다")
        XCTAssertTrue(undo.undo())
        let back = try XCTUnwrap(try context.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(back.keyNote, "매운 음식은 피한다")
        XCTAssertTrue(back.isPinned, "고정도 돌아온다")
        XCTAssertEqual(back.openTalkItems.map(\.text), ["남은 이야기"])
        XCTAssertEqual(back.doneTalkItems.map(\.text), ["끝낸 이야기"], "끝낸 것은 끝낸 채로")
    }

    func testBackupRoundTripKeepsKeyNotePinAndTalkItems() throws {
        let source = try makeContainer().mainContext
        let store = PersonStore(context: source)
        var draft = PersonDraft()
        draft.name = "백업 견본"
        draft.keyNote = "가족 이름: 하준"
        let person = try store.create(draft)
        try store.setPinned(person, true)
        try store.addTalkItem("멘토링 주제", to: person)
        let file = Backup.makeFile(context: source)
        let decoded = try Backup.decode(try Backup.encode(file))

        let target = try makeContainer().mainContext
        _ = try Backup.restore(decoded, into: target)
        let restored = try XCTUnwrap(try target.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(restored.keyNote, "가족 이름: 하준")
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.openTalkItems.map(\.text), ["멘토링 주제"])
    }

    /// 기념일이 vCard 로 나갔다가 초안으로 돌아온다 (FR-068) — 셈은 Core 정답표(`vcardEncode` · `vcardParse`)가 본다.
    func testVCardCarriesAnniversariesIntoDraft() throws {
        let card = VCardPerson(name: "카드 견본",
                               anniversaries: [VCardDate(label: "결혼기념일", month: 10, day: 12, year: 2018),
                                               VCardDate(label: "입사일", month: 3, day: 2)])
        let parsed = try XCTUnwrap(VCard.parse(VCard.encode([card])).first)
        let draft = VCardTransfer.draft(parsed)
        XCTAssertEqual(draft.specialDays.map(\.label), ["결혼기념일", "입사일"])
        XCTAssertEqual(draft.specialDays.map(\.year), [2018, nil])

        let context = try makeContainer().mainContext
        let person = try PersonStore(context: context).create(draft)
        XCTAssertEqual(person.sortedSpecialDays.map(\.label), ["결혼기념일", "입사일"], "가져오면 기념일로 저장된다")
    }

    // MARK: - 10판 → 11판

    /// 10판(App Store 1.1.7) 저장소 → 11판: 사람 · 기념일이 남고, 기억할 것 · 고정 · 이야기할 것은 비어 있다가 쓸 수 있다.
    func testVersionTenStoreOpensAndTakesNewFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v10.store")

        do {
            let schema = Schema(versionedSchema: SchemaV10.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV10.Person(name: "10판 친구")
            context.insert(friend)
            let wedding = SchemaV10.SpecialDay(label: "결혼기념일", month: 10, day: 12, year: 2018, remind: true, position: 0)
            context.insert(wedding)
            wedding.person = friend
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let person = try XCTUnwrap(try context.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(person.name, "10판 친구")
        XCTAssertEqual(person.sortedSpecialDays.map(\.label), ["결혼기념일"], "기념일이 남는다")
        XCTAssertNil(person.keyNote)
        XCTAssertFalse(person.isPinned)
        XCTAssertTrue(person.openTalkItems.isEmpty)

        let store = PersonStore(context: context)
        try store.setPinned(person, true)
        try store.addTalkItem("옮긴 뒤 첫 이야기", to: person)
        XCTAssertEqual(person.openTalkItems.map(\.text), ["옮긴 뒤 첫 이야기"], "이야기할 것을 더할 수 있다")
    }
}
