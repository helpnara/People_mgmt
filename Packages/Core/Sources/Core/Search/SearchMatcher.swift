import Foundation

/// 검색이 보는 **사람의 값들**. 저장 계층의 객체를 여기로 베껴 넘긴다 —
/// Core 는 SwiftData 를 모르고, 값 구조체라 어느 스레드에서든 안전하다.
public struct SearchablePerson: Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var nickname: String?
    public var organization: String?
    public var role: String?
    public var relationshipType: String?
    public var metThrough: String?
    public var firstNote: String?
    public var tags: [String]
    public var records: [SearchableRecord]

    public init(id: UUID, name: String, nickname: String? = nil, organization: String? = nil,
                role: String? = nil, relationshipType: String? = nil, metThrough: String? = nil,
                firstNote: String? = nil, tags: [String] = [], records: [SearchableRecord] = []) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.organization = organization
        self.role = role
        self.relationshipType = relationshipType
        self.metThrough = metThrough
        self.firstNote = firstNote
        self.tags = tags
        self.records = records
    }
}

public struct SearchableRecord: Sendable, Equatable {
    public var id: UUID
    public var displayTitle: String
    public var title: String?
    public var note: String?
    public var location: String?
    public var tags: [String]

    public init(id: UUID, displayTitle: String, title: String? = nil, note: String? = nil,
                location: String? = nil, tags: [String] = []) {
        self.id = id
        self.displayTitle = displayTitle
        self.title = title
        self.note = note
        self.location = location
        self.tags = tags
    }
}

/// 어디서 일치했나. 숫자가 작을수록 결과에서 앞에 선다 (요구사항 4.2.6).
public enum MatchKind: Int, Sendable, Comparable, CaseIterable {
    case name = 0
    case tag = 1
    case personField = 2
    case recordField = 3

    public static func < (lhs: MatchKind, rhs: MatchKind) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 정답표(JSON)와 맞출 때 쓰는 이름.
    public var label: String {
        switch self {
        case .name: return "name"
        case .tag: return "tag"
        case .personField: return "person"
        case .recordField: return "record"
        }
    }
}

/// 검색 결과 한 줄. 사람 하나에 하나다.
public struct SearchHit: Sendable, Equatable {
    public let personID: UUID
    public let kind: MatchKind
    /// 화면에 한 줄로 보여 줄 근거. 예: `기록 '분기 회의' 메모 일치`
    public let evidence: String
    /// 정렬용 이름 열쇠.
    public let nameKey: String
    /// 기록에서 일치했으면 그 기록 (FR-034 — 결과를 누르면 그 기록으로 바로 간다). 사람 칸에서 일치하면 `nil`.
    public let recordID: UUID?
}

public enum SearchMatcher {

    private struct Match {
        let kind: MatchKind
        let evidence: String
        var recordID: UUID? = nil
    }

    /// 사람 하나가 낱말 하나에 어디서 일치하는지 — **제일 앞서는 자리** 하나.
    /// 검사 순서가 곧 순위다: 이름 → 태그 → 사람의 다른 칸 → 기록.
    private static func bestMatch(of term: SearchQuery.Term, in person: SearchablePerson) -> Match? {
        func has(_ value: String?) -> Bool {
            guard let value else { return false }
            return TextNormalization.folded(value).contains(term.text)
        }

        if !term.tagOnly, has(person.name) {
            return Match(kind: .name, evidence: "이름 일치")
        }
        if let tag = person.tags.first(where: { has($0) }) {
            return Match(kind: .tag, evidence: "태그 #\(tag) 일치")
        }
        if !term.tagOnly {
            let fields: [(String?, String)] = [
                (person.nickname, "별명 일치"),
                (person.organization, "소속 일치"),
                (person.role, "직무 일치"),
                (person.relationshipType, "관계 유형 일치"),
                (person.metThrough, "알게 된 경로 일치"),
                (person.firstNote, "첫 인연 메모 일치"),
            ]
            for (value, evidence) in fields where has(value) {
                return Match(kind: .personField, evidence: evidence)
            }
        }
        for record in person.records {
            if !term.tagOnly {
                if has(record.title) { return Match(kind: .recordField, evidence: "기록 '\(record.displayTitle)' 제목 일치", recordID: record.id) }
                if has(record.note) { return Match(kind: .recordField, evidence: "기록 '\(record.displayTitle)' 메모 일치", recordID: record.id) }
                if has(record.location) { return Match(kind: .recordField, evidence: "기록 '\(record.displayTitle)' 장소 일치", recordID: record.id) }
            }
            if let tag = record.tags.first(where: { has($0) }) {
                return Match(kind: .recordField, evidence: "기록 '\(record.displayTitle)' 태그 #\(tag) 일치", recordID: record.id)
            }
        }
        return nil
    }

    /// 낱말이 **모두** 일치하는 사람만. 결과의 등급은 낱말들 중 **가장 뒤처진 자리**다 —
    /// 한 낱말이 기록 메모에서만 걸렸으면 그 사람은 "기록 일치" 다. 근거도 그 낱말의 것을 쓴다.
    public static func hits(_ query: SearchQuery, in people: [SearchablePerson]) -> [SearchHit] {
        guard !query.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for person in people {
            var worst: Match?
            var allMatched = true
            for term in query.terms {
                guard let match = bestMatch(of: term, in: person) else {
                    allMatched = false
                    break
                }
                if let current = worst {
                    if match.kind > current.kind { worst = match }
                } else {
                    worst = match
                }
            }
            guard allMatched, let decisive = worst else { continue }
            hits.append(SearchHit(personID: person.id, kind: decisive.kind,
                                  evidence: decisive.evidence, nameKey: NameSort.key(person.name),
                                  recordID: decisive.recordID))
        }
        return hits.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
            if lhs.nameKey != rhs.nameKey { return lhs.nameKey < rhs.nameKey }
            return lhs.personID.uuidString < rhs.personID.uuidString
        }
    }
}
