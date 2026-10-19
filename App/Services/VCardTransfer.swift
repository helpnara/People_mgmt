import Core
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// **vCard 내보내기 · 가져오기** (빌드 18 · D-41) — 만들기 · 읽기 · 같은 사람 판정은 Core(`VCard` · `ImportMatcher`, 정답표).
/// 여기서는 저장소와 잇기만 한다. 읽기 · 판정은 **따로 연 문맥**에서 — 5,000명이어도 주 스레드를 막지 않는다.
enum VCardTransfer {
    /// 미리보기 한 줄 — 넣을지 말지는 화면이 고른다.
    struct Item: Identifiable, Sendable {
        let id: Int
        let person: VCardPerson
        let verdict: ImportMatcher.Verdict
        /// 겹치는 기존 사람의 이름 (같은 사람 후보 · 이미 있음).
        let existingName: String?
    }

    static func fileName(now: Date = Date()) -> String {
        "느린인연-연락처-" + now.formatted(.iso8601.year().month().day())
    }

    /// 나를 뺀 사람 전부를 .vcf 한 파일로. 이름 순.
    static func export(container: ModelContainer) async -> (data: Data, count: Int) {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let people = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? []
            let sorted = NameSort.sorted(people, name: \.name, createdAt: \.createdAt)
            let cards = sorted.map { person in
                VCardPerson(name: person.name, nickname: person.nickname ?? "", organization: person.organization ?? "",
                            role: person.role ?? "",
                            fields: ContactFields(mobile: person.mobilePhone ?? "", office: person.officePhone ?? "",
                                                  fax: person.faxNumber ?? "", email: person.email ?? "",
                                                  other: person.contactNote ?? ""),
                            birthMonth: person.birthMonth, birthDay: person.birthDay, birthYear: person.birthYear)
            }
            return (Data(VCard.encode(cards).utf8), cards.count)
        }.value
    }

    /// 파일을 읽어 사람마다 새 사람 · 같은 사람 후보 · 이미 있음으로 가른다.
    static func preview(url: URL, container: ModelContainer) async throws -> [Item] {
        try await Task.detached(priority: .userInitiated) { () throws -> [Item] in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? String(decoding: data, as: UTF8.self)
            let incoming = VCard.parse(text)
            let context = ModelContext(container)
            let people = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? []
            let sorted = NameSort.sorted(people, name: \.name, createdAt: \.createdAt)
            let existing = sorted.map { person in
                ImportMatcher.Existing(id: person.uuid, name: person.name,
                                       fields: ContactFields(mobile: person.mobilePhone ?? "", office: person.officePhone ?? "",
                                                             fax: person.faxNumber ?? "", email: person.email ?? ""))
            }
            var names: [UUID: String] = [:]
            for person in sorted { names[person.uuid] = person.name }
            let matches = ImportMatcher.classify(incoming, existing: existing)
            return zip(incoming, matches).enumerated().map { index, pair in
                Item(id: index, person: pair.0, verdict: pair.1.verdict, existingName: pair.1.existingID.flatMap { names[$0] })
            }
        }.value
    }

    /// 사람 추가 화면이 쓰는 초안으로 — 저장은 `PersonStore` 한 문으로.
    static func draft(_ person: VCardPerson) -> PersonDraft {
        var draft = PersonDraft()
        draft.name = person.name
        draft.nickname = person.nickname
        draft.organization = person.organization
        draft.role = person.role
        draft.fill(person.fields)
        if let month = person.birthMonth, let day = person.birthDay {
            draft.hasBirthday = true
            draft.birthMonth = month
            draft.birthDay = day
            draft.birthYear = person.birthYear
        }
        return draft
    }
}
