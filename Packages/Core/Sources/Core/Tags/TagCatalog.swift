import Foundation

/// **태그 모음** (FR-026 태그 관리) — 앱 안에 있는 태그와 쓰인 수. 자동완성 · 이름 바꾸기 · 합치기가 이 하나를 쓴다.
///
/// - 같은 태그인지는 `TagNormalizer.key` 하나로 가린다 (`#멘토` · `멘토` · `Mentor` 와 `mentor`).
/// - 표기가 여럿이면(`Mentor` · `mentor`) 문자열 차례로 앞서는 것을 보인다 — 읽은 차례와 상관없이 늘 같게.
/// - 쓰인 수는 사람 수 · 기록 수 — 한 사람(한 기록)에 같은 태그가 두 번 있어도 하나로 센다.
/// - 차례는 많이 쓴 태그부터, 같으면 이름 순(`NameSort.key`).
public struct TagCatalog: Sendable, Equatable {

    public struct Entry: Sendable, Equatable, Identifiable {
        public let tag: String
        public let people: Int
        public let records: Int

        public var id: String { TagNormalizer.key(tag) ?? tag }
        public var total: Int { people + records }

        public init(tag: String, people: Int, records: Int) {
            self.tag = tag
            self.people = people
            self.records = records
        }
    }

    public let entries: [Entry]

    public init(personTags: [[String]], recordTags: [[String]]) {
        var shown: [String: String] = [:]
        var people: [String: Int] = [:]
        var records: [String: Int] = [:]
        func count(_ lists: [[String]], into counts: inout [String: Int]) {
            for list in lists {
                var seen = Set<String>()
                for raw in list {
                    guard let tag = TagNormalizer.normalize(raw), let key = TagNormalizer.key(tag) else { continue }
                    if let current = shown[key] {
                        if tag < current { shown[key] = tag }
                    } else {
                        shown[key] = tag
                    }
                    if seen.insert(key).inserted { counts[key, default: 0] += 1 }
                }
            }
        }
        count(personTags, into: &people)
        count(recordTags, into: &records)
        entries = shown
            .map { key, tag in Entry(tag: tag, people: people[key] ?? 0, records: records[key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                let lk = NameSort.key(lhs.tag), rk = NameSort.key(rhs.tag)
                if lk != rk { return lk < rk }
                return lhs.tag < rhs.tag
            }
    }

    /// 이 태그(같은 열쇠)의 줄. 없으면 `nil`.
    public func entry(for tag: String) -> Entry? {
        guard let key = TagNormalizer.key(tag) else { return nil }
        return entries.first { $0.id == key }
    }

    /// 치는 중인 글자에 맞는 태그 — **자동완성**. 이미 붙인 태그는 뺀다. 빈 글자면 없다.
    ///
    /// 맞추기는 검색과 같은 규칙(`FoldedText` · 초성 포함). 글자로 **시작하는** 태그가 먼저, 그다음 많이 쓴 순.
    public func suggestions(for input: String, excluding chosen: [String], limit: Int = 8) -> [String] {
        let term = TextNormalization.folded(TagNormalizer.normalize(input) ?? "")
        guard !term.isEmpty else { return [] }
        let taken = Set(chosen.compactMap(TagNormalizer.key))
        var starts: [String] = []
        var inside: [String] = []
        for entry in entries where !taken.contains(entry.id) {
            let text = FoldedText(entry.tag)
            guard text.contains(term) else { continue }
            if text.folded.hasPrefix(term) { starts.append(entry.tag) } else { inside.append(entry.tag) }
        }
        return Array((starts + inside).prefix(limit))
    }

    /// 태그 목록에서 `from` 을 `to` 로 바꾼다 — **이름 바꾸기 · 합치기**가 같은 규칙이다.
    /// 바꾼 뒤 같은 태그가 둘이 되면(합치기) 앞의 것만 남는다(`TagNormalizer.normalizeList`).
    /// `to` 가 태그가 될 수 없으면(빈 것 · 30자 넘음) 그대로 돌려준다.
    public static func renamed(_ tags: [String], from: String, to: String) -> [String] {
        guard let target = TagNormalizer.normalize(to), let key = TagNormalizer.key(from) else { return tags }
        let replaced = tags.map { TagNormalizer.key($0) == key ? target : $0 }
        return TagNormalizer.normalizeList(replaced)
    }
}

/// **목록 거르기** (FR-013) — 사람 목록은 관계 유형 · 태그로, 타임라인은 기록 유형 · 태그로.
///
/// 고른 것이 둘이면 둘 다 맞아야 한다. `nil` 은 거르지 않는다. 유형은 `NameSort.key`, 태그는 `TagNormalizer.key` 로 견준다.
public enum ListFilter {
    public static func matches(type: String?, tags: [String], wantedType: String?, wantedTag: String?) -> Bool {
        if let wantedType {
            guard let type, NameSort.key(type) == NameSort.key(wantedType) else { return false }
        }
        if let wantedTag {
            guard let key = TagNormalizer.key(wantedTag), tags.contains(where: { TagNormalizer.key($0) == key }) else { return false }
        }
        return true
    }

    /// 고를 수 있는 유형 — 쓰인 것만, 많이 쓴 순, 같으면 이름 순. 표기는 처음 나온 것.
    public static func typeChoices(_ types: [String?]) -> [String] {
        var shown: [String: String] = [:]
        var counts: [String: Int] = [:]
        var order: [String] = []
        for case let type? in types {
            let cleaned = TextNormalization.normalized(type)
            let key = NameSort.key(cleaned)
            guard !key.isEmpty else { continue }
            if shown[key] == nil {
                shown[key] = cleaned
                order.append(key)
            }
            counts[key, default: 0] += 1
        }
        return order
            .sorted { lhs, rhs in
                let lc = counts[lhs] ?? 0, rc = counts[rhs] ?? 0
                if lc != rc { return lc > rc }
                return lhs < rhs
            }
            .compactMap { shown[$0] }
    }
}
