import Foundation

/// **관계도 이름표를 놓는 차례** (이슈 73 · 2026-11-03 사용자) — 이름이 다 들어가지 않을 때 어떤 이름부터 자리를 주나.
///
/// - 누른 사람이 맨 먼저.
/// - 그다음 **모임마다 한 명씩 돌아가며** — 어느 모임이든 대표 이름이 보이게(빽빽한 모임 하나가 자리를 다 쓰지 않게).
///   모임 안에서는 **나와의 기록이 많은 사람부터**, 같으면 이름 열쇠 순, 그다음 자리 번호 순.
/// - 모임 차례는 그 모임 첫 사람의 기록 수가 많은 모임부터, 같으면 모임 번호 순. 모임이 없는 사람은 한 묶음으로 돌림의 끝에.
///
/// 기록 수는 **이름을 놓는 차례에만** 쓴다 — 화면에 점수 · 순위로 드러내지 않는다(ADR-0004). 자리 찾기는 `LabelPlacement`.
/// 파이썬 정답표(`Tools/golden` 의 `labelPriority`)와 같은 셈이다.
public enum LabelPriority {
    public struct Item: Sendable, Equatable {
        /// 관계도의 사람 자리.
        public let index: Int
        /// 지금 그리는 모임 번호. 모임이 없으면 nil.
        public let community: Int?
        /// 나와의 기록 수(오늘까지).
        public let records: Int
        /// 이름 열쇠(`NameSort.key`).
        public let nameKey: String

        public init(index: Int, community: Int?, records: Int, nameKey: String) {
            self.index = index
            self.community = community
            self.records = records
            self.nameKey = nameKey
        }
    }

    /// 놓는 차례대로의 자리 번호.
    public static func order(_ items: [Item], first: Int? = nil) -> [Int] {
        func before(_ a: Item, _ b: Item) -> Bool {
            if a.records != b.records { return a.records > b.records }
            if a.nameKey != b.nameKey { return a.nameKey < b.nameKey }
            return a.index < b.index
        }
        let rest = items.filter { $0.index != first }
        var buckets: [Int: [Item]] = [:]
        var loners: [Item] = []
        for item in rest {
            if let community = item.community { buckets[community, default: []].append(item) } else { loners.append(item) }
        }
        var queues = buckets
            .map { (id: $0.key, members: $0.value.sorted(by: before)) }
            .sorted { lhs, rhs in
                let l = lhs.members[0].records, r = rhs.members[0].records
                return l != r ? l > r : lhs.id < rhs.id
            }
            .map(\.members)
        if !loners.isEmpty { queues.append(loners.sorted(by: before)) }

        var out: [Int] = []
        out.reserveCapacity(items.count)
        if let first, items.contains(where: { $0.index == first }) { out.append(first) }
        var round = 0
        while out.count < items.count {
            var added = false
            for queue in queues where round < queue.count {
                out.append(queue[round].index)
                added = true
            }
            if !added { break }
            round += 1
        }
        return out
    }
}
