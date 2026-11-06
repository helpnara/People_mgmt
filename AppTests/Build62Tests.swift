import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **1.1.9 (빌드 62 · 스키마 12판)** — 반복 약속의 다음 회차(FR-069) · 기록 틀(FR-070) · 고쳐 둔 모임 이름(FR-071)의 저장 규칙,
/// 백업 왕복, 11판 → 12판 옮기기. 날짜 셈 · 이름 고르기의 값은 Core 정답표(`repeatRule` · `savedCommunityName`)가 본다 —
/// 여기서는 저장소에 몇 개가 생기고 무엇이 옮겨 가는지만 본다.
@MainActor
final class Build62Tests: XCTestCase {

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

    private func daysAgo(_ days: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
    }

    // MARK: - 반복 약속 (FR-069)

    func testDueRepeatSpawnsOneNextOccurrenceAndOnlyOnce() throws {
        let context = try makeContainer().mainContext
        let friend = try person("반복 견본", in: context)
        let store = RecordStore(context: context)
        let now = Date()
        var draft = RecordDraft(anchor: friend)
        draft.title = "주간 산책"
        draft.location = "호숫가"
        draft.tags = ["운동"]
        draft.occurredAt = daysAgo(8, from: now)
        draft.repeatRule = .weekly
        let first = try store.create(draft)
        XCTAssertEqual(first.repeatRule, RepeatRule.weekly.rawValue)
        XCTAssertNotNil(first.repeatSeriesID, "반복이면 회차끼리 같은 값을 둔다")

        XCTAssertEqual(try store.spawnDueRepeats(now: now), 1, "지난 회차에서 다음 회차 하나")
        let records = try context.fetch(FetchDescriptor<Record>())
        XCTAssertEqual(records.count, 2)
        let next = try XCTUnwrap(records.first { $0.persistentModelID != first.persistentModelID })
        let calendar = Calendar.current
        let today = DayIndex.of(now, calendar: calendar)
        let nextDay = DayIndex.of(next.occurredAt, calendar: calendar)
        XCTAssertGreaterThan(nextDay, today, "다음 회차는 오늘 뒤")
        XCTAssertEqual((nextDay - DayIndex.of(first.occurredAt, calendar: calendar)) % 7, 0, "매주 같은 요일")
        XCTAssertEqual(next.title, "주간 산책")
        XCTAssertEqual(next.location, "호숫가")
        XCTAssertEqual(next.tags, ["운동"])
        XCTAssertNil(next.note, "메모는 따라가지 않는다")
        XCTAssertEqual((next.participants ?? []).map(\.name), ["반복 견본"])
        XCTAssertEqual(next.repeatSeriesID, first.repeatSeriesID)
        XCTAssertTrue(first.repeatSpawned)
        XCTAssertFalse(next.repeatSpawned)

        XCTAssertEqual(try store.spawnDueRepeats(now: now), 0, "한 회차에서 한 번만")
        // 다른 기기가 표시를 못 받은 채로 다시 돌아도 같은 날을 두 번 만들지 않는다.
        first.repeatSpawned = false
        try context.save()
        XCTAssertEqual(try store.spawnDueRepeats(now: now), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Record>()), 2)
    }

    func testFutureRepeatWaitsAndOffClearsSeries() throws {
        let context = try makeContainer().mainContext
        let friend = try person("앞날 견본", in: context)
        let store = RecordStore(context: context)
        let now = Date()
        var draft = RecordDraft(anchor: friend)
        draft.title = "다음 주 모임"
        draft.occurredAt = Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now
        draft.repeatRule = .monthlyDay
        let record = try store.create(draft)
        XCTAssertNotNil(record.repeatAnchorDay, "매달 같은 날은 처음 날을 기억한다")
        XCTAssertEqual(try store.spawnDueRepeats(now: now), 0, "아직 오지 않은 회차는 기다린다")

        var off = RecordDraft(record: record)
        off.repeatRule = .none
        try store.apply(off, to: record)
        XCTAssertEqual(record.repeatRule, 0)
        XCTAssertNil(record.repeatSeriesID)
        XCTAssertNil(record.repeatAnchorDay)

        var month = RecordDraft(record: record)
        month.occurredPrecision = .month
        month.repeatRule = .weekly
        try store.apply(month, to: record)
        XCTAssertEqual(record.repeatRule, 0, "날짜까지 정한 기록만 반복한다")
    }

    // MARK: - 기록 틀 (FR-070)

    func testTemplateSavesShapeAndFillsWithoutDroppingAnchor() throws {
        let context = try makeContainer().mainContext
        let host = try person("틀 주인", in: context)
        let guest = try person("틀 손님", in: context)
        let other = try person("새 사람", in: context)
        let templates = TemplateStore(context: context)

        var draft = RecordDraft(anchor: host)
        draft.participants.append(guest)
        draft.recordType = "meeting"
        draft.title = "월례 회의"
        draft.location = "3층 회의실"
        draft.tags = ["회사"]
        draft.note = "틀에 들어가지 않는 메모"
        XCTAssertNil(try templates.save(draft, name: "   "), "이름이 없으면 만들지 않는다")
        let template = try XCTUnwrap(try templates.save(draft, name: "  월례   회의  "))
        XCTAssertEqual(template.name, "월례 회의", "빈칸을 정리한다")
        XCTAssertEqual(template.participantIDs.count, 2)
        XCTAssertEqual(templates.templates().map(\.name), ["월례 회의"])

        var fresh = RecordDraft(anchor: other)
        fresh.note = "내 메모"
        templates.fill(&fresh, from: template)
        XCTAssertEqual(fresh.title, "월례 회의")
        XCTAssertEqual(fresh.location, "3층 회의실")
        XCTAssertEqual(fresh.tags, ["회사"])
        XCTAssertEqual(fresh.note, "내 메모", "메모는 그대로")
        XCTAssertEqual(fresh.participants.first?.name, "새 사람", "기록을 연 사람이 남는다")
        XCTAssertEqual(Set(fresh.participants.map(\.name)), ["새 사람", "틀 주인", "틀 손님"])

        var again = RecordDraft(anchor: host)
        templates.fill(&again, from: template)
        XCTAssertEqual(again.participants.count, 2, "이미 든 사람은 두 번 넣지 않는다")

        try templates.rename(template, to: "회의")
        XCTAssertEqual(template.name, "회의")
        try templates.delete(template)
        XCTAssertTrue(templates.templates().isEmpty)
    }

    // MARK: - 모임 이름 (FR-071)

    func testCommunityRenameUpdatesOverlappingLabelAndEmptyClears() throws {
        let context = try makeContainer().mainContext
        let store = TemplateStore(context: context)
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        try store.renameCommunity(members: [a, b, c], to: "독서 모임")
        XCTAssertEqual(store.communityLabels().map(\.name), ["독서 모임"])

        // 셋 가운데 셋이 그대로 · 한 명 늘어난 모임 — 같은 모임으로 보고 이름만 고친다.
        try store.renameCommunity(members: [a, b, c, d], to: "  책 모임 ")
        let labels = try context.fetch(FetchDescriptor<CommunityLabel>())
        XCTAssertEqual(labels.count, 1)
        XCTAssertEqual(labels.first?.name, "책 모임")
        XCTAssertEqual(labels.first?.memberIDs.count, 4, "묶음도 지금으로")

        try store.renameCommunity(members: [a, b, c, d], to: " ")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CommunityLabel>()), 0, "비우면 제안 이름으로 돌아간다")
    }

    // MARK: - 백업

    func testBackupRoundTripKeepsRepeatTemplatesAndLabels() throws {
        let source = try makeContainer().mainContext
        let friend = try person("백업 견본", in: source)
        var draft = RecordDraft(anchor: friend)
        draft.title = "격주 통화"
        draft.repeatRule = .biweekly
        let record = try RecordStore(context: source).create(draft)
        let templates = TemplateStore(context: source)
        try templates.save(draft, name: "통화")
        try templates.renameCommunity(members: [friend.uuid], to: "가족")

        let decoded = try Backup.decode(try Backup.encode(Backup.makeFile(context: source)))
        let target = try makeContainer().mainContext
        _ = try Backup.restore(decoded, into: target)

        let restored = try XCTUnwrap(try target.fetch(FetchDescriptor<Record>()).first)
        XCTAssertEqual(restored.repeatRule, RepeatRule.biweekly.rawValue)
        XCTAssertEqual(restored.repeatSeriesID, record.repeatSeriesID)
        let template = try XCTUnwrap(TemplateStore(context: target).templates().first)
        XCTAssertEqual(template.name, "통화")
        XCTAssertEqual(template.participantIDs, [friend.uuid.uuidString])
        XCTAssertEqual(TemplateStore(context: target).communityLabels().map(\.name), ["가족"])
    }

    // MARK: - 달마다 돌아보기 (FR-074)

    func testMonthlyRecapFiresOnNextFirstAndLooksBackOneMonth() throws {
        let calendar = Calendar.current
        let now = Date()
        let plan = try XCTUnwrap(MonthlyRecap.plan(now: now, hour: 9, minute: 0, calendar: calendar))
        XCTAssertGreaterThan(plan.fireAt, now)
        XCTAssertEqual(calendar.component(.day, from: plan.fireAt), 1)
        XCTAssertEqual(calendar.component(.hour, from: plan.fireAt), 9)
        XCTAssertEqual(plan.end, calendar.startOfDay(for: plan.fireAt), "돌아볼 달은 울리는 날 바로 전까지")
        XCTAssertEqual(calendar.date(byAdding: .month, value: 1, to: plan.start), plan.end)
        XCTAssertEqual(calendar.component(.month, from: plan.start), plan.month)
    }

    // MARK: - 11판 → 12판

    /// 11판(빌드 61) 저장소 → 12판: 사람 · 기록이 남고, 반복은 꺼진 채, 틀 · 모임 이름을 새로 쓸 수 있다.
    func testVersionElevenStoreOpensAndTakesNewFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v11.store")

        do {
            let schema = Schema(versionedSchema: SchemaV11.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let friend = SchemaV11.Person(name: "11판 친구")
            context.insert(friend)
            let record = SchemaV11.Record(title: "11판 기록")
            context.insert(record)
            record.participants = [friend]
            try context.save()
        }

        let container = try Persistence.makeContainer(inMemory: false, url: url)
        let context = container.mainContext
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<Record>()).first)
        XCTAssertEqual(record.title, "11판 기록")
        XCTAssertEqual((record.participants ?? []).map(\.name), ["11판 친구"])
        XCTAssertEqual(record.repeatRule, 0)
        XCTAssertNil(record.repeatSeriesID)
        XCTAssertFalse(record.repeatSpawned)

        let templates = TemplateStore(context: context)
        try templates.save(RecordDraft(record: record), name: "옮긴 뒤 첫 틀")
        XCTAssertEqual(templates.templates().map(\.name), ["옮긴 뒤 첫 틀"])
    }
}
