import Core
import Foundation
import SwiftData

/// **기록 틀** (12판 · 이슈 95 · FR-070 · D-79 · 2026-11-06 사용자) 과 **고쳐 둔 모임 이름** (이슈 96 · FR-071) 을 고치는 문.
/// 저장은 누른 자리에서 디스크에 닿고, 실패하면 이번에 바꾼 것을 되돌린다(`PersonStore` 와 같은 꼴).
@MainActor
struct TemplateStore {
    let context: ModelContext

    /// 틀 이름의 한도 — 칩 하나에 들어갈 만큼.
    static let nameLimit = 30

    private func commit() throws {
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: 기록 틀

    /// 만든 차례대로.
    func templates() -> [RecordTemplate] {
        ((try? context.fetch(FetchDescriptor<RecordTemplate>())) ?? [])
            .filter { !$0.isGone }
            .sorted { $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.uuid.uuidString < $1.uuid.uuidString }
    }

    /// 지금 초안의 유형 · 제목 · 장소 · 태그 · 함께한 사람을 틀로. 날짜 · 메모 · 사진은 넣지 않는다.
    @discardableResult
    func save(_ draft: RecordDraft, name: String) throws -> RecordTemplate? {
        let cleaned = String(TextNormalization.collapsedSpaces(TextNormalization.normalized(name)).prefix(Self.nameLimit))
        guard !cleaned.isEmpty else { return nil }
        let template = RecordTemplate(name: cleaned)
        context.insert(template)
        template.recordType = RecordType.named(draft.recordType).key
        template.title = TextNormalization.nilIfEmpty(draft.title).map { String($0.prefix(Limits.recordTitle)) }
        template.location = TextNormalization.nilIfEmpty(draft.location).map { String($0.prefix(Limits.location)) }
        template.tags = TagNormalizer.normalizeList(draft.tags)
        template.participantIDs = draft.participants.filter { !$0.isGone && !$0.isMe }.map(\.uuid.uuidString)
        try commit()
        return template
    }

    func rename(_ template: RecordTemplate, to name: String) throws {
        let cleaned = String(TextNormalization.collapsedSpaces(TextNormalization.normalized(name)).prefix(Self.nameLimit))
        guard !cleaned.isEmpty, cleaned != template.name else { return }
        let before = template.name
        template.name = cleaned
        template.updatedAt = Date()
        do {
            try commit()
        } catch {
            template.name = before
            throw error
        }
    }

    /// 화면이 확인을 받은 뒤 부른다 (모든 삭제에 확인 · CLAUDE.md).
    func delete(_ template: RecordTemplate) throws {
        guard !template.isGone else { return }
        context.delete(template)
        try commit()
    }

    /// 틀을 초안에 채운다 — 유형 · 제목 · 장소 · 태그는 틀로 바꾸고, 함께한 사람은 지금 사람에 **더한다**(기록을 연 사람은 남는다).
    /// 지운 사람은 건너뛴다. 날짜 · 시각 · 메모 · 사진 · 반복은 그대로.
    func fill(_ draft: inout RecordDraft, from template: RecordTemplate) {
        draft.recordType = template.recordType
        draft.title = template.title ?? ""
        draft.location = template.location ?? ""
        draft.tags = template.tags
        let ids = Set(template.participantIDs.compactMap(UUID.init(uuidString:)))
        guard !ids.isEmpty else { return }
        let people = ((try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? [])
            .filter { !$0.isGone && ids.contains($0.uuid) }
        let have = Set(draft.participants.map(\.persistentModelID))
        draft.participants += NameSort.sorted(people.filter { !have.contains($0.persistentModelID) }, name: \.name, createdAt: \.createdAt)
    }

    // MARK: 고쳐 둔 모임 이름

    /// 최근에 고친 것부터 — `Core.CommunityNaming.saved` 가 같은 점수면 앞의 것을 고른다.
    func communityLabels() -> [CommunityNaming.SavedLabel] {
        Self.labels(in: context)
    }

    nonisolated static func labels(in context: ModelContext) -> [CommunityNaming.SavedLabel] {
        ((try? context.fetch(FetchDescriptor<CommunityLabel>())) ?? [])
            .filter { !$0.isGone }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { CommunityNaming.SavedLabel(name: $0.name, members: $0.memberIDs) }
    }

    /// 모임 이름을 고친다 — 이 모임과 절반 넘게 겹치는 저장된 이름이 있으면 그것을 고치고(묶음도 지금으로), 없으면 새로.
    /// 이름을 비우면 겹치는 저장된 이름을 지운다(제안 이름으로 돌아간다).
    func renameCommunity(members: [UUID], to name: String) throws {
        let ids = members.map(\.uuidString)
        let cleaned = String(TextNormalization.collapsedSpaces(TextNormalization.normalized(name)).prefix(Self.nameLimit))
        let mine = Set(ids)
        let stored = ((try? context.fetch(FetchDescriptor<CommunityLabel>())) ?? []).filter { !$0.isGone }
        let overlapping = stored.filter { label in
            let theirs = Set(label.memberIDs)
            let union = mine.union(theirs).count
            return union > 0 && Double(mine.intersection(theirs).count) / Double(union) > 0.5
        }
        if cleaned.isEmpty {
            for label in overlapping { context.delete(label) }
        } else if let label = overlapping.max(by: { $0.updatedAt < $1.updatedAt }) {
            label.name = cleaned
            label.memberIDs = ids
            label.updatedAt = Date()
            for other in overlapping where other !== label { context.delete(other) }
        } else {
            context.insert(CommunityLabel(name: cleaned, memberIDs: ids))
        }
        try commit()
    }
}
