import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **이슈 117 (스키마 13판 · D-81)** — 안 만난 약속을 지우지 않고 남긴다. 남긴 기록은 만남을 세는 곳에서 빠진다
/// (마지막 기록 · 예정된 만남 판정). 다른 날로 다시 잡으면 원래 기록은 남고 같은 내용의 새 약속이 생긴다.
/// 백업 왕복 · 12판 → 13판 옮기기도 본다.
@MainActor
final class Issue117Tests: XCTestCase {

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

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    /// 열흘 전에 미리 적어 둔, 사흘 전 약속 — 결과를 적을 만남이다.
    private func plannedPast(for friend: Person, in context: ModelContext) throws -> Record {
        var draft = RecordDraft(anchor: friend)
        draft.title = "저녁 약속"
        draft.location = "역 앞"
        draft.tags = ["식사"]
        draft.occurredAt = daysAgo(3)
        let record = try RecordStore(context: context).create(draft)
        record.createdAt = daysAgo(10)
        record.updatedAt = daysAgo(10)
        try context.save()
        return record
    }

    func testNotMetRecordStaysButStopsCounting() throws {
        let context = try makeContainer().mainContext
        let friend = try person("약속 견본", in: context)
        let record = try plannedPast(for: friend, in: context)
        XCTAssertTrue(record.isAwaitingResult, "미리 적은 지난 약속은 결과를 적을 만남")
        XCTAssertNotNil(friend.lastRecordAt)

        try RecordStore(context: context).setDidNotMeet(record, true)
        XCTAssertTrue(record.didNotMeet)
        XCTAssertFalse(record.countsAsMeeting)
        XCTAssertFalse(record.isAwaitingResult, "안 만난 약속은 결과를 적을 만남에서 빠진다")
        XCTAssertFalse(record.isUpcoming)
        XCTAssertNil(friend.lastRecordAt, "안 만난 약속은 마지막 기록이 아니다")
        XCTAssertEqual(RecordStore.timeline(of: friend).map(\.uuid), [record.uuid], "타임라인에는 남는다")

        try RecordStore(context: context).setDidNotMeet(record, false)
        XCTAssertFalse(record.didNotMeet)
        XCTAssertFalse(record.isAwaitingResult, "되돌리면 그날 이후 고친 기록 — 만난 기록이 된다")
        XCTAssertNotNil(friend.lastRecordAt)
    }

    func testRescheduleKeepsOriginalAndMakesNewPlan() throws {
        let context = try makeContainer().mainContext
        let friend = try person("다시 잡기 견본", in: context)
        let other = try person("함께 간 견본", in: context)
        let record = try plannedPast(for: friend, in: context)
        record.participants = [friend, other]
        record.repeatRule = RepeatRule.weekly.rawValue
        try context.save()

        let target = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let copy = try RecordStore(context: context).reschedule(record, to: target, minute: 19 * 60)

        XCTAssertTrue(record.didNotMeet, "원래 기록은 안 만난 약속으로 남는다")
        XCTAssertFalse(copy.didNotMeet)
        XCTAssertNotEqual(copy.uuid, record.uuid)
        XCTAssertEqual(copy.title, "저녁 약속")
        XCTAssertEqual(copy.location, "역 앞")
        XCTAssertEqual(copy.tags, ["식사"])
        XCTAssertEqual(Set((copy.participants ?? []).map(\.uuid)), Set([friend.uuid, other.uuid]))
        XCTAssertEqual(copy.occurredMinute, 19 * 60)
        XCTAssertEqual(DayIndex.of(copy.occurredAt), DayIndex.of(target))
        XCTAssertEqual(copy.repeatRule, 0, "반복은 원래 회차가 이어 간다 — 새 약속에는 두지 않는다")
        XCTAssertTrue(copy.isUpcoming, "새 약속은 다가오는 만남")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Record>()), 2)
    }

    func testBackupCarriesNotMet() throws {
        let context = try makeContainer().mainContext
        let friend = try person("백업 견본", in: context)
        let record = try plannedPast(for: friend, in: context)
        try RecordStore(context: context).setDidNotMeet(record, true)

        let item = Backup.item(of: record)
        XCTAssertEqual(item.didNotMeet, true)
        let restored = Record(recordType: item.recordType)
        context.insert(restored)
        Backup.fill(restored, from: item)
        XCTAssertTrue(restored.didNotMeet)

        let plain = try RecordStore(context: context).create({
            var draft = RecordDraft(anchor: friend)
            draft.title = "보통 기록"
            return draft
        }())
        XCTAssertNil(Backup.item(of: plain).didNotMeet, "만난 기록은 칸을 비운다 — 옛 백업과 같은 모양")
    }

    // MARK: - 12판 → 13판

    /// 12판(빌드 62 ~ 75) 저장소 → 13판: 사람 · 기록 · 반복이 남고, 안 만남 칸은 꺼진 채 시작한다.
    func testVersionTwelveStoreOpensWithNotMetOff() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v12.store")

        do {
            let schema = Schema(versionedSchema: SchemaV12.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV12.Person(name: "12판 친구")
            context.insert(friend)
            let record = SchemaV12.Record(title: "12판 기록")
            record.repeatRule = 1
            context.insert(record)
            record.participants = [friend]
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<Record>()).first)
        XCTAssertEqual(record.title, "12판 기록")
        XCTAssertEqual((record.participants ?? []).map(\.name), ["12판 친구"])
        XCTAssertEqual(record.repeatRule, 1)
        XCTAssertFalse(record.didNotMeet)
        XCTAssertTrue(record.countsAsMeeting)
    }
}
