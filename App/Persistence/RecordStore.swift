import Core
import Foundation
import SwiftData

/// 기록 추가 · 수정 화면이 들고 있는 값 (요구사항 4.2.4).
struct RecordDraft: Equatable {
    var occurredAt = Date()
    var recordType = RecordType.defaultKey
    var title = ""
    var note = ""
    var location = ""
    /// 함께한 사람. 기록을 연 사람이 기본으로 들어 있고, 1명 이상이어야 저장된다 (FR-042).
    var participants: [Person] = []
    var tags: [String] = []

    /// 새 기록 — 기록을 연 사람이 첫 참여자다.
    init(anchor: Person) {
        participants = [anchor]
    }

    init(record: Record) {
        occurredAt = record.occurredAt
        recordType = record.recordType
        title = record.title ?? ""
        note = record.note ?? ""
        location = record.location ?? ""
        participants = record.participants ?? []
        tags = record.tags
    }

    /// 제목 또는 메모 중 하나(D-4) · 참여자 1명 이상.
    var canSave: Bool {
        RecordValidation.canSave(title: title, note: note) && !participants.isEmpty
    }
}

/// 기록을 고치는 **유일한 문**. 저장은 `저장` 을 누른 자리에서 디스크에 닿는다.
@MainActor
struct RecordStore {
    let context: ModelContext

    /// 한 사람의 타임라인 (요구사항 6.7). 정렬 규칙은 `Core.TimelineSort` 한 곳이다.
    static func timeline(of person: Person) -> [Record] {
        (person.records ?? []).sorted {
            TimelineSort.areInIncreasingOrder((occurredAt: $0.occurredAt, createdAt: $0.createdAt),
                                              (occurredAt: $1.occurredAt, createdAt: $1.createdAt))
        }
    }

    /// 저장하고, 실패하면 이번에 바꾼 것을 모두 되돌린다 — `PersonStore.commit` 과 같은 까닭 (전수조사 2026-10-18).
    private func commit() throws {
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func create(_ draft: RecordDraft) throws -> Record {
        let record = Record(recordType: draft.recordType)
        context.insert(record)
        fill(record, from: draft)
        try commit()
        return record
    }

    /// 실패하면 옛 값을 되돌려 쓴다 — `PersonStore.apply` 와 같은 까닭 (`rollback()` 은 바뀐 칸을 되돌리지 않았다).
    func apply(_ draft: RecordDraft, to record: Record) throws {
        let before = RecordDraft(record: record)
        let updatedAt = record.updatedAt
        fill(record, from: draft)
        record.updatedAt = Date()
        do {
            try commit()
        } catch {
            fill(record, from: before)
            record.updatedAt = updatedAt
            throw error
        }
    }

    /// 기록만 지운다. 참여자는 남는다 (6.5).
    func delete(_ record: Record) throws {
        context.delete(record)
        try commit()
    }

    private func fill(_ record: Record, from draft: RecordDraft) {
        record.recordType = RecordType.named(draft.recordType).key
        record.occurredAt = DayNormalizer.noon(of: draft.occurredAt, calendar: .current)
        record.title = clipped(draft.title, Limits.recordTitle)
        record.note = clipped(draft.note, Limits.recordNote)
        record.location = clipped(draft.location, Limits.location)
        record.tags = TagNormalizer.normalizeList(draft.tags)
        // 같은 사람이 두 번 들어오지 않게, 지워진 사람은 빼고.
        var seen = Set<PersistentIdentifier>()
        record.participants = draft.participants.filter { person in
            guard !person.isGone, !seen.contains(person.persistentModelID) else { return false }
            seen.insert(person.persistentModelID)
            return true
        }
    }

    private func clipped(_ text: String, _ limit: Int) -> String? {
        guard let cleaned = TextNormalization.nilIfEmpty(text) else { return nil }
        return String(cleaned.prefix(limit))
    }
}

extension SchemaV4.Record {
    /// 목록에 보일 이름 (요구사항 6.2). 규칙은 `Core.DisplayTitle` 하나다.
    var displayTitle: String { DisplayTitle.make(title: title, note: note) }

    var type: RecordType { RecordType.named(recordType) }

    /// 삭제 확인 문구 (FR-009 — 대상과 범위 · 전수조사 이슈 19). 기록은 한 번만 저장되므로(N:M) 지우면
    /// 함께한 다른 사람의 타임라인에서도 사라진다. `viewer` 는 지금 보고 있는 사람의 타임라인 (기록 상세면 nil).
    /// 단추를 누를 때 미리 만들어 둔다 — 확인 창이 닫히는 동안 지운 기록을 다시 읽지 않게.
    func deletionMessage(viewer: Person?) -> String {
        let people = (participants ?? []).filter { !$0.isGone && !$0.isMe }
        var text = "'\(displayTitle)' 기록을 삭제하시겠습니까?"
        if let viewer {
            let others = people.filter { $0 !== viewer }.count
            if others > 0 { text += " 함께한 \(others)명의 타임라인에서도 사라집니다." }
        } else if people.count >= 2 {
            text += " 함께한 \(people.count)명의 타임라인에서 모두 사라집니다."
        }
        return text + " 되돌릴 수 없습니다."
    }

    /// 이 사람 말고 함께한 사람 수 — 타임라인 행의 "외 N명".
    func otherParticipantCount(besides person: Person) -> Int {
        (participants ?? []).filter { $0 !== person }.count
    }

    /// 메모 첫 줄 (타임라인 행에 한 줄 말줄임으로). 제목이 메모에서 나왔으면 비운다.
    var notePreview: String? {
        guard let note, !note.isEmpty else { return nil }
        if TextNormalization.nilIfEmpty(title) == nil { return nil }
        return note.split(whereSeparator: { $0.isNewline }).first.map(String.init)
    }
}
