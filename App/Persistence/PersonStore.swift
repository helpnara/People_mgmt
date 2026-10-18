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
    /// 연락 수단 기타 (FR-032). 네 칸에 들지 않는 번호 · 메일 · 메모.
    var contactNote = ""
    var mobilePhone = ""
    var officePhone = ""
    var faxNumber = ""
    var email = ""
    var tags: [String] = []
    /// 명함 사진 (FR-050). JPEG.
    var businessCard: Data?

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
        contactNote = person.contactNote ?? ""
        mobilePhone = person.mobilePhone ?? ""
        officePhone = person.officePhone ?? ""
        faxNumber = person.faxNumber ?? ""
        email = person.email ?? ""
        tags = person.tags
        businessCard = person.businessCard
    }

    /// 다섯 칸을 한꺼번에 — 명함 · 연락처에서 가져온 값을 넣을 때. 빈 칸은 덮지 않는다.
    mutating func fill(_ fields: ContactFields) {
        if !fields.mobile.isEmpty { mobilePhone = String(fields.mobile.prefix(Limits.phone)) }
        if !fields.office.isEmpty { officePhone = String(fields.office.prefix(Limits.phone)) }
        if !fields.fax.isEmpty { faxNumber = String(fields.fax.prefix(Limits.phone)) }
        if !fields.email.isEmpty { email = String(fields.email.prefix(Limits.email)) }
        if !fields.other.isEmpty { contactNote = String(fields.other.prefix(Limits.contactNote)) }
    }

    var nameProblem: String? { PersonValidation.nameProblem(name) }
    var canSave: Bool { nameProblem == nil }
}

/// 사람 목록 정렬 (FR-027). 기기 편의라 `UserDefaults` 에 두고 iCloud 로 보내지 않는다.
enum PeopleSortOption: String, CaseIterable, Identifiable {
    case name
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "이름순"
        case .recent: return "최근 기록순"
        }
    }
}

/// 사람을 고치는 **유일한 문** (요구사항 8.1 아키텍처). 화면은 읽기만 `@Query` 로 하고 쓰기는 여기로 온다.
/// 저장은 사용자가 `저장` 을 누른 그 자리에서 디스크에 닿는다 — 지연 저장으로 잃는 일이 없게.
@MainActor
struct PersonStore {
    let context: ModelContext

    // MARK: 읽기

    /// 나를 뺀 사람 전원. 나는 사람 수 · 검색 · 정렬 · 고르기에 들지 않는다 (이슈 12).
    func allPeople() throws -> [Person] {
        try context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))
    }

    /// 나. 없으면 `nil`.
    func me() throws -> Person? {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == true })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 이름순 (요구사항 6.7). 정렬 규칙은 `Core.NameSort` 한 곳이다.
    func sortedPeople() throws -> [Person] {
        Self.sorted(try allPeople(), by: .name)
    }

    /// 목록 정렬 (FR-027). 규칙은 Core 의 `NameSort` · `RecencySort` 다 — 화면은 이것만 부른다.
    static func sorted(_ people: [Person], by option: PeopleSortOption) -> [Person] {
        switch option {
        case .name:
            return NameSort.sorted(people, name: \.name, createdAt: \.createdAt)
        case .recent:
            return RecencySort.sorted(people, lastRecordAt: \.lastRecordAt, name: \.name, createdAt: \.createdAt)
        }
    }

    /// 같은 이름(공백 · 대소문자 무시)인 사람들. 동명이인 안내(FR-021)에 쓴다. 등록을 막지는 않는다.
    func sameName(as name: String, excluding: Person? = nil) -> [Person] {
        Self.sameName(as: name, in: (try? allPeople()) ?? [], excluding: excluding)
    }

    /// 이미 받아 둔 목록에서 같은 이름을 찾는다. **화면 본문에서는 이것을 쓴다** — 본문에서 저장소를 다시 읽지 않는다 (이슈 10).
    static func sameName(as name: String, in people: [Person], excluding: Person? = nil) -> [Person] {
        let key = NameSort.key(name)
        guard !key.isEmpty else { return [] }
        return people.filter { $0 !== excluding && !$0.isGone && NameSort.key($0.name) == key }
    }

    // MARK: 쓰기

    /// `isMe` 면 **나**로 만든다 (이슈 12). 나는 하나뿐이다 — 이미 있으면 그 사람을 고친다.
    func create(_ draft: PersonDraft, isMe: Bool = false) throws -> Person {
        if isMe, let existing = try me() {
            try apply(draft, to: existing)
            return existing
        }
        let person = Person(name: TextNormalization.normalized(draft.name))
        person.isMe = isMe
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
        person.contactNote = clipped(draft.contactNote, Limits.contactNote)
        person.mobilePhone = clipped(draft.mobilePhone, Limits.phone)
        person.officePhone = clipped(draft.officePhone, Limits.phone)
        person.faxNumber = clipped(draft.faxNumber, Limits.phone)
        person.email = clipped(draft.email, Limits.email)
        person.tags = TagNormalizer.normalizeList(draft.tags)
        // 같은 사진이면 다시 쓰지 않는다 — 바깥 파일을 매번 새로 쓰지 않게.
        if person.businessCard != draft.businessCard { person.businessCard = draft.businessCard }
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
