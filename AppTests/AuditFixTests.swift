import SwiftData
import XCTest
@testable import SlowConnection

/// 전수조사(2026-10-18 · 이슈 19 · 20)에서 고친 저장 규칙을 인메모리 저장소로 시험한다.
@MainActor
final class AuditFixTests: XCTestCase {

    /// 저장소를 시험 동안 붙잡아 둔다 — `makeContainer(...).mainContext` 만 돌려주면 그릇(`ModelContainer`)이
    /// 바로 풀려 문맥이 죽은 그릇을 쓰다 시험 앱이 꺼진다 (빌드 12 첫 CI 에서 이 시험 넷이 그렇게 죽었다).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    /// 저장이 실패하면 넣은 사람이 문맥에 남지 않는다 — `다시 시도` 가 같은 사람을 하나 더 만들지 않는다 (AC-29).
    func testFailedSaveRollsBackAndRetryCreatesExactlyOnePerson() throws {
        let context = try makeContext()
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "다시해"

        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try store.create(draft), "저장 실패를 던진다")
        XCTAssertTrue(try store.allPeople().isEmpty, "실패한 저장은 되돌린다 — 남은 사람이 없다")

        SaveFailure.isOn = false
        _ = try store.create(draft)
        XCTAssertEqual(try store.allPeople().map(\.name), ["다시해"], "다시 시도하면 꼭 한 명")
    }

    /// 수정이 실패하면 바뀐 값이 모델에 남지 않는다 — `버리기` 뒤에도 옛 값이 그대로다.
    func testFailedEditKeepsTheSavedValues() throws {
        let context = try makeContext()
        let store = PersonStore(context: context)
        var draft = PersonDraft()
        draft.name = "그대로"
        let person = try store.create(draft)

        var changed = PersonDraft(person: person)
        changed.name = "바뀜"
        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try store.apply(changed, to: person))
        XCTAssertEqual(person.name, "그대로", "실패한 수정은 되돌린다")
    }

    /// 기록 수정이 실패해도 마찬가지 — 옛 제목이 남는다.
    func testFailedRecordEditKeepsTheSavedValues() throws {
        let context = try makeContext()
        var someone = PersonDraft()
        someone.name = "기록 주인"
        let person = try PersonStore(context: context).create(someone)
        let records = RecordStore(context: context)
        var draft = RecordDraft(anchor: person)
        draft.title = "그대로"
        let record = try records.create(draft)

        var changed = RecordDraft(record: record)
        changed.title = "바뀜"
        SaveFailure.isOn = true
        defer { SaveFailure.isOn = false }
        XCTAssertThrowsError(try records.apply(changed, to: record))
        XCTAssertEqual(record.title, "그대로", "실패한 수정은 되돌린다")
    }

    /// 앞날짜(예정) 기록은 마지막 기록일이 아니다 — 목록 · 돌아보기 · 관계 돌아보기가 같은 말을 한다 (이슈 20).
    func testFutureRecordsAreNotTheLastRecord() throws {
        let context = try makeContext()
        let both = Person(name: "둘다")
        let futureOnly = Person(name: "앞으로")
        context.insert(both)
        context.insert(futureOnly)
        let past = Date().addingTimeInterval(-10 * 86_400)
        let pastRecord = Record(recordType: "meal", occurredAt: past, title: "지난 점심")
        let plan = Record(recordType: "meal", occurredAt: Date().addingTimeInterval(5 * 86_400), title: "예정")
        let lonePlan = Record(recordType: "meal", occurredAt: Date().addingTimeInterval(5 * 86_400), title: "예정 둘")
        for record in [pastRecord, plan, lonePlan] { context.insert(record) }
        pastRecord.participants = [both]
        plan.participants = [both]
        lonePlan.participants = [futureOnly]
        try context.save()

        XCTAssertEqual(both.lastRecordAt, past, "오늘까지의 기록 중 마지막")
        XCTAssertNil(futureOnly.lastRecordAt, "앞날짜 기록만 있으면 아직 기록이 없는 사람")
    }

    /// 태그 칸에 치다 만 글자도 저장할 때 태그가 된다 (이슈 19).
    func testPendingTagIsMergedOnSave() {
        // 정리 규칙(나누기 · 다듬기)의 기댓값은 Core 정답표(`tagSplit` · `tags`)가 본다 — 여기서는 지어내지 않고 성질만 본다.
        let merged = TagEditor.merged(["멘토"], pending: "독서, 등산")
        XCTAssertEqual(merged.first, "멘토", "있던 태그는 그대로 남는다")
        XCTAssertGreaterThan(merged.count, 1, "치던 글자가 태그로 들어간다")
        XCTAssertEqual(TagEditor.merged(merged, pending: "  "), merged, "빈 글자는 아무것도 바꾸지 않는다")
    }

    /// 삭제 문구 — 혼자 참여한 기록이 없으면 `기록 0건` 을 말하지 않고, 공동 기록은 범위를 말한다 (FR-009 · 이슈 19).
    func testDeletionMessagesStateTheScope() throws {
        let context = try makeContext()
        let people = PersonStore(context: context)
        let records = RecordStore(context: context)
        var first = PersonDraft()
        first.name = "첫째"
        let a = try people.create(first)
        var second = PersonDraft()
        second.name = "둘째"
        let b = try people.create(second)
        var third = PersonDraft()
        third.name = "셋째"
        let c = try people.create(third)

        var draft = RecordDraft(anchor: a)
        draft.title = "셋이 저녁"
        draft.participants = [a, b, c]
        let record = try records.create(draft)

        let personMessage = people.deletionMessage(for: a)
        XCTAssertFalse(personMessage.contains("0건"), personMessage)
        XCTAssertTrue(personMessage.contains("기록은 남습니다"), personMessage)
        XCTAssertTrue(record.deletionMessage(viewer: a).contains("함께한 2명의 타임라인에서도"))
        XCTAssertTrue(record.deletionMessage(viewer: nil).contains("함께한 3명의 타임라인에서 모두"))
    }
}
