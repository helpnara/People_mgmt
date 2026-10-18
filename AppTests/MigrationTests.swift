import SwiftData
import XCTest
@testable import SlowConnection

/// **1판 저장소가 2판으로 그대로 옮겨지는가** — 빌드 2 · 3 을 쓰던 기기가 업데이트하는 길이다.
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

        // 지금 판(2판)으로 연다 — 앱이 업데이트 뒤 하는 일과 같은 길.
        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(Set(people.map(\.name)), ["옛 판 사람", "소개받은 사람"])

        let introducer = try XCTUnwrap(people.first { $0.name == "옛 판 사람" })
        XCTAssertEqual(introducer.firstNote, "1판에서 적은 첫 인연")
        XCTAssertEqual(introducer.contactNote, "010-0000-0000")
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
}
