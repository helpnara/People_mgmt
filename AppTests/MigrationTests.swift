import SwiftData
import XCTest
@testable import SlowConnection

/// **옛 판 저장소가 지금 판(4판)으로 그대로 옮겨지는가** — 빌드 2 · 3(1판), 빌드 4 ~ 6(2판), 빌드 7 ~ 9(3판)을 쓰던 기기가 업데이트하는 길이다.
/// 자료 유실은 이 앱에서 가장 비싼 실패라, 디스크에 진짜 1판 저장소를 만들어 지금 판으로 연다.
@MainActor
final class MigrationTests: XCTestCase {

    func testVersionOneStoreOpensWithCurrentSchemaWithoutLosingAnything() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v1.store")

        // 1판으로 쓰고 닫는다.
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let introducer = SchemaV1.Person(name: "옛 판 사람")
            introducer.firstNote = "1판에서 적은 첫 인연"
            introducer.contactNote = "010-0000-0000"
            introducer.tags = ["옛판"]
            let newcomer = SchemaV1.Person(name: "소개받은 사람")
            context.insert(introducer)
            context.insert(newcomer)
            newcomer.metThrough = "소개"
            newcomer.introducedBy = introducer
            let record = SchemaV1.Record(recordType: "meal", title: "함께 점심", note: "1판 기록")
            context.insert(record)
            record.participants = [introducer, newcomer]
            try context.save()
        }

        // 지금 판(4판)으로 연다 — 앱이 업데이트 뒤 하는 일과 같은 길.
        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(Set(people.map(\.name)), ["옛 판 사람", "소개받은 사람"])

        let introducer = try XCTUnwrap(people.first { $0.name == "옛 판 사람" })
        XCTAssertEqual(introducer.firstNote, "1판에서 적은 첫 인연")
        // 3판으로 옮기며 한 칸의 연락 수단이 칸으로 나뉜다 — 010 으로 시작하니 휴대전화 (이슈 11).
        XCTAssertEqual(introducer.mobilePhone, "010-0000-0000")
        XCTAssertNil(introducer.contactNote, "나눈 뒤 기타 칸은 비었다")
        XCTAssertFalse(introducer.isMe)
        XCTAssertEqual(introducer.tags, ["옛판"])
        XCTAssertNil(introducer.businessCard, "새 칸은 비어 있다")

        let newcomer = try XCTUnwrap(people.first { $0.name == "소개받은 사람" })
        XCTAssertTrue(newcomer.introducedBy === introducer, "소개 관계가 남는다")

        let records = try context.fetch(FetchDescriptor<Record>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.note, "1판 기록")
        XCTAssertEqual(records.first?.participants?.count, 2, "공동 기록의 참여자가 남는다")

        // 옮긴 뒤 새 칸에 쓸 수 있다.
        introducer.businessCard = Data([0xFF, 0xD8, 0xFF])
        try context.save()
        XCTAssertEqual(introducer.businessCard, Data([0xFF, 0xD8, 0xFF]))
    }

    /// **2판 → 3판** (이슈 11 · 12). 한 칸에 들어 있던 연락 수단이 네 칸으로 나뉘고, 나누지 못한 글은 기타에 남는다.
    /// 나눔 규칙 자체는 Core 정답표(`contactSplit`)가 대조한다. 여기는 옮기기가 그 규칙을 실제로 부르고 저장하는지 본다.
    func testVersionTwoStoreSplitsContactNoteIntoFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v2.store")

        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let split = SchemaV2.Person(name: "나눌 사람")
            split.contactNote = "010-1234-5678 · haneul@example.com · 02-555-0101"
            let kept = SchemaV2.Person(name: "남길 사람")
            kept.contactNote = "본가 031-123-4567"
            let card = SchemaV2.Person(name: "명함 사람")
            card.businessCard = Data([0xFF, 0xD8, 0xFF])
            context.insert(split)
            context.insert(kept)
            context.insert(card)
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let people = try container.mainContext.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 3)

        let split = try XCTUnwrap(people.first { $0.name == "나눌 사람" })
        XCTAssertEqual(split.mobilePhone, "010-1234-5678")
        XCTAssertEqual(split.email, "haneul@example.com")
        XCTAssertEqual(split.officePhone, "02-555-0101")
        XCTAssertNil(split.faxNumber)
        XCTAssertNil(split.contactNote)

        let kept = try XCTUnwrap(people.first { $0.name == "남길 사람" })
        XCTAssertEqual(kept.contactNote, "본가 031-123-4567", "알아보지 못한 글은 기타에 그대로")
        XCTAssertNil(kept.mobilePhone)

        let card = try XCTUnwrap(people.first { $0.name == "명함 사람" })
        XCTAssertEqual(card.businessCard, Data([0xFF, 0xD8, 0xFF]), "명함 사진이 남는다")
        XCTAssertTrue(people.allSatisfy { !$0.isMe }, "옛 판 사람은 나가 아니다")
    }

    /// **3판 → 4판** (D-30). 나 · 연락 칸 · 기록 · 소개가 그대로 남고, 아는 사이 연결을 새로 만들 수 있다.
    func testVersionThreeStoreOpensAndAcceptsTies() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v3.store")

        do {
            let schema = Schema(versionedSchema: SchemaV3.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let me = SchemaV3.Person(name: "3판의 나")
            me.isMe = true
            let friend = SchemaV3.Person(name: "3판 친구")
            friend.mobilePhone = "010-1111-2222"
            let other = SchemaV3.Person(name: "3판 동료")
            context.insert(me)
            context.insert(friend)
            context.insert(other)
            other.metThrough = "소개"
            other.introducedBy = friend
            let record = SchemaV3.Record(recordType: "meal", title: "3판 점심")
            context.insert(record)
            record.participants = [friend, other]
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 3)
        let me = try XCTUnwrap(people.first { $0.isMe }, "나가 남는다")
        XCTAssertEqual(me.name, "3판의 나")
        let friend = try XCTUnwrap(people.first { $0.name == "3판 친구" })
        let other = try XCTUnwrap(people.first { $0.name == "3판 동료" })
        XCTAssertEqual(friend.mobilePhone, "010-1111-2222", "연락 칸이 남는다")
        XCTAssertTrue(other.introducedBy === friend, "소개가 남는다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).first?.participants?.count, 2, "기록 참여자가 남는다")
        XCTAssertTrue(friend.acquaintances.isEmpty, "옮긴 직후에는 아는 사이가 없다")

        let store = PersonStore(context: context)
        var edit = PersonDraft(person: friend)
        edit.acquaintances = [other]
        try store.apply(edit, to: friend)
        XCTAssertEqual(other.acquaintances.map(\.name), ["3판 친구"], "4판에서 아는 사이를 만들 수 있다")
    }

    /// 4판(빌드 10 ~ 17) 저장소가 5판으로 열리고, 새 칸(생일 · 연락 주기)은 비어 있다가 저장할 수 있다 (D-40).
    func testVersionFourStoreOpensWithEmptyBirthdayAndCadence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v4.store")

        do {
            let schema = Schema(versionedSchema: SchemaV4.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV4.Person(name: "4판 친구")
            friend.mobilePhone = "010-3333-4444"
            let other = SchemaV4.Person(name: "4판 동료")
            context.insert(friend)
            context.insert(other)
            let tie = SchemaV4.Tie()
            context.insert(tie)
            tie.first = friend
            tie.second = other
            let record = SchemaV4.Record(recordType: "meal", title: "4판 점심")
            context.insert(record)
            record.participants = [friend, other]
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 2)
        let friend = try XCTUnwrap(people.first { $0.name == "4판 친구" })
        XCTAssertEqual(friend.mobilePhone, "010-3333-4444", "연락 칸이 남는다")
        XCTAssertEqual(friend.acquaintances.map(\.name), ["4판 동료"], "아는 사이가 남는다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).first?.participants?.count, 2, "기록 참여자가 남는다")
        XCTAssertNil(friend.birthMonth, "옮긴 직후 생일은 비어 있다")
        XCTAssertNil(friend.contactCadenceMonths)

        var edit = PersonDraft(person: friend)
        edit.hasBirthday = true
        edit.birthMonth = 2
        edit.birthDay = 29
        edit.contactCadenceMonths = 6
        try PersonStore(context: context).apply(edit, to: friend)
        XCTAssertEqual(friend.birthMonth, 2)
        XCTAssertEqual(friend.birthDay, 29, "연도를 모르면 2월 29일을 받는다")
        XCTAssertNil(friend.birthYear)
        XCTAssertEqual(friend.contactCadenceMonths, 6)

        edit.birthYear = 2023   // 평년 — 2월 29일은 없는 날
        try PersonStore(context: context).apply(edit, to: friend)
        XCTAssertNil(friend.birthMonth, "없는 날은 저장하지 않는다")
    }
}
