import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **1.1.1 (빌드 45 · 스키마 9판)** — 기록 사진(FR-058 · D-65)과 내 선택지(FR-035 · D-66)의 저장 규칙.
/// 사진은 진짜 JPEG 이 아니어도 된다 — 저장 규칙만 본다(줄이기는 화면에서 · `RecordPhotos.normalized`).
@MainActor
final class Build45Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func makeContainer() throws -> ModelContainer {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        return container
    }

    private func person(_ name: String, in context: ModelContext) throws -> Person {
        var draft = PersonDraft()
        draft.name = name
        return try PersonStore(context: context).create(draft)
    }

    private func photo(_ byte: UInt8) -> DraftPhoto { DraftPhoto(data: Data([0xFF, 0xD8, byte])) }

    // MARK: - 기록 사진

    func testRecordKeepsPhotosInOrder() throws {
        let context = try makeContainer().mainContext
        let owner = try person("사진 주인", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "사진 있는 점심"
        draft.photos = [photo(1), photo(2)]
        let record = try RecordStore(context: context).create(draft)

        XCTAssertEqual(record.sortedPhotos.compactMap(\.data), [Data([0xFF, 0xD8, 1]), Data([0xFF, 0xD8, 2])], "고른 차례대로")
        XCTAssertEqual(record.sortedPhotos.map(\.position), [0, 1])
        XCTAssertTrue(record.hasPhotos)
        XCTAssertEqual(RecordDraft(record: record).photos.map(\.id), record.sortedPhotos.map(\.uuid), "초안은 번호만 든다")
        XCTAssertTrue(RecordDraft(record: record).photos.allSatisfy { $0.data == nil }, "저장된 사진의 파일을 초안에 읽지 않는다")
    }

    func testEditingPhotosKeepsUntouchedOnesAndDropsRemoved() throws {
        let context = try makeContainer().mainContext
        let owner = try person("고치는 사람", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "넉 장"
        draft.photos = [photo(1), photo(2), photo(3)]
        let records = RecordStore(context: context)
        let record = try records.create(draft)
        let kept = record.sortedPhotos[1].uuid

        var changed = RecordDraft(record: record)
        changed.photos.remove(at: 0)                 // 첫 장을 빼고
        changed.photos.append(photo(9))              // 새 사진을 끝에
        try records.apply(changed, to: record)

        XCTAssertEqual(record.sortedPhotos.count, 3)
        XCTAssertEqual(record.sortedPhotos.first?.uuid, kept, "건드리지 않은 사진은 그대로(번호가 같다) — 다시 올리지 않는다")
        XCTAssertEqual(record.sortedPhotos.map(\.position), [0, 1, 2], "차례를 다시 매긴다")
        XCTAssertEqual(record.sortedPhotos.last?.data, Data([0xFF, 0xD8, 9]))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordPhoto>()), 3, "뺀 사진은 저장소에서도 지운다")
    }

    func testAtMostFourPhotos() throws {
        let context = try makeContainer().mainContext
        let owner = try person("많이 고른 사람", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "다섯 장"
        draft.photos = (1...5).map { photo(UInt8($0)) }
        let record = try RecordStore(context: context).create(draft)
        XCTAssertEqual(RecordPhotos.limit, 4)
        XCTAssertEqual(record.sortedPhotos.count, 4, "넉 장까지만")
    }

    func testDeletingRecordDeletesPhotosAndUndoBringsThemBack() throws {
        let context = try makeContainer().mainContext
        let owner = try person("지우는 사람", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "지울 기록"
        draft.photos = [photo(1), photo(2)]
        let record = try RecordStore(context: context).create(draft)
        let id = record.uuid

        try DeletionUndo.shared.delete(record, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordPhoto>()), 0, "기록을 지우면 사진도 지운다")

        XCTAssertTrue(DeletionUndo.shared.undo())
        let back = try XCTUnwrap(try context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.uuid == id })).first)
        XCTAssertEqual(back.sortedPhotos.compactMap(\.data), [Data([0xFF, 0xD8, 1]), Data([0xFF, 0xD8, 2])], "되돌리면 사진도 차례대로")
    }

    func testDeletingPersonDeletesPhotosOfSoleRecordsOnly() throws {
        let context = try makeContainer().mainContext
        let a = try person("가", in: context)
        let b = try person("나", in: context)
        let records = RecordStore(context: context)
        var sole = RecordDraft(anchor: a)
        sole.title = "혼자"
        sole.photos = [photo(1)]
        _ = try records.create(sole)
        var shared = RecordDraft(anchor: a)
        shared.title = "함께"
        shared.participants = [a, b]
        shared.photos = [photo(2)]
        let together = try records.create(shared)

        try PersonStore(context: context).delete(a)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordPhoto>()), 1, "공동 기록의 사진은 남는다")
        XCTAssertEqual(together.sortedPhotos.first?.data, Data([0xFF, 0xD8, 2]))
    }

    func testDataWipeRemovesPhotosButKeepsChoices() throws {
        let context = try makeContainer().mainContext
        let owner = try person("다 지우기", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "사진"
        draft.photos = [photo(1)]
        _ = try RecordStore(context: context).create(draft)
        try ChoiceStore.save(.relationshipType, items: ["친구", "동료"], hidden: ["고객"], in: context)

        _ = try DataWipe.wipe(into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordPhoto>()), 0)
        XCTAssertNotNil(ChoiceStore.setting(.relationshipType, in: context), "내 선택지는 설정이라 둔다")
    }

    // MARK: - 내 선택지

    func testChoiceSettingSavesAndFeedsTheChips() throws {
        let context = try makeContainer().mainContext
        XCTAssertNil(ChoiceStore.setting(.relationshipType, in: context), "처음엔 정한 것이 없다")
        XCTAssertEqual(ChoiceStore.choices(.relationshipType, used: [], in: context), RelationshipPresets.relationshipTypes)

        try ChoiceStore.save(.relationshipType, items: ["친구", "선배"], hidden: ["고객"], in: context)
        let chips = ChoiceStore.choices(.relationshipType, used: ["고객", "거래처"], in: context)
        XCTAssertEqual(Array(chips.prefix(2)), ["친구", "선배"], "내가 정한 차례가 앞")
        XCTAssertFalse(chips.contains("고객"), "숨긴 것은 쓴 사람이 있어도 칩에 없다")
        XCTAssertEqual(chips.last, "거래처", "직접 입력해 쓴 값은 끝에")
        XCTAssertEqual(ChoiceStore.choices(.metThrough, used: [], in: context), RelationshipPresets.metThroughOptions, "다른 종류는 그대로")

        try ChoiceStore.reset(.relationshipType, in: context)
        XCTAssertNil(ChoiceStore.setting(.relationshipType, in: context), "처음 선택지로")
    }

    /// 아이폰 · 아이패드가 따로 만들어 둘이 된 경우 — 늦게 고친 것을 쓰고, 고칠 때 하나로 줄인다.
    func testDuplicateChoiceListsResolveToLatest() throws {
        let context = try makeContainer().mainContext
        let older = ChoiceList(kind: ChoiceKind.relationshipType.rawValue)
        context.insert(older)
        older.items = ["옛것"]
        older.updatedAt = Date(timeIntervalSince1970: 1_000)
        let newer = ChoiceList(kind: ChoiceKind.relationshipType.rawValue)
        context.insert(newer)
        newer.items = ["새것"]
        newer.updatedAt = Date(timeIntervalSince1970: 2_000)
        try context.save()

        XCTAssertEqual(ChoiceStore.setting(.relationshipType, in: context)?.items, ["새것"])
        try ChoiceStore.save(.relationshipType, items: ["고친 것"], hidden: [], in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChoiceList>()), 1, "고칠 때 하나로")
        XCTAssertEqual(ChoiceStore.setting(.relationshipType, in: context)?.items, ["고친 것"])
    }

    func testFailedChoiceSaveKeepsOldValues() throws {
        let context = try makeContainer().mainContext
        try ChoiceStore.save(.metThrough, items: ["학교"], hidden: [], in: context)
        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try ChoiceStore.save(.metThrough, items: ["바뀜"], hidden: [], in: context))
        XCTAssertEqual(ChoiceStore.setting(.metThrough, in: context)?.items, ["학교"], "실패하면 옛 값")
    }

    // MARK: - 한 해 돌아보기 · 견본

    /// 재료(`YearReviewData`)가 저장소의 기록을 해마다 빠짐없이 센다 — 오늘까지의 기록만.
    func testYearReviewDataCountsEveryPastRecordOfEachYear() throws {
        let container = try makeContainer()
        let context = container.mainContext
        SampleData.seed(into: context, communities: false, planned: true)
        try context.save()
        let data = YearReviewData.make(context: context)
        let calendar = Calendar.current
        let today = DayIndex.of(Date())
        let records = try context.fetch(FetchDescriptor<Record>())
        XCTAssertTrue(data.years.contains(calendar.component(.year, from: Date())), "올해는 늘 고를 수 있다")
        for year in data.years {
            let expected = records.filter {
                calendar.component(.year, from: $0.occurredAt) == year && DayIndex.of($0.occurredAt) <= today
            }.count
            XCTAssertEqual(data.summary(of: year).recordCount, expected, "\(year)년 기록 수")
        }
        let total = data.years.reduce(0) { $0 + data.summary(of: $1).recordCount }
        XCTAssertEqual(total, records.filter { DayIndex.of($0.occurredAt) <= today }.count, "예정된 만남은 빼고 모두")
    }

    func testSampleTripHasTwoPhotos() throws {
        let context = try makeContainer().mainContext
        SampleData.seed(into: context, communities: false, planned: false)
        try context.save()
        let trip = try XCTUnwrap(try context.fetch(FetchDescriptor<Record>()).first { $0.recordType == "trip" })
        XCTAssertEqual(trip.sortedPhotos.count, 2, "CI 스크린샷 44 의 견본")
        XCTAssertEqual(trip.displayTitle, "봄 산행. 지리산 둘레길 2코스.", "스크린샷이 이 이름으로 연다")
    }

    // MARK: - 백업

    func testBackupCarriesRecordPhotosAndChoices() async throws {
        let source = try makeContainer()
        let context = source.mainContext
        let owner = try person("백업 주인", in: context)
        var draft = RecordDraft(anchor: owner)
        draft.title = "사진 둘"
        draft.photos = [photo(1), photo(2)]
        let record = try RecordStore(context: context).create(draft)
        try ChoiceStore.save(.metThrough, items: ["교회", "직장"], hidden: ["온라인"], in: context)

        let file = try Backup.decode(Backup.encode(Backup.makeFile(context: context)))
        XCTAssertEqual(Backup.summary(of: file).recordPhotos, 2)

        let target = try makeContainer()
        let summary = try await Backup.restore(file, container: target)
        XCTAssertEqual(summary.recordPhotos, 2)
        let restored = try XCTUnwrap(try target.mainContext.fetch(FetchDescriptor<Record>()).first)
        XCTAssertEqual(restored.uuid, record.uuid)
        XCTAssertEqual(restored.sortedPhotos.compactMap(\.data), [Data([0xFF, 0xD8, 1]), Data([0xFF, 0xD8, 2])], "기록 사진이 차례대로")
        let choices = ChoiceStore.setting(.metThrough, in: target.mainContext)
        XCTAssertEqual(choices?.items, ["교회", "직장"])
        XCTAssertEqual(choices?.hidden, ["온라인"])
    }

    /// 9판 전의 백업(사진 · 선택지 칸 없음)도 읽는다.
    func testOldBackupWithoutPhotosStillRestores() throws {
        let json = """
        {"format":"slow-connection-backup","version":1,"exportedAt":"2026-10-01T00:00:00.000Z",
         "people":[{"uuid":"00000000-0000-0000-0000-000000000001","name":"옛 사람","isMe":false,"tags":[],
                    "createdAt":"2026-10-01T00:00:00.000Z","updatedAt":"2026-10-01T00:00:00.000Z"}],
         "records":[{"uuid":"00000000-0000-0000-0000-000000000002","recordType":"meal","occurredAt":"2026-09-30T03:00:00.000Z",
                     "title":"옛 점심","tags":[],"participants":["00000000-0000-0000-0000-000000000001"],
                     "createdAt":"2026-10-01T00:00:00.000Z","updatedAt":"2026-10-01T00:00:00.000Z"}],
         "ties":[]}
        """
        let file = try Backup.decode(Data(json.utf8))
        let target = try makeContainer()
        let summary = try Backup.restore(file, into: target.mainContext)
        XCTAssertEqual(summary.records, 1)
        XCTAssertEqual(summary.recordPhotos, 0)
        XCTAssertNil(ChoiceStore.setting(.metThrough, in: target.mainContext))
    }

    // MARK: - 8판 → 9판

    /// 8판(App Store 1.1) 저장소 → 9판: 사람 · 기록 · 시각이 남고, 사진 · 선택지는 비어 있다가 넣을 수 있다.
    func testVersionEightStoreOpensAndTakesPhotos() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v8.store")

        do {
            let schema = Schema(versionedSchema: SchemaV8.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV8.Person(name: "8판 친구")
            context.insert(friend)
            let record = SchemaV8.Record(recordType: "meal", title: "8판 점심")
            record.occurredMinute = 750
            context.insert(record)
            record.participants = [friend]
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<Record>()).first)
        XCTAssertEqual(record.displayTitle, "8판 점심")
        XCTAssertEqual(record.occurredMinute, 750, "시각이 남는다")
        XCTAssertEqual(record.participants?.first?.name, "8판 친구")
        XCTAssertFalse(record.hasPhotos, "옮긴 직후 사진은 없다")
        XCTAssertNil(ChoiceStore.setting(.relationshipType, in: context))

        var draft = RecordDraft(record: record)
        draft.photos = [photo(7)]
        try RecordStore(context: context).apply(draft, to: record)
        XCTAssertEqual(record.sortedPhotos.first?.data, Data([0xFF, 0xD8, 7]), "사진을 붙일 수 있다")
    }
}
