import Core
import SwiftData
import XCTest
@testable import SlowConnection

/// 빌드 27 — 태그 이름 바꾸기 · 합치기(FR-026)가 사람과 기록에 함께 닿는지. 기댓값은 Core 규칙(`TagCatalog.renamed`)이 낸다.
@MainActor
final class Build27Tests: XCTestCase {

    /// 컨테이너를 시험 동안 붙잡아 둔다 — 문맥만 돌려주면 컨테이너가 먼저 풀려 문맥을 쓰는 순간 시험 프로세스가 꺼진다
    /// (빌드 27 첫 CI · `PersonStoreTests.Fixture` 와 같은 까닭).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    private func person(_ name: String, tags: [String], in context: ModelContext) throws -> Person {
        var draft = PersonDraft()
        draft.name = name
        draft.tags = tags
        return try PersonStore(context: context).create(draft)
    }

    func testRenameReachesPeopleAndRecords() throws {
        let context = try makeContext()
        let a = try person("가", tags: ["멘토", "업무"], in: context)
        let b = try person("나", tags: ["독서"], in: context)
        var draft = RecordDraft(anchor: a)
        draft.title = "점심"
        draft.tags = ["Mentor"]
        let record = try RecordStore(context: context).create(draft)

        let result = try TagStore(context: context).rename("멘토", to: "선배")
        XCTAssertEqual(result, TagStore.Result(people: 1, records: 0))
        XCTAssertEqual(a.tags, TagCatalog.renamed(["멘토", "업무"], from: "멘토", to: "선배"))
        XCTAssertEqual(b.tags, ["독서"], "태그가 없는 사람은 그대로")
        XCTAssertEqual(record.tags, ["Mentor"], "다른 열쇠(Mentor)는 그대로")

        let second = try TagStore(context: context).rename("mentor", to: "선배")
        XCTAssertEqual(second, TagStore.Result(people: 0, records: 1))
        XCTAssertEqual(record.tags, TagCatalog.renamed(["Mentor"], from: "mentor", to: "선배"))
    }

    func testRenameIntoExistingTagMerges() throws {
        let context = try makeContext()
        let a = try person("가", tags: ["멘토", "선배"], in: context)
        try TagStore(context: context).rename("멘토", to: "선배")
        XCTAssertEqual(a.tags, TagCatalog.renamed(["멘토", "선배"], from: "멘토", to: "선배"))
        XCTAssertEqual(a.tags.count, 1, "합쳐서 하나")
    }

    func testCatalogBuilderCountsPeopleAndRecords() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let a = try person("가", tags: ["멘토"], in: context)
        _ = try person("나", tags: ["멘토", "업무"], in: context)
        var draft = RecordDraft(anchor: a)
        draft.title = "회의"
        draft.tags = ["업무"]
        _ = try RecordStore(context: context).create(draft)

        let catalog = await TagCatalogBuilder.build(container: container)
        let expected = TagCatalog(personTags: [["멘토"], ["멘토", "업무"]], recordTags: [["업무"]])
        XCTAssertEqual(catalog, expected)
    }
}
