import SwiftData
import XCTest
@testable import SlowConnection

/// **빌드 20** — iCloud 동기화 준비 (D-42 · ADR-0005). 두 기기에서 따로 적은 나가 이어져 둘이 되면 먼저 만든 나만 남고,
/// 나머지는 지우지 않고 보통 사람이 되는가 (D-43). 시험은 메모리 저장소라 iCloud 와 잇지 않는다.
@MainActor
final class Build20Tests: XCTestCase {

    private var containers: [ModelContainer] = []

    func testDuplicateMeKeepsTheEarliest() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        let context = container.mainContext
        let store = PersonStore(context: context)
        var mine = PersonDraft()
        mine.name = "아이폰의 나"
        let first = try store.create(mine, isMe: true)

        // 다른 기기에서 온 나 — 같은 기기에서는 나를 둘 만들 수 없으니 저장소에 바로 넣는다.
        let other = Person(name: "아이패드의 나")
        context.insert(other)
        other.isMe = true
        other.createdAt = first.createdAt.addingTimeInterval(60)
        try context.save()
        defer { UserDefaults.standard.removeObject(forKey: PersonStore.demotedMeKey) }

        let demoted = try store.resolveDuplicateMe()
        XCTAssertEqual(demoted, ["아이패드의 나"])
        XCTAssertTrue(first.isMe, "먼저 만든 나가 남는다")
        XCTAssertFalse(other.isMe, "나중 것은 보통 사람이 된다")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 2, "지우지 않는다")
        XCTAssertEqual(try store.resolveDuplicateMe(), [], "한 번 정리하면 더 할 것이 없다")
    }
}
