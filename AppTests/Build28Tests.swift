import Core
import Foundation
import SwiftData
import XCTest
@testable import SlowConnection

/// 빌드 28 — 대략 날짜(FR-033 · 스키마 6판). 기댓값은 Core 규칙(`ApproximateDate`)이 낸다.
@MainActor
final class Build28Tests: XCTestCase {

    /// 컨테이너를 시험 동안 붙잡아 둔다 (빌드 27 CI — 문맥만 돌려주면 컨테이너가 먼저 풀린다).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    func testFirstMetAndRecordKeepPrecision() throws {
        let context = try makeContext()
        let picked = Date(timeIntervalSince1970: 1_614_816_000) // 2021-03-04 쯤 — 접는 규칙은 Core 가 낸다
        var draft = PersonDraft()
        draft.name = "가"
        draft.hasFirstMetDate = true
        draft.firstMetDate = picked
        draft.firstMetPrecision = .year
        let person = try PersonStore(context: context).create(draft)
        XCTAssertEqual(person.firstMetPrecision, DatePrecision.year.rawValue)
        XCTAssertEqual(person.firstMetDate, ApproximateDate.noon(of: picked, precision: .year, calendar: .current))
        XCTAssertEqual(PersonDraft(person: person).firstMetPrecision, .year, "수정 화면이 정밀도를 다시 읽는다")

        var record = RecordDraft(anchor: person)
        record.title = "점심"
        record.occurredAt = picked
        record.occurredPrecision = .month
        let saved = try RecordStore(context: context).create(record)
        XCTAssertEqual(saved.occurredPrecision, DatePrecision.month.rawValue)
        XCTAssertEqual(saved.occurredAt, ApproximateDate.noon(of: picked, precision: .month, calendar: .current))

        // 처음 만난 날을 끄면 정밀도도 날짜까지로 돌아간다.
        var off = PersonDraft(person: person)
        off.hasFirstMetDate = false
        try PersonStore(context: context).apply(off, to: person)
        XCTAssertNil(person.firstMetDate)
        XCTAssertEqual(person.firstMetPrecision, DatePrecision.day.rawValue)
    }

    func testBackupCarriesPrecisionAndOldBackupsReadAsDay() throws {
        let context = try makeContext()
        var draft = PersonDraft()
        draft.name = "가"
        draft.hasFirstMetDate = true
        draft.firstMetPrecision = .month
        let person = try PersonStore(context: context).create(draft)
        var record = RecordDraft(anchor: person)
        record.title = "회의"
        record.occurredPrecision = .year
        _ = try RecordStore(context: context).create(record)

        let file = Backup.makeFile(context: context)
        let decoded = try Backup.decode(Backup.encode(file))
        XCTAssertEqual(decoded.people.first?.firstMetPrecision, DatePrecision.month.rawValue)
        XCTAssertEqual(decoded.records.first?.occurredPrecision, DatePrecision.year.rawValue)

        // 옛 백업(빌드 27 까지)에는 칸이 없다 — 날짜까지로 되살린다.
        var old = decoded
        old.people = old.people.map { var item = $0; item.firstMetPrecision = nil; return item }
        old.records = old.records.map { var item = $0; item.occurredPrecision = nil; return item }
        let fresh = try Persistence.makeContainer(inMemory: true)
        _ = try Backup.restore(old, into: fresh.mainContext)
        let restored = try XCTUnwrap(try fresh.mainContext.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(restored.firstMetPrecision, DatePrecision.day.rawValue)
        XCTAssertEqual(try fresh.mainContext.fetch(FetchDescriptor<Record>()).first?.occurredPrecision, DatePrecision.day.rawValue)
    }

    func testVersionFiveStoreOpensWithDayPrecision() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v5.store")

        do {
            let schema = Schema(versionedSchema: SchemaV5.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let old = try ModelContainer(for: schema, configurations: [configuration])
            let context = old.mainContext
            let friend = SchemaV5.Person(name: "5판 친구")
            friend.birthMonth = 5
            friend.birthDay = 21
            friend.firstMetDate = Date(timeIntervalSince1970: 1_600_000_000)
            context.insert(friend)
            let record = SchemaV5.Record(recordType: "meal", title: "5판 점심")
            context.insert(record)
            record.participants = [friend]
            try context.save()
        }

        let opened = try Persistence.makeContainer(inMemory: false, url: url)
        let context = opened.mainContext
        let friend = try XCTUnwrap(try context.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(friend.birthMonth, 5, "5판 칸이 남는다")
        XCTAssertNotNil(friend.firstMetDate)
        XCTAssertEqual(friend.firstMetPrecision, DatePrecision.day.rawValue, "옛 자료는 날짜까지")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).first?.occurredPrecision, DatePrecision.day.rawValue)
    }
}
