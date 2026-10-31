import Foundation

/// **아는 사이 후보** (빌드 16 · 조사 보고서 지금 5) — 입력이 병목이다. 앱이 이미 아는 **사실**로 "아는 사이로 이을까요?" 를 묻는다.
///
/// - 근거는 둘뿐이다: 같은 기록에 함께 나온 횟수, 같은 사람이 둘 다 소개함. **점수 · 퍼센트는 없다** (ADR-0004).
/// - 이미 아는 사이 · 한쪽이 다른 쪽을 소개 · `아니요` 한 쌍은 뺀다. 자동으로 잇지 않는다 — 사람이 `잇기` 를 눌러야 한다.
/// - 차례: 함께한 기록 수가 많은 쌍 → 같은 소개자가 있는 쌍 → 이름 순. 쌍 안에서도 이름이 앞선 사람이 먼저.
/// - 같은 사람이 소개한 사람이 너무 많으면(12명 넘게) 그 무리는 쌍으로 펴지 않는다 — 100명이면 4,950쌍이 된다.
///
/// 선은 `RelationGraph.edges` 가 만든 것을 그대로 받는다 — 같은 것을 재는 곳은 하나다.
/// 파이썬 정답표(`Tools/golden` 의 `acquaintanceSuggestions`)와 같은 셈이다.
public enum AcquaintanceSuggestions {
    public static let limit = 30
    public static let introducerGroupLimit = 12

    public struct Suggestion: Sendable, Hashable {
        /// 이름이 앞선 사람.
        public let a: UUID
        public let b: UUID
        /// 둘이 함께 나온 기록 수.
        public let together: Int
        /// 둘을 모두 소개한 사람.
        public let introducer: UUID?
    }

    /// `아니요` 를 기억하는 열쇠 — 두 사람의 차례와 상관없이 같다.
    public static func pairKey(_ x: UUID, _ y: UUID) -> String {
        let a = x.uuidString, b = y.uuidString
        return a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    /// 저장해 둔 열쇠를 다시 맞춘다 — 차례 · 대소문자가 달라도 같은 쌍으로.
    static func normalizedKey(_ stored: String) -> String? {
        let parts = stored.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2, let x = UUID(uuidString: String(parts[0])), let y = UUID(uuidString: String(parts[1])) else { return nil }
        return pairKey(x, y)
    }

    public static func suggest(people: [GraphPerson], edges: [GraphEdge], declined: [String],
                               limit: Int = limit) -> [Suggestion] {
        var byID: [UUID: GraphPerson] = [:]
        for person in people { byID[person.id] = person }
        let declinedKeys = Set(declined.compactMap(normalizedKey))
        var edgeByKey: [String: GraphEdge] = [:]
        for edge in edges { edgeByKey[pairKey(edge.a, edge.b)] = edge }

        struct Found {
            var together: Int
            var introducer: UUID?
        }
        var found: [String: (x: UUID, y: UUID, item: Found)] = [:]
        for edge in edges where edge.together > 0 && !edge.acquainted && !edge.introduced {
            found[pairKey(edge.a, edge.b)] = (x: edge.a, y: edge.b, item: Found(together: edge.together, introducer: nil))
        }

        var groups: [UUID: [UUID]] = [:]
        for person in people {
            guard let introducer = person.introducedBy, introducer != person.id, byID[introducer] != nil else { continue }
            groups[introducer, default: []].append(person.id)
        }
        for introducer in groups.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            let members = (groups[introducer] ?? []).sorted { $0.uuidString < $1.uuidString }
            guard members.count >= 2, members.count <= introducerGroupLimit else { continue }
            for i in members.indices {
                for j in members.indices where j > i {
                    let key = pairKey(members[i], members[j])
                    let edge = edgeByKey[key]
                    if let edge, edge.acquainted || edge.introduced { continue }
                    var entry = found[key] ?? (x: members[i], y: members[j], item: Found(together: edge?.together ?? 0, introducer: nil))
                    entry.item.introducer = introducer
                    found[key] = entry
                }
            }
        }

        // 이름 열쇠는 사람마다 한 번만 센다 — 줄 세우는 동안 견줄 때마다 세면 5,000명에서 수 초다 (D-47).
        var nameKeys: [UUID: (String, String)] = [:]
        func nameKey(_ id: UUID) -> (String, String) {
            if let known = nameKeys[id] { return known }
            let key = (NameSort.key(byID[id]?.name ?? ""), id.uuidString)
            nameKeys[id] = key
            return key
        }
        func precedes(_ l: (String, String), _ r: (String, String)) -> Bool {
            l.0 != r.0 ? l.0 < r.0 : l.1 < r.1
        }

        var out: [Suggestion] = []
        for (key, entry) in found where !declinedKeys.contains(key) {
            let (first, second) = precedes(nameKey(entry.x), nameKey(entry.y)) ? (entry.x, entry.y) : (entry.y, entry.x)
            out.append(Suggestion(a: first, b: second, together: entry.item.together, introducer: entry.item.introducer))
        }
        out.sort { l, r in
            if l.together != r.together { return l.together > r.together }
            if (l.introducer != nil) != (r.introducer != nil) { return l.introducer != nil }
            let la = nameKey(l.a), ra = nameKey(r.a)
            if la != ra { return precedes(la, ra) }
            return precedes(nameKey(l.b), nameKey(r.b))
        }
        return Array(out.prefix(limit))
    }
}
