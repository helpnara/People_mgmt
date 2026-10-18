import SwiftData
import XCTest
@testable import SlowConnection

/// 빌드 13 (전수조사 이슈 22 · 23 · 24) — 검색 색인 · 채울 것 · 나 지우기 · 같은 이름 열쇠 · 최근 등록순.
/// 순수 셈은 Core 정답표가 보고, 여기는 SwiftData 가 있어야 보이는 것만 둔다. 기댓값은 넣은 자료에서 바로 나오는 것만.
@MainActor
final class Build13Tests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 — 풀리면 문맥이 죽은 그릇을 쓰다 시험 앱이 꺼진다 (빌드 12 CI).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    private func person(_ name: String, in context: ModelContext, configure: (inout PersonDraft) -> Void = { _ in }) throws -> Person {
        var draft = PersonDraft()
        draft.name = name
        configure(&draft)
        return try PersonStore(context: context).create(draft)
    }

    /// 검색 색인은 따로 연 문맥에서 만든다 (이슈 8) — 나는 빠지고 사람마다 한 줄.
    func testSearchIndexIsBuiltFromABackgroundContextWithoutMe() async throws {
        let context = try makeContext()
        guard let container else { return XCTFail("저장소가 없다") }
        var mine = PersonDraft()
        mine.name = "나"
        _ = try PersonStore(context: context).create(mine, isMe: true)
        let a = try person("가을", in: context)
        _ = try person("겨울", in: context)
        var record = RecordDraft(anchor: a)
        record.title = "소풍"
        record.note = "단풍 구경"
        _ = try RecordStore(context: context).create(record)

        let index = await SearchIndexBuilder.build(container: container)
        XCTAssertEqual(index.count, 2, "나를 뺀 사람마다 한 줄")
    }

    /// 채울 것 목록의 `채웠습니다` 표시 — 처음 만난 날 · 아는 사이 · 기록.
    func testFillFieldIsFilledFollowsTheSavedPerson() throws {
        let context = try makeContext()
        let friend = try person("친구", in: context)
        let empty = try person("빈칸", in: context)
        let full = try person("다채움", in: context) { draft in
            draft.hasFirstMetDate = true
            draft.firstMetDate = Date(timeIntervalSince1970: 1_600_000_000)
            draft.acquaintances = [friend]
        }
        var record = RecordDraft(anchor: full)
        record.title = "점심"
        _ = try RecordStore(context: context).create(record)

        for field in [FillField.firstMet, .acquaintances, .record] {
            XCTAssertTrue(field.isFilled(full), "\(field.rawValue) — 채운 사람")
            XCTAssertFalse(field.isFilled(empty), "\(field.rawValue) — 빈 사람")
        }
    }

    /// 나를 지울 수 있고, 지운 뒤 다시 나를 적을 수 있다.
    func testDeletingMeAllowsANewMe() throws {
        let context = try makeContext()
        let store = PersonStore(context: context)
        var mine = PersonDraft()
        mine.name = "처음 나"
        let me = try store.create(mine, isMe: true)
        try store.delete(me)
        XCTAssertNil(try store.me(), "지우면 나가 없다")

        mine.name = "새 나"
        _ = try store.create(mine, isMe: true)
        XCTAssertEqual(try store.me()?.name, "새 나")
        XCTAssertTrue(try store.allPeople().isEmpty, "나는 사람 목록에 들지 않는다")
    }

    /// 같은 이름은 가운데 공백도 무시한다 (FR-021) — `홍 길동` 과 `홍길동`.
    func testSameNameIgnoresInnerSpaces() throws {
        let context = try makeContext()
        let gil = try person("홍길동", in: context)
        XCTAssertEqual(PersonStore.sameNameKey("홍 길동"), PersonStore.sameNameKey("홍길동"))
        XCTAssertEqual(PersonStore.sameName(as: "홍 길동", in: [gil]).map(\.name), ["홍길동"])
        XCTAssertNotEqual(PersonStore.sameNameKey("홍길순"), PersonStore.sameNameKey("홍길동"))
    }

    /// 최근 등록순 — 늦게 적은 사람부터, 같은 때 적었으면 이름순 차례 (FR-027).
    func testNewestFirstSortsByCreationThenName() throws {
        let context = try makeContext()
        let old = try person("오래", in: context)
        let mid = try person("중간", in: context)
        let new = try person("새로", in: context)
        let twin = try person("가나", in: context)
        old.createdAt = Date(timeIntervalSince1970: 100)
        mid.createdAt = Date(timeIntervalSince1970: 200)
        new.createdAt = Date(timeIntervalSince1970: 300)
        twin.createdAt = Date(timeIntervalSince1970: 300)

        let sorted = PersonStore.sorted([old, mid, new, twin], by: .newest)
        XCTAssertEqual(sorted.map(\.createdAt), [new.createdAt, twin.createdAt, mid.createdAt, old.createdAt], "늦게 적은 사람부터")
        let sameTime = PersonStore.sorted([new, twin], by: .name).map(\.name)
        XCTAssertEqual(Array(sorted.prefix(2)).map(\.name), sameTime, "같은 때면 이름순 차례")
    }
}
