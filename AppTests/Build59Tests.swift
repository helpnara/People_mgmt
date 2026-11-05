import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **1.1.7 (빌드 59 · 스키마 10판)** — 기념일(이슈 84 · D-77)과 사람별 생일 알림 끄기의 저장 규칙.
@MainActor
final class Build59Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func makeContainer() throws -> ModelContainer {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        return container
    }

    func testSpecialDaysSaveUpdateAndRemove() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "기념일 견본"
        draft.specialDays = [DraftSpecialDay(label: "결혼기념일", month: 11, day: 20, year: 2016),
                             DraftSpecialDay(label: "입사일", month: 3, day: 2, remind: false),
                             DraftSpecialDay(label: "없는 날", month: 2, day: 30)]
        let person = try store.create(draft)
        XCTAssertEqual(person.sortedSpecialDays.map(\.label), ["결혼기념일", "입사일"], "맞지 않는 날은 저장하지 않는다")
        XCTAssertEqual(person.sortedSpecialDays.map(\.remind), [true, false])
        XCTAssertEqual(person.sortedSpecialDays.first?.year, 2016)

        var edit = PersonDraft(person: person)
        XCTAssertEqual(edit.specialDays.map(\.label), ["결혼기념일", "입사일"], "편집으로 다시 읽힌다")
        let keptID = edit.specialDays[0].id
        edit.specialDays.remove(at: 1)
        edit.specialDays[0].day = 21
        edit.specialDays.append(DraftSpecialDay(label: "", month: 7, day: 7))
        try store.apply(edit, to: person)
        XCTAssertEqual(person.sortedSpecialDays.map(\.label), ["결혼기념일", ""])
        XCTAssertEqual(person.sortedSpecialDays.first?.uuid, keptID, "같은 줄은 고친다 — 새로 만들지 않는다")
        XCTAssertEqual(person.sortedSpecialDays.first?.day, 21)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SpecialDay>()), 2, "뺀 줄은 지운다")
    }

    func testBirthdayReminderMuteFollowsBirthday() throws {
        let context = try makeContainer().mainContext
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "생일 견본"
        draft.hasBirthday = true
        draft.birthMonth = 5
        draft.birthDay = 21
        draft.birthdayReminder = false
        let person = try store.create(draft)
        XCTAssertTrue(person.muteBirthdayReminder)
        XCTAssertFalse(PersonDraft(person: person).birthdayReminder)

        var edit = PersonDraft(person: person)
        edit.hasBirthday = false
        try store.apply(edit, to: person)
        XCTAssertFalse(person.muteBirthdayReminder, "생일을 지우면 끄기도 풀린다")
    }

    func testDeletingPersonDeletesSpecialDaysAndUndoBringsThemBack() throws {
        let context = try makeContainer().mainContext
        var draft = PersonDraft()
        draft.name = "지울 사람"
        draft.specialDays = [DraftSpecialDay(label: "결혼기념일", month: 6, day: 1, year: 2020)]
        let person = try PersonStore(context: context).create(draft)
        let undo = DeletionUndo.shared
        undo.finish()
        defer { undo.finish() }
        try undo.delete(person, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SpecialDay>()), 0, "사람과 함께 지운다")
        XCTAssertTrue(undo.undo())
        let back = try XCTUnwrap(try context.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(back.sortedSpecialDays.map(\.label), ["결혼기념일"], "되돌리면 기념일도 돌아온다")
        XCTAssertEqual(back.sortedSpecialDays.first?.year, 2020)
    }

    func testBackupRoundTripKeepsSpecialDaysAndMute() throws {
        let source = try makeContainer().mainContext
        var draft = PersonDraft()
        draft.name = "백업 견본"
        draft.hasBirthday = true
        draft.birthMonth = 1
        draft.birthDay = 2
        draft.birthdayReminder = false
        draft.specialDays = [DraftSpecialDay(label: "기일", month: 12, day: 1, remind: false)]
        _ = try PersonStore(context: source).create(draft)
        let file = Backup.makeFile(context: source)
        let data = try Backup.encode(file)
        let decoded = try Backup.decode(data)

        let target = try makeContainer().mainContext
        _ = try Backup.restore(decoded, into: target)
        let person = try XCTUnwrap(try target.fetch(FetchDescriptor<Person>()).first)
        XCTAssertTrue(person.muteBirthdayReminder)
        XCTAssertEqual(person.sortedSpecialDays.map(\.label), ["기일"])
        XCTAssertEqual(person.sortedSpecialDays.first?.remind, false)
    }

    // MARK: - 9판 → 10판

    /// 9판(App Store 1.1.2 ~ 1.1.6) 저장소 → 10판: 사람 · 생일이 남고, 기념일은 비어 있다가 넣을 수 있다.
    func testVersionNineStoreOpensAndTakesSpecialDays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v9.store")

        do {
            let schema = Schema(versionedSchema: SchemaV9.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV9.Person(name: "9판 친구")
            friend.birthMonth = 5
            friend.birthDay = 21
            context.insert(friend)
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let person = try XCTUnwrap(try context.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(person.name, "9판 친구")
        XCTAssertEqual(person.birthMonth, 5, "생일이 남는다")
        XCTAssertFalse(person.muteBirthdayReminder, "옮긴 직후 생일 알림은 켬")
        XCTAssertTrue(person.sortedSpecialDays.isEmpty)

        var draft = PersonDraft(person: person)
        draft.specialDays = [DraftSpecialDay(label: "결혼기념일", month: 10, day: 12)]
        try PersonStore(context: context).apply(draft, to: person)
        XCTAssertEqual(person.sortedSpecialDays.first?.label, "결혼기념일", "기념일을 넣을 수 있다")
    }
}
