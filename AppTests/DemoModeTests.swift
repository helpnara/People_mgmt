import SwiftData
import XCTest
@testable import SlowConnection

/// **견본으로 둘러보기** (D-55) — 견본은 메모리 저장소에만 채워지고 다른 저장소에 새지 않는가, 끝내면 사라지는가,
/// 둘러보는 동안 쓴 기록 유형 · 장소가 내 다음 기록에 남지 않는가.
@MainActor
final class DemoModeTests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈).
    private var containers: [ModelContainer] = []

    func testDemoFillsOnlyItsOwnMemoryStoreAndEndsClean() throws {
        let mine = try Persistence.makeContainer(inMemory: true)
        containers.append(mine)
        let demo = DemoMode.shared
        demo.start()
        defer { demo.end() }

        let container = try XCTUnwrap(demo.container, "둘러보기 저장소가 열린다")
        XCTAssertTrue(demo.isActive)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<Person>()).isEmpty, "견본 사람이 있다")
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<Record>()).isEmpty, "견본 기록이 있다")
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<Tie>()).isEmpty, "모임 견본의 아는 사이까지 있다")
        XCTAssertTrue(try mine.mainContext.fetch(FetchDescriptor<Person>()).isEmpty, "다른 저장소에는 아무것도 들어가지 않는다")

        demo.start()
        XCTAssertTrue(demo.container === container, "이미 둘러보는 중이면 새로 채우지 않는다")

        demo.end()
        XCTAssertNil(demo.container)
        XCTAssertFalse(demo.isActive)
    }

    func testRecordMemoryIsLeftAloneWhileDemoIsOpen() {
        RecordMemory.remember(type: "meal", location: "내 단골 식당")
        let demo = DemoMode.shared
        demo.start()
        RecordMemory.remember(type: "trip", location: "견본 장소")
        demo.end()
        XCTAssertEqual(RecordMemory.lastType, "meal", "둘러보며 쓴 유형은 남지 않는다")
        XCTAssertEqual(RecordMemory.lastLocation, "내 단골 식당", "둘러보며 쓴 장소는 남지 않는다")
    }
}
