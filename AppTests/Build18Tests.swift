import SwiftData
import XCTest
@testable import SlowConnection

/// **빌드 18** — 모임 짝짓기 문턱을 설정에서 고른다 (D-39). 기본은 0.3, 저장해 둔 값이 없거나 낯선 값이면 기본으로.
/// 문턱마다 판정이 어떻게 달라지는지는 Core 정답표(`temporal` 의 `thresholdChanges`)가 본다.
@MainActor
final class Build18Tests: XCTestCase {

    func testDefaultIsStandardAndStoredChoiceIsRead() {
        UserDefaults.standard.removeObject(forKey: GroupMatchSetting.key)
        defer { UserDefaults.standard.removeObject(forKey: GroupMatchSetting.key) }
        XCTAssertEqual(GroupMatchSetting.current, .standard, "고른 적이 없으면 보통")
        XCTAssertEqual(GroupMatchSetting.standard.threshold, 0.3, accuracy: 1e-12)

        UserDefaults.standard.set(GroupMatchSetting.looser.rawValue, forKey: GroupMatchSetting.key)
        XCTAssertEqual(GroupMatchSetting.current, .looser)
        XCTAssertEqual(GroupMatchSetting.current.threshold, 0.1, accuracy: 1e-12)

        UserDefaults.standard.set("unknown", forKey: GroupMatchSetting.key)
        XCTAssertEqual(GroupMatchSetting.current, .standard, "낯선 값이면 보통")
    }

    private var containers: [ModelContainer] = []

    /// vCard (D-41) — 내보낸 파일을 다른 저장소에서 읽으면, 이미 있는 사람은 이미 있음 · 없는 사람은 새 사람으로 나뉘고,
    /// 새 사람만 넣으면 이름 · 연락 수단 · 생일이 그대로 들어간다. 만들기 · 읽기 · 판정의 세부는 Core 정답표가 본다.
    func testVCardExportThenImportPreview() async throws {
        let source = try Persistence.makeContainer(inMemory: true)
        let target = try Persistence.makeContainer(inMemory: true)
        containers += [source, target]
        var first = PersonDraft()
        first.name = "가람"
        first.mobilePhone = "010-1234-5678"
        first.hasBirthday = true
        first.birthMonth = 3
        first.birthDay = 14
        var second = PersonDraft()
        second.name = "나래"
        second.email = "narae@example.com"
        _ = try PersonStore(context: source.mainContext).createMany([first, second])

        let made = await VCardTransfer.export(container: source)
        XCTAssertEqual(made.count, 2)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vcf")
        try made.data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var already = PersonDraft()
        already.name = "가람"
        already.mobilePhone = "010-1234-5678"
        _ = try PersonStore(context: target.mainContext).create(already)

        let items = try await VCardTransfer.preview(url: url, container: target)
        XCTAssertEqual(items.map(\.person.name), ["가람", "나래"], "이름 순")
        XCTAssertEqual(items.map { $0.verdict.rawValue }, ["duplicate", "new"])
        XCTAssertEqual(items.first?.existingName, "가람")

        let fresh = items.filter { $0.verdict.rawValue == "new" }.map { VCardTransfer.draft($0.person) }
        try PersonStore(context: target.mainContext).createMany(fresh)
        let people = try target.mainContext.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 2, "새 사람만 들어간다")
        XCTAssertEqual(people.first { $0.name == "나래" }?.email, "narae@example.com")

        let back = items.first { $0.person.name == "가람" }?.person
        XCTAssertEqual(back?.birthMonth, 3, "생일이 오간다")
        XCTAssertEqual(back?.birthDay, 14)
    }
}
