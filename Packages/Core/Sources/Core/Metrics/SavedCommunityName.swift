import Foundation

/// **모임 이름 고쳐 저장** (1.1.9 · 이슈 96 · FR-071 · D-79 · 2026-11-06 사용자).
///
/// 사용자가 고친 이름은 그때 모임의 사람 묶음과 함께 저장된다. 다음에 그리는 모임이 저장한 묶음과 **절반 넘게 겹치면**
/// (자카드 — 겹친 사람 ÷ 둘 중 한쪽에라도 있는 사람 > 0.5) 그 이름. 여럿이면 가장 많이 겹치는 것, 같으면 먼저 받은 것
/// (부르는 쪽이 최근에 고친 것부터 넘긴다). 빈 이름은 건너뛴다. 파이썬 정답표(`savedCommunityName`)와 같은 셈이다.
extension CommunityNaming {
    public struct SavedLabel: Sendable {
        public let name: String
        public let members: [String]
        public init(name: String, members: [String]) {
            self.name = name
            self.members = members
        }
    }

    public static func saved(members: [String], labels: [SavedLabel]) -> String? {
        let mine = Set(members)
        guard !mine.isEmpty else { return nil }
        var best: (name: String, score: Double)?
        for label in labels {
            let name = TextNormalization.collapsedSpaces(TextNormalization.normalized(label.name))
            guard !name.isEmpty else { continue }
            let theirs = Set(label.members)
            let union = mine.union(theirs).count
            guard union > 0 else { continue }
            let score = Double(mine.intersection(theirs).count) / Double(union)
            guard score > 0.5 else { continue }
            if best == nil || score > best!.score { best = (name, score) }
        }
        return best?.name
    }
}
