import SwiftData
import XCTest
@testable import SlowConnection

/// **백업 · 복원** (FR-018 · D-34) — 만든 파일을 빈 저장소에 되살리면 사람 · 기록 · 아는 사이 · 명함 · 소개 관계가
/// 그대로 이어지는가, 비어 있지 않은 저장소에는 복원하지 않는가, 백업이 아닌 파일은 거르는가.
@MainActor
final class BackupTests: XCTestCase {

    /// 저장소 그릇을 시험 동안 붙잡아 둔다 (빌드 12 교훈 — 풀린 그릇을 쓰면 시험 앱이 꺼진다).
    private var containers: [ModelContainer] = []

    private func makeContainer() throws -> ModelContainer {
        let container = try Persistence.makeContainer(inMemory: true)
        containers.append(container)
        return container
    }

    func testRoundTripRestoresEverythingIntoAnEmptyStore() async throws {
        let source = try makeContainer()
        let context = source.mainContext
        let people = PersonStore(context: context)
        let records = RecordStore(context: context)

        var mine = PersonDraft()
        mine.name = "나"
        let me = try people.create(mine, isMe: true)
        var first = PersonDraft()
        first.name = "첫째"
        first.tags = ["독서모임"]
        first.businessCard = Data([0x01, 0x02, 0x03])
        first.photo = Data([0x04, 0x05])
        let a = try people.create(first)
        var second = PersonDraft()
        second.name = "둘째"
        second.metThrough = "소개"   // 앱 시험 묶음은 Core 를 들이지 않는다 — 소개 경로의 이름표 (RelationshipPresets.introducedLabel)
        second.introducedBy = a
        second.acquaintances = [a]
        let b = try people.create(second)
        var draft = RecordDraft(anchor: a)
        draft.title = "함께한 저녁"
        draft.participants = [me, a, b]
        let shared = try records.create(draft)

        let file = Backup.makeFile(context: context)
        let data = try Backup.encode(file)
        let decoded = try Backup.decode(data)

        let target = try makeContainer()
        let summary = try await Backup.restore(decoded, container: target)
        XCTAssertEqual(summary.people, 3)
        XCTAssertEqual(summary.records, 1)
        XCTAssertEqual(summary.ties, 1)
        XCTAssertEqual(summary.cards, 1)
        XCTAssertEqual(summary.photos, 1, "사람 사진도 센다 (이슈 45)")

        let restored = target.mainContext
        let all = try restored.fetch(FetchDescriptor<Person>())
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.uuid, $0) })
        XCTAssertEqual(Set(byID.keys), [me.uuid, a.uuid, b.uuid], "고유 식별자가 그대로")
        XCTAssertEqual(all.filter(\.isMe).map(\.uuid), [me.uuid], "나는 하나 그대로")
        XCTAssertEqual(byID[b.uuid]?.introducedBy?.uuid, a.uuid, "소개 관계가 이어진다")
        XCTAssertEqual(byID[a.uuid]?.businessCard, Data([0x01, 0x02, 0x03]), "명함 사진이 그대로")
        XCTAssertEqual(byID[a.uuid]?.photo, Data([0x04, 0x05]), "사람 사진이 그대로")
        XCTAssertEqual(byID[a.uuid]?.tags, a.tags)
        XCTAssertEqual(byID[b.uuid]?.acquaintances.map(\.uuid), [a.uuid], "아는 사이가 이어진다")
        let createdGap = abs((byID[a.uuid]?.createdAt.timeIntervalSince1970 ?? 0) - a.createdAt.timeIntervalSince1970)
        XCTAssertLessThan(createdGap, 0.001, "만든 날이 그대로 (천분의 1초까지)")

        let restoredRecords = try restored.fetch(FetchDescriptor<Record>())
        XCTAssertEqual(restoredRecords.map(\.uuid), [shared.uuid])
        XCTAssertEqual(Set((restoredRecords.first?.participants ?? []).map(\.uuid)), [me.uuid, a.uuid, b.uuid], "함께한 사람이 그대로")
        XCTAssertEqual(restoredRecords.first?.title, "함께한 저녁")
    }

    func testRestoreRefusesAStoreThatAlreadyHasPeople() async throws {
        let source = try makeContainer()
        var someone = PersonDraft()
        someone.name = "있던 사람"
        _ = try PersonStore(context: source.mainContext).create(someone)
        let file = Backup.makeFile(context: source.mainContext)

        do {
            _ = try await Backup.restore(file, container: source)
            XCTFail("사람이 있으면 복원하지 않는다")
        } catch let error as Backup.Failure {
            XCTAssertEqual(error, .notEmpty)
        }
        XCTAssertEqual(try source.mainContext.fetchCount(FetchDescriptor<Person>()), 1, "있던 자료는 그대로")
    }

    func testDecodeRejectsFilesThatAreNotBackups() {
        XCTAssertThrowsError(try Backup.decode(Data("{\"hello\": 1}".utf8))) { error in
            XCTAssertEqual(error as? Backup.Failure, .notBackup)
        }
        XCTAssertThrowsError(try Backup.decode(Data("not json".utf8)))
    }
}
