import Foundation

/// **한 사람 내보내기** (FR-014 · D-54) — 한 사람의 정보와 기록 전체를 Markdown 글 하나로. PDF 도 이 글에서 그린다.
///
/// 날짜 · 유형 같은 **보이는 글은 부르는 쪽이 만들어 넘긴다**(기기 형식 · 정밀도) — 여기는 차례와 모양만 정한다.
/// 빈 칸은 줄을 쓰지 않는다. 정답표 `personExport` 가 대조한다.
public enum PersonExport {

    public struct Record: Sendable, Equatable {
        public var date: String
        public var type: String
        public var title: String
        public var note: String?
        public var location: String?
        public var tags: [String]
        public var companions: [String]

        public init(date: String, type: String, title: String, note: String? = nil, location: String? = nil,
                    tags: [String] = [], companions: [String] = []) {
            self.date = date
            self.type = type
            self.title = title
            self.note = note
            self.location = location
            self.tags = tags
            self.companions = companions
        }
    }

    public struct Contact: Sendable, Equatable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public struct Person: Sendable, Equatable {
        public var name: String
        public var nickname: String?
        public var organization: String?
        public var role: String?
        public var relationshipType: String?
        public var metThrough: String?
        public var introducer: String?
        public var birthday: String?
        public var tags: [String]
        public var contacts: [Contact]
        /// 처음 만난 날의 보이는 글. 없으면 nil — 첫 인연 메모만 있으면 `날짜 미상` 으로 쓴다.
        public var firstMet: String?
        public var firstNote: String?
        /// 타임라인 차례(최신순)로.
        public var records: [Record]
        /// 맨 아래 한 줄 — `2026년 10월 20일` 처럼.
        public var exportedOn: String

        public init(name: String, nickname: String? = nil, organization: String? = nil, role: String? = nil,
                    relationshipType: String? = nil, metThrough: String? = nil, introducer: String? = nil,
                    birthday: String? = nil, tags: [String] = [], contacts: [Contact] = [], firstMet: String? = nil,
                    firstNote: String? = nil, records: [Record] = [], exportedOn: String) {
            self.name = name
            self.nickname = nickname
            self.organization = organization
            self.role = role
            self.relationshipType = relationshipType
            self.metThrough = metThrough
            self.introducer = introducer
            self.birthday = birthday
            self.tags = tags
            self.contacts = contacts
            self.firstMet = firstMet
            self.firstNote = firstNote
            self.records = records
            self.exportedOn = exportedOn
        }
    }

    public static func markdown(_ person: Person) -> String {
        func filled(_ text: String?) -> String? {
            guard let text else { return nil }
            let cleaned = TextNormalization.normalized(text)
            return cleaned.isEmpty ? nil : cleaned
        }
        func hashTags(_ tags: [String]) -> String? {
            tags.isEmpty ? nil : tags.map { "#" + $0 }.joined(separator: " ")
        }
        var lines = ["# \(TextNormalization.normalized(person.name))", ""]

        var facts: [String] = []
        if let nickname = filled(person.nickname) { facts.append("- 별명: \(nickname)") }
        let work = [filled(person.organization), filled(person.role)].compactMap { $0 }
        if !work.isEmpty { facts.append("- 소속: \(work.joined(separator: " · "))") }
        if let type = filled(person.relationshipType) { facts.append("- 관계 유형: \(type)") }
        if let path = filled(person.metThrough) {
            if let introducer = filled(person.introducer) {
                facts.append("- 알게 된 경로: \(path) (\(introducer)의 소개)")
            } else {
                facts.append("- 알게 된 경로: \(path)")
            }
        }
        if let birthday = filled(person.birthday) { facts.append("- 생일: \(birthday)") }
        if let tags = hashTags(person.tags) { facts.append("- 태그: \(tags)") }
        if !facts.isEmpty { lines += facts + [""] }

        let contacts = person.contacts.compactMap { contact in filled(contact.value).map { "- \(contact.label): \($0)" } }
        if !contacts.isEmpty { lines += ["## 연락 수단", ""] + contacts + [""] }

        let firstMet = filled(person.firstMet)
        let firstNote = filled(person.firstNote)
        if firstMet != nil || firstNote != nil {
            lines += ["## 첫 인연", "", firstMet ?? "날짜 미상", ""]
            if let firstNote { lines += [firstNote, ""] }
        }

        lines += ["## 기록 \(person.records.count)건", ""]
        if person.records.isEmpty {
            lines += ["아직 기록이 없습니다.", ""]
        }
        for record in person.records {
            lines.append("### \(record.date) · \(record.type) · \(TextNormalization.normalized(record.title))")
            lines.append("")
            var details: [String] = []
            if !record.companions.isEmpty { details.append("- 함께한 사람: \(record.companions.joined(separator: ", "))") }
            if let location = filled(record.location) { details.append("- 장소: \(location)") }
            if let tags = hashTags(record.tags) { details.append("- 태그: \(tags)") }
            if !details.isEmpty { lines += details + [""] }
            if let note = filled(record.note) { lines += [note, ""] }
        }

        lines += ["---", "", "느린 인연에서 \(person.exportedOn)에 내보냄"]
        return lines.joined(separator: "\n") + "\n"
    }
}
