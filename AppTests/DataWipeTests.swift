import SwiftData
import XCTest
@testable import SlowConnection

/// **전체 데이터 삭제** (할 일 54) — 사람 · 기록 · 아는 사이가 모두 사라지는가, 설정은 남는가,
/// 저장이 실패하면 하나도 지우지 않는가.
@MainActor
final class DataWipeTests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    private func seeded() throws -> ModelContainer {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        SampleData.seed(into: container.mainContext, communities: true)
        try container.mainContext.save()
        return container
    }

    func testWipeRemovesPeopleRecordsAndTiesButKeepsSettings() async throws {
        let container = try seeded()
        let before = DataWipe.counts(in: container.mainContext)
        XCTAssertGreaterThan(before.people, 0)
        XCTAssertGreaterThan(before.records, 0)
        XCTAssertGreaterThan(before.ties, 0, "모임 견본에는 아는 사이가 있다")

        let defaults = UserDefaults.standard
        let key = DetailLayoutView.storageKey
        let kept = defaults.string(forKey: key)
        defaults.set("timeline", forKey: key)
        defer { defaults.set(kept, forKey: key) }

        let done = try await DataWipe.wipe(container: container)
        XCTAssertEqual(done, before, "지운 수는 지우기 전의 수와 같다")
        XCTAssertTrue(DataWipe.counts(in: container.mainContext).isEmpty, "사람 · 기록 · 아는 사이가 하나도 남지 않는다")
        XCTAssertTrue(DataWipe.counts(in: ModelContext(container)).isEmpty, "새 그릇으로 읽어도 비어 있다")
        XCTAssertEqual(defaults.string(forKey: key), "timeline", "설정은 그대로 둔다")
    }

    func testFailedSaveLeavesEverythingInPlace() throws {
        let container = try seeded()
        let before = DataWipe.counts(in: container.mainContext)
        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try DataWipe.wipe(into: ModelContext(container)))
        XCTAssertEqual(DataWipe.counts(in: ModelContext(container)), before, "저장이 실패하면 하나도 지우지 않는다")
    }

    func testEmptyStoreCountsAsEmpty() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        XCTAssertTrue(DataWipe.counts(in: container.mainContext).isEmpty)
    }
}
