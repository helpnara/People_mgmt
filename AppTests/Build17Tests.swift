import SwiftData
import XCTest
@testable import SlowConnection

/// **빌드 17** — 이슈 27: 기록을 지운 직후 사람 상세의 타임라인이 지운 기록을 읽다 앱이 꺼졌다 (빌드 16 실기기 크래시 ·
/// `TimelineRow.body`). 타임라인은 지운 기록을 빼고 돌려주는가 — 지운 기록의 날짜 · 장소를 읽지 않는가.
@MainActor
final class Build17Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    func testTimelineLeavesOutADeletedRecord() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        let context = container.mainContext
        var draft = PersonDraft()
        draft.name = "가람"
        let person = try PersonStore(context: context).create(draft)
        let records = RecordStore(context: context)
        var first = RecordDraft(anchor: person)
        first.title = "남길 기록"
        first.location = "을지로"
        let kept = try records.create(first)
        var second = RecordDraft(anchor: person)
        second.title = "지울 기록"
        second.location = "종로"
        let gone = try records.create(second)

        try records.delete(gone)

        let timeline = RecordStore.timeline(of: person)
        XCTAssertEqual(timeline.map(\.uuid), [kept.uuid], "지운 기록은 타임라인에 없다")
        XCTAssertEqual(timeline.first?.location, "을지로")
    }
}
