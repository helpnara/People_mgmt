import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// **예정된 만남** (빌드 38 · D-62) — 앞날짜 기록은 다가오는 만남, 미리 적은 예정의 날이 오면 결과를 적을 만남,
/// 그대로 만났어요를 누르면 빠진다, 저장이 실패하면 고친 때를 되돌린다.
@MainActor
final class PlannedMeetingTests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func seeded() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        SampleData.seed(into: container.mainContext, communities: false, planned: true)
        try container.mainContext.save()
        return container.mainContext
    }

    private func plan(_ context: ModelContext) throws -> (upcoming: [Record], awaiting: [Record]) {
        let records = try context.fetch(FetchDescriptor<Record>()).filter { !$0.isGone }
        let result = PlannedMeetings.plan(records.map { $0.plannedEntry() }, today: DayIndex.of(Date()))
        let byID = Dictionary(records.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        return (result.upcoming.compactMap { byID[$0] }, result.awaiting.compactMap { byID[$0] })
    }

    func testSampleShowsUpcomingAndAwaiting() throws {
        let context = try seeded()
        let found = try plan(context)
        XCTAssertEqual(found.upcoming.map(\.displayTitle), ["커피 약속", "점심 약속", "저녁 산책", "독서모임 송년회"],
                       "가까운 날부터 · 같은 날은 이른 시각부터 (D-63) · 저녁 산책은 반복 견본(12판 · 5일 뒤)")
        XCTAssertEqual(found.upcoming.first?.timeText, "오전 10:00")
        XCTAssertEqual(found.awaiting.map(\.displayTitle), ["프로젝트 시작 회의"])
        XCTAssertTrue(found.upcoming.allSatisfy(\.isUpcoming))
        XCTAssertTrue(found.awaiting.allSatisfy(\.isAwaitingResult))
        XCTAssertEqual(found.upcoming.first?.upcomingPhrase, "3일 후")
        // 견본의 지난 기록(만든 때가 그날보다 뒤)은 결과를 묻지 않는다.
        let past = try context.fetch(FetchDescriptor<Record>()).filter { $0.displayTitle == "분기 회의" }
        XCTAssertEqual(past.count, 1)
        XCTAssertFalse(past[0].isAwaitingResult)
        XCTAssertFalse(past[0].isUpcoming)
    }

    func testConfirmMetRemovesFromAwaiting() throws {
        let context = try seeded()
        let record = try XCTUnwrap(try plan(context).awaiting.first)
        let note = record.note
        try RecordStore(context: context).confirmMet(record)
        XCTAssertFalse(record.isAwaitingResult, "그대로 만났어요 뒤에는 결과를 적을 만남이 아니다")
        XCTAssertEqual(record.note, note, "내용은 그대로")
        XCTAssertTrue(try plan(context).awaiting.isEmpty)
    }

    func testFailedConfirmKeepsAwaiting() throws {
        let context = try seeded()
        let record = try XCTUnwrap(try plan(context).awaiting.first)
        let updatedAt = record.updatedAt
        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try RecordStore(context: context).confirmMet(record))
        XCTAssertEqual(record.updatedAt, updatedAt, "저장이 실패하면 고친 때를 되돌린다")
        XCTAssertTrue(record.isAwaitingResult)
    }

    func testMovingDateToFutureMakesItUpcomingAgain() throws {
        let context = try seeded()
        let record = try XCTUnwrap(try plan(context).awaiting.first)
        var draft = RecordDraft(record: record)
        draft.occurredAt = DayNormalizer.noon(of: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                                              calendar: .current)
        try RecordStore(context: context).apply(draft, to: record)
        let found = try plan(context)
        XCTAssertTrue(found.awaiting.isEmpty, "날짜를 바꾸면 결과를 적을 만남에서 빠진다")
        XCTAssertTrue(found.upcoming.contains { $0.uuid == record.uuid }, "다시 다가오는 만남이 된다")
    }
}
