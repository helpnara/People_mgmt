import Core
import Foundation
import SwiftData
import XCTest
@testable import SlowConnection

/// 빌드 29 — 삭제 실행취소(FR-031) · 사람 사진(FR-012 · 7판) · 한 사람 내보내기(FR-014).
@MainActor
final class Build29Tests: XCTestCase {

    /// 컨테이너를 시험 동안 붙잡아 둔다 (빌드 27 CI).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    private func person(_ name: String, in context: ModelContext) throws -> Person {
        var draft = PersonDraft()
        draft.name = name
        return try PersonStore(context: context).create(draft)
    }

    private func record(_ title: String, with people: [Person], in context: ModelContext) throws -> Record {
        var draft = RecordDraft(anchor: people[0])
        draft.participants = people
        draft.title = title
        return try RecordStore(context: context).create(draft)
    }

    override func tearDown() {
        DeletionUndo.shared.finish()
        super.tearDown()
    }

    func testUndoBringsBackPersonWithSoleAndSharedRecordsAndTies() throws {
        let context = try makeContext()
        let a = try person("가", in: context)
        let b = try person("나", in: context)
        let c = try person("다", in: context)
        try PersonStore(context: context).link(a, b)
        _ = try record("혼자 점심", with: [a], in: context)
        _ = try record("함께 회의", with: [a, b], in: context)
        var introduced = PersonDraft(person: c)
        introduced.metThrough = RelationshipPresets.introducedLabel
        introduced.introducedBy = a
        try PersonStore(context: context).apply(introduced, to: c)

        let aID = a.uuid   // 지운 객체는 다시 읽지 않는다 — 지우기 전에.
        try DeletionUndo.shared.delete(a, in: context)
        XCTAssertNotNil(DeletionUndo.shared.pending, "되돌리기 알림이 뜬다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Person>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).count, 1, "혼자 기록은 함께 지워진다")
        XCTAssertNil(c.introducedBy)

        XCTAssertTrue(DeletionUndo.shared.undo())
        XCTAssertNil(DeletionUndo.shared.pending, "되돌리면 알림이 내려간다")
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 3)
        let back = try XCTUnwrap(people.first { $0.name == "가" })
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).count, 2, "혼자 기록도 돌아온다")
        XCTAssertEqual(Set(RecordStore.timeline(of: back).map(\.displayTitle)), ["혼자 점심", "함께 회의"])
        XCTAssertEqual(back.acquaintances.map(\.name), ["나"], "아는 사이가 돌아온다")
        XCTAssertEqual(c.introducedBy?.uuid, back.uuid, "소개자 칸이 돌아온다")
        XCTAssertEqual(back.uuid, aID, "같은 uuid 로 돌아온다")
        XCTAssertFalse(context.hasChanges, "되돌린 뒤 저장까지 했다")
    }

    func testUndoBringsBackRecordAndLaterEditsAreNotUndone() throws {
        let context = try makeContext()
        let a = try person("가", in: context)
        let b = try person("나", in: context)
        let shared = try record("함께 회의", with: [a, b], in: context)

        try DeletionUndo.shared.delete(shared, in: context)
        // 5초 사이의 다른 고침은 되돌리기에 섞이지 않는다.
        var edit = PersonDraft(person: b)
        edit.organization = "새 소속"
        try PersonStore(context: context).apply(edit, to: b)

        XCTAssertTrue(DeletionUndo.shared.undo())
        XCTAssertEqual(try context.fetch(FetchDescriptor<Record>()).first?.participants?.count, 2)
        XCTAssertEqual(b.organization, "새 소속", "다른 고침은 그대로")
    }

    func testPhotoIsSavedAndBackedUp() throws {
        let context = try makeContext()
        let photo = try XCTUnwrap(SampleData.renderPortrait(background: 0xE4F0EC, figure: 0x2F6B5E))
        var draft = PersonDraft()
        draft.name = "가"
        draft.photo = photo
        let saved = try PersonStore(context: context).create(draft)
        XCTAssertEqual(saved.photo, photo)
        XCTAssertEqual(PersonDraft(person: saved).photo, photo)

        let decoded = try Backup.decode(Backup.encode(Backup.makeFile(context: context)))
        XCTAssertEqual(decoded.people.first?.photo, photo)

        var removed = PersonDraft(person: saved)
        removed.photo = nil
        try PersonStore(context: context).apply(removed, to: saved)
        XCTAssertNil(saved.photo)
    }

    func testPersonExportMarkdownAndPDF() throws {
        let context = try makeContext()
        let a = try person("가", in: context)
        let b = try person("나", in: context)
        _ = try record("함께 회의", with: [a, b], in: context)

        let value = PersonExporter.value(of: a, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(value.records.count, 1)
        XCTAssertEqual(value.records.first?.companions, ["나"], "보고 있는 사람은 함께한 사람에서 뺀다")
        let markdown = PersonExport.markdown(value)
        XCTAssertTrue(markdown.hasPrefix("# 가\n"))

        let mdURL = try PersonExporter.write(markdown, name: a.name, format: .markdown)
        XCTAssertEqual(try String(contentsOf: mdURL, encoding: .utf8), markdown)
        let pdfURL = try PersonExporter.write(markdown, name: "가/나", format: .pdf)
        XCTAssertFalse(pdfURL.lastPathComponent.contains("/"))
        let pdf = try Data(contentsOf: pdfURL)
        XCTAssertEqual(String(data: pdf.prefix(4), encoding: .ascii), "%PDF")
    }

    func testVersionSixStoreOpensWithoutPhoto() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v6.store")

        do {
            let schema = Schema(versionedSchema: SchemaV6.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let old = try ModelContainer(for: schema, configurations: [configuration])
            let friend = SchemaV6.Person(name: "6판 친구")
            friend.firstMetPrecision = 1
            old.mainContext.insert(friend)
            try old.mainContext.save()
        }

        let opened = try Persistence.makeContainer(inMemory: false, url: url)
        let friend = try XCTUnwrap(try opened.mainContext.fetch(FetchDescriptor<Person>()).first)
        XCTAssertEqual(friend.firstMetPrecision, 1, "6판 칸이 남는다")
        XCTAssertNil(friend.photo, "옮긴 직후 사진은 없다")
    }
}
