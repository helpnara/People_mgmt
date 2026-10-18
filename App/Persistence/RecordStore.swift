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

    func create(_ draft: RecordDraft) throws -> Record {
        let record = Record(recordType: draft.recordType)
        context.insert(record)
        fill(record, from: draft)
        try context.save()
        return record
    }

    func apply(_ draft: RecordDraft, to record: Record) throws {
        fill(record, from: draft)
        record.updatedAt = Date()
        try context.save()
    }

    /// 기록만 지운다. 참여자는 남는다 (6.5).
    func delete(_ record: Record) throws {
        context.delete(record)
        try context.save()
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

extension SchemaV2.Record {
    /// 목록에 보일 이름 (요구사항 6.2). 규칙은 `Core.DisplayTitle` 하나다.
    var displayTitle: String { DisplayTitle.make(title: title, note: note) }

    var type: RecordType { RecordType.named(recordType) }

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
