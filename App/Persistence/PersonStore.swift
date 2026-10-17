import Core
import Foundation
import SwiftData

/// 사람 추가 · 수정 화면이 들고 있는 값. 저장할 때 `PersonStore` 가 모델에 옮긴다.
///
/// 화면이 모델을 직접 묶지 않는 이유 — 취소하면 되돌려야 하고(미저장 변경 보호, FR-022),
/// 저장 실패 때 입력 내용을 그대로 쥐고 있어야 한다(FR-023).
struct PersonDraft: Equatable {
    var name = ""
    var nickname = ""
    var organization = ""
    var role = ""
    var relationshipType: String?
    var metThrough: String?
    var introducedBy: Person?
    var hasFirstMetDate = false
    var firstMetDate = Date()
    var firstNote = ""
    var tags: [String] = []

    init() {}

    init(person: Person) {
        name = person.name
        nickname = person.nickname ?? ""
        organization = person.organization ?? ""
        role = person.role ?? ""
        relationshipType = person.relationshipType
        metThrough = person.metThrough
        introducedBy = person.introducedBy
        hasFirstMetDate = person.firstMetDate != nil
        firstMetDate = person.firstMetDate ?? Date()
        firstNote = person.firstNote ?? ""
        tags = person.tags
    }

    var nameProblem: String? { PersonValidation.nameProblem(name) }
    var canSave: Bool { nameProblem == nil }
}

/// 사람을 고치는 **유일한 문** (요구사항 8.1 아키텍처). 화면은 읽기만 `@Query` 로 하고 쓰기는 여기로 온다.
/// 저장은 사용자가 `저장` 을 누른 그 자리에서 디스크에 닿는다 — 지연 저장으로 잃는 일이 없게.
@MainActor
struct PersonStore {
    let context: ModelContext

    // MARK: 읽기

    func allPeople() throws -> [Person] {
        try context.fetch(FetchDescriptor<Person>())
    }

    /// 이름순 (요구사항 6.7). 정렬 규칙은 `Core.NameSort` 한 곳이다.
    func sortedPeople() throws -> [Person] {
        try allPeople().sorted {
            NameSort.areInIncreasingOrder((name: $0.name, createdAt: $0.createdAt),
                                          (name: $1.name, createdAt: $1.createdAt))
        }
    }

    /// 같은 이름(공백 · 대소문자 무시)인 사람들. 동명이인 안내(FR-021)에 쓴다. 등록을 막지는 않는다.
    func sameName(as name: String, excluding: Person? = nil) -> [Person] {
        let key = NameSort.key(name)
        guard !key.isEmpty else { return [] }
        let all = (try? allPeople()) ?? []
        return all.filter { NameSort.key($0.name) == key && $0 !== excluding }
    }

    // MARK: 쓰기

    func create(_ draft: PersonDraft) throws -> Person {
        let person = Person(name: TextNormalization.normalized(draft.name))
        context.insert(person)
        fill(person, from: draft)
        try context.save()
        return person
    }

    func apply(_ draft: PersonDraft, to person: Person) throws {
        fill(person, from: draft)
        person.updatedAt = Date()
        try context.save()
    }

    private func fill(_ person: Person, from draft: PersonDraft) {
        person.name = String(TextNormalization.normalized(draft.name).prefix(Limits.name))
        person.nickname = clipped(draft.nickname, Limits.nickname)
        person.organization = clipped(draft.organization, Limits.organization)
        person.role = clipped(draft.role, Limits.role)
        person.relationshipType = clipped(draft.relationshipType ?? "", Limits.relationshipType)
        person.metThrough = clipped(draft.metThrough ?? "", Limits.metThrough)
        // 소개자는 경로가 "소개" 일 때만 뜻이 있고, 자기 자신일 수 없다.
        if draft.metThrough == RelationshipPresets.introducedLabel,
           let introducer = draft.introducedBy, introducer !== person, !introducer.isGone {
            person.introducedBy = introducer
        } else {
            person.introducedBy = nil
        }
        person.firstMetDate = draft.hasFirstMetDate ? DayNormalizer.noon(of: draft.firstMetDate, calendar: .current) : nil
        person.firstNote = clipped(draft.firstNote, Limits.firstNote)
        person.tags = TagNormalizer.normalizeList(draft.tags)
    }

    private func clipped(_ text: String, _ limit: Int) -> String? {
        guard let cleaned = TextNormalization.nilIfEmpty(text) else { return nil }
        return String(cleaned.prefix(limit))
    }

    // MARK: 삭제 (요구사항 6.5 · 7.6)

    struct DeletionSummary {
        /// 이 사람만 참여한 기록 — 함께 지워진다.
        let sole: Int
        /// 다른 사람도 참여한 기록 — 이 사람만 빠진다.
        let shared: Int
    }

    func deletionSummary(for person: Person) -> DeletionSummary {
        var sole = 0
        var shared = 0
        for record in person.records ?? [] {
            if (record.participants ?? []).count <= 1 { sole += 1 } else { shared += 1 }
        }
        return DeletionSummary(sole: sole, shared: shared)
    }

    /// 확인 창에 보여 줄 문장. 삭제 범위를 숫자로 말한다 (7.6).
    func deletionMessage(for person: Person) -> String {
        let summary = deletionSummary(for: person)
        let name = person.name
        if summary.sole == 0 && summary.shared == 0 {
            return "'\(name)'\(Josa.eulReul(name)) 삭제하시겠습니까? 되돌릴 수 없습니다."
        }
        if summary.shared == 0 {
            return "'\(name)'\(Josa.gwaWa(name)) 기록 \(summary.sole)건을 모두 삭제하시겠습니까? 되돌릴 수 없습니다."
        }
        return "'\(name)'\(Josa.eulReul(name)) 삭제하시겠습니까? 기록 \(summary.sole)건이 삭제되고, 다른 사람과 함께한 기록 \(summary.shared)건에서는 이 사람만 빠집니다. 되돌릴 수 없습니다."
    }

    /// 사람을 지운다. 혼자 참여한 기록은 함께, 공동 기록에서는 빠지기만, 소개자 칸은 비워진다(nullify).
    func delete(_ person: Person) throws {
        for record in person.records ?? [] where (record.participants ?? []).count <= 1 {
            context.delete(record)
        }
        context.delete(person)
        try context.save()
    }
}

// MARK: - 검색이 보는 값 (Core 는 SwiftData 를 모른다)

extension SearchablePerson {
    @MainActor
    init(person: Person) {
        self.init(
            id: person.uuid,
            name: person.name,
            nickname: person.nickname,
            organization: person.organization,
            role: person.role,
            relationshipType: person.relationshipType,
            metThrough: person.metThrough,
            firstNote: person.firstNote,
            tags: person.tags,
            records: (person.records ?? [])
                .sorted { $0.occurredAt > $1.occurredAt }
                .map { record in
                    SearchableRecord(
                        id: record.uuid,
                        displayTitle: DisplayTitle.make(title: record.title, note: record.note),
                        title: record.title,
                        note: record.note,
                        location: record.location,
                        tags: record.tags)
                })
    }
}
