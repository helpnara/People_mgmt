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
    /// 처음 만난 날의 정밀도 (FR-033) — 월까지 · 연도만이면 그달 1일 · 그해 1월 1일로 저장한다.
    var firstMetPrecision = DatePrecision.day
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
    /// 아는 사이 (D-30) — 기록 없이 서로 아는 사람.
    var acquaintances: [Person] = []
    /// 생일 (5판 · D-40) — 켜면 월 · 일이 저장된다. 연도는 선택.
    var hasBirthday = false
    var birthMonth = 1
    var birthDay = 1
    var birthYear: Int?
    /// 연락 주기(개월) — 고른 사람만 (5판 · D-40).
    var contactCadenceMonths: Int?

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
        firstMetPrecision = .of(person.firstMetPrecision)
        firstNote = person.firstNote ?? ""
        contactNote = person.contactNote ?? ""
        mobilePhone = person.mobilePhone ?? ""
        officePhone = person.officePhone ?? ""
        faxNumber = person.faxNumber ?? ""
        email = person.email ?? ""
        tags = person.tags
        businessCard = person.businessCard
        acquaintances = person.acquaintances
        if let month = person.birthMonth, let day = person.birthDay {
            hasBirthday = true
            birthMonth = month
            birthDay = day
        }
        birthYear = person.birthYear
        contactCadenceMonths = person.contactCadenceMonths
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
    /// 최근 등록순 (FR-027 · 전수조사 이슈 23) — 방금 적은 사람부터. 하루 10명 입력 뒤 확인하기 좋게.
    case newest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "이름순"
        case .recent: return "최근 기록순"
        case .newest: return "최근 등록순"
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
        case .newest:
            // 등록 시각이 늦은 사람부터. 같으면 이름순 차례를 그대로 둔다 (먼저 이름순으로 줄 세우고 안정 정렬).
            let byName = NameSort.sorted(people, name: \.name, createdAt: \.createdAt)
            return byName.enumerated()
                .sorted { lhs, rhs in
                    lhs.element.createdAt != rhs.element.createdAt
                        ? lhs.element.createdAt > rhs.element.createdAt
                        : lhs.offset < rhs.offset
                }
                .map(\.element)
        }
    }

    /// 같은 이름을 가르는 열쇠 — **모든 공백을 지우고** 대소문자 · 조합을 무시한다 (FR-021 · 전수조사 이슈 22).
    /// `홍 길동` 과 `홍길동` 은 같은 이름이다. 동명이인 안내는 이 열쇠 하나로만 견준다.
    static func sameNameKey(_ name: String) -> String {
        NameSort.key(String(name.filter { !$0.isWhitespace }))
    }

    /// 같은 이름(공백 · 대소문자 무시)인 사람들. 동명이인 안내(FR-021)에 쓴다. 등록을 막지는 않는다.
    func sameName(as name: String, excluding: Person? = nil) -> [Person] {
        Self.sameName(as: name, in: (try? allPeople()) ?? [], excluding: excluding)
    }

    /// 이미 받아 둔 목록에서 같은 이름을 찾는다. **화면 본문에서는 이것을 쓴다** — 본문에서 저장소를 다시 읽지 않는다 (이슈 10).
    static func sameName(as name: String, in people: [Person], excluding: Person? = nil) -> [Person] {
        let key = sameNameKey(name)
        guard !key.isEmpty else { return [] }
        return people.filter { $0 !== excluding && !$0.isGone && sameNameKey($0.name) == key }
    }

    // MARK: 쓰기

    /// 저장하고, 실패하면 **이번에 바꾼 것을 모두 되돌린다** (전수조사 2026-10-18).
    /// 되돌리지 않으면 넣은 사람이 문맥에 남아 `다시 시도` 가 같은 사람을 하나 더 만들고, 수정을 `버리기` 해도
    /// 바뀐 값이 남았다가 다음 저장 때 디스크에 들어간다. 입력은 초안(`PersonDraft`)에 그대로 있어 다시 시도할 수 있다.
    private func commit() throws {
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

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
        try commit()
        return person
    }

    /// **나가 둘 이상이면 먼저 만든 나만 남긴다** (iCloud 동기화 · D-43) — 두 기기에서 따로 나를 적은 뒤 이어지면 생긴다.
    /// 나중 것은 지우지 않고 보통 사람으로 바꾼다(적은 내용을 잃지 않게). 바꾼 사람들의 이름을 돌려준다 — 화면이 한 번 알린다.
    @discardableResult
    func resolveDuplicateMe() throws -> [String] {
        let mine = try context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == true }))
            .filter { !$0.isGone }
            .sorted { $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.uuid.uuidString < $1.uuid.uuidString }
        guard mine.count > 1 else { return [] }
        let demoted = Array(mine.dropFirst())
        for person in demoted { person.isMe = false }
        try commit()
        let names = demoted.map(\.name)
        UserDefaults.standard.set(names, forKey: Self.demotedMeKey)
        return names
    }

    /// 나에서 보통 사람으로 바꾼 이름들 — 목록이 한 번 알리고 지운다.
    static let demotedMeKey = "sync.demotedMe"

    /// 여러 사람을 한 번에 저장한다 (vCard 가져오기 · D-41). 하나라도 실패하면 모두 되돌린다(`commit`).
    @discardableResult
    func createMany(_ drafts: [PersonDraft]) throws -> [Person] {
        let people = drafts.map { draft -> Person in
            let person = Person(name: TextNormalization.normalized(draft.name))
            context.insert(person)
            fill(person, from: draft)
            return person
        }
        try commit()
        return people
    }

    /// 실패하면 옛 값을 되돌려 쓴다 — `rollback()` 은 새로 넣은 것은 버리지만 **이미 있던 사람의 바뀐 칸은
    /// 되돌리지 않았다** (빌드 12 CI · `AuditFixTests`). 그대로 두면 `버리기` 를 해도 바뀐 값이 남았다가 자동 저장에 실린다.
    func apply(_ draft: PersonDraft, to person: Person) throws {
        let before = PersonDraft(person: person)
        let updatedAt = person.updatedAt
        fill(person, from: draft)
        person.updatedAt = Date()
        do {
            try commit()
        } catch {
            fill(person, from: before)
            person.updatedAt = updatedAt
            throw error
        }
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
        person.firstMetDate = draft.hasFirstMetDate
            ? ApproximateDate.noon(of: draft.firstMetDate, precision: draft.firstMetPrecision, calendar: .current) : nil
        person.firstMetPrecision = draft.hasFirstMetDate ? draft.firstMetPrecision.rawValue : 0
        person.firstNote = clipped(draft.firstNote, Limits.firstNote)
        person.contactNote = clipped(draft.contactNote, Limits.contactNote)
        person.mobilePhone = clipped(draft.mobilePhone, Limits.phone)
        person.officePhone = clipped(draft.officePhone, Limits.phone)
        person.faxNumber = clipped(draft.faxNumber, Limits.phone)
        person.email = clipped(draft.email, Limits.email)
        person.tags = TagNormalizer.normalizeList(draft.tags)
        // 같은 사진이면 다시 쓰지 않는다 — 바깥 파일을 매번 새로 쓰지 않게.
        if person.businessCard != draft.businessCard { person.businessCard = draft.businessCard }
        // 생일은 맞는 날일 때만 (2월 30일 · 4월 31일은 저장하지 않는다). 끄면 연도까지 비운다.
        if draft.hasBirthday, BirthdayRule.isValid(month: draft.birthMonth, day: draft.birthDay, year: draft.birthYear) {
            person.birthMonth = draft.birthMonth
            person.birthDay = draft.birthDay
            person.birthYear = draft.birthYear
        } else {
            person.birthMonth = nil
            person.birthDay = nil
            person.birthYear = nil
        }
        // 연락 주기는 나에게 없다 — 나와의 기록은 따로 없다.
        person.contactCadenceMonths = person.isMe ? nil : draft.contactCadenceMonths.flatMap { $0 > 0 ? $0 : nil }
        // 나는 아는 사이를 두지 않는다 — 나는 모두를 안다.
        if !person.isMe { syncTies(of: person, to: draft.acquaintances) }
    }

    /// 아는 사이를 고른 대로 맞춘다 (D-30) — 빠진 연결은 지우고 새 연결은 만든다. 같은 두 사람은 한 줄.
    private func syncTies(of person: Person, to wanted: [Person]) {
        var wantedByID: [PersistentIdentifier: Person] = [:]
        for other in wanted where other !== person && !other.isGone && !other.isMe {
            wantedByID[other.persistentModelID] = other
        }
        var existing: [PersistentIdentifier: Tie] = [:]
        for tie in person.tiesAsFirst ?? [] {
            guard let other = tie.second else { continue }
            if existing[other.persistentModelID] != nil { context.delete(tie) } else { existing[other.persistentModelID] = tie }
        }
        for tie in person.tiesAsSecond ?? [] {
            guard let other = tie.first else { continue }
            if existing[other.persistentModelID] != nil { context.delete(tie) } else { existing[other.persistentModelID] = tie }
        }
        for (id, tie) in existing where wantedByID[id] == nil {
            context.delete(tie)
        }
        for (id, other) in wantedByID where existing[id] == nil {
            let tie = Tie()
            context.insert(tie)
            tie.first = person
            tie.second = other
        }
    }

    /// 두 사람을 아는 사이로 잇는다 (아는 사이 후보 · 빌드 16). 이미 이어져 있으면 아무것도 하지 않는다.
    /// 나 · 지운 사람 · 자기 자신은 잇지 않는다. 실패하면 넣은 연결을 버린다(`commit`).
    func link(_ a: Person, _ b: Person) throws {
        guard a !== b, !a.isMe, !b.isMe, !a.isGone, !b.isGone else { return }
        let already = (a.tiesAsFirst ?? []).contains { $0.second === b } || (a.tiesAsSecond ?? []).contains { $0.first === b }
        guard !already else { return }
        let tie = Tie()
        context.insert(tie)   // 넣고 나서 잇는다 (스키마 4판의 규칙).
        tie.first = a
        tie.second = b
        try commit()
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
        if summary.sole == 0 {
            // 혼자 참여한 기록이 없으면 `기록 0건이 삭제되고` 를 말하지 않는다 (전수조사 이슈 19).
            return "'\(name)'\(Josa.eulReul(name)) 삭제하시겠습니까? 다른 사람과 함께한 기록 \(summary.shared)건에서 이 사람만 빠지고, 기록은 남습니다. 되돌릴 수 없습니다."
        }
        return "'\(name)'\(Josa.eulReul(name)) 삭제하시겠습니까? 기록 \(summary.sole)건이 삭제되고, 다른 사람과 함께한 기록 \(summary.shared)건에서는 이 사람만 빠집니다. 되돌릴 수 없습니다."
    }

    /// 사람을 지운다. 혼자 참여한 기록은 함께, 공동 기록에서는 빠지기만, 소개자 칸은 비워진다(nullify).
    func delete(_ person: Person) throws {
        for record in person.records ?? [] where (record.participants ?? []).count <= 1 {
            context.delete(record)
        }
        context.delete(person)
        try commit()
    }
}

// MARK: - 검색이 보는 값 (Core 는 SwiftData 를 모른다)

extension SearchablePerson {
    /// 주 스레드에 묶지 않는다 — 검색 색인은 따로 연 문맥에서 만든다 (이슈 8 · `SearchIndexBuilder`).
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
