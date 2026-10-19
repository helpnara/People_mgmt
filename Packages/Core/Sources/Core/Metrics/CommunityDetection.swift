import Foundation

/// **모임(그룹) 찾기** — Louvain + 연결 쪼개기 + 고정 차례 (D-30 · docs/community-detection-review.md).
///
/// - **Louvain**: 모듈성(Q)을 올리는 쪽으로 사람을 이웃 그룹에 옮기고(1단계), 그룹을 한 점으로 묶어(2단계) 되풀이한다.
/// - **고정 차례**: 사람을 번호 순으로 돌고, 이웃 그룹을 이웃 번호 순으로 본다. 이득이 같으면 지금 그룹에 남는다.
///   난수가 없다 — 같은 자료면 늘 같은 그룹이고, 파이썬 정답표(`Tools/golden`)와 글자 하나 다르지 않다.
/// - **연결 쪼개기**: Louvain 은 한 그룹 안에 서로 이어지지 않은 조각을 남길 수 있다. 끝에 그룹마다 안쪽 선으로
///   연결 조각을 찾아 나눈다 (Leiden 이 보장하는 성질을 값싸게).
///
/// 나는 넣지 않는다 — 모두가 나와 이어져 있어 넣으면 한 덩어리가 된다. 사람을 점수화하지 않는다 (ADR-0004):
/// 모듈성은 그룹을 보여 줄지의 문턱으로만 쓰고 화면에 숫자로 내지 않는다.
public enum CommunityDetection {
    /// 모임을 보여 주는 문턱 (D-30) — 모듈성이 이보다 낮으면 뚜렷한 모임이 없다고 보고 묶지 않는다.
    public static let minimumModularity = 0.3
    /// 이보다 작은 묶음은 모임으로 그리지 않는다.
    public static let minimumGroupSize = 3

    public struct Link: Sendable, Equatable {
        public let i: Int
        public let j: Int
        public let weight: Double
        public init(i: Int, j: Int, weight: Double) {
            self.i = i
            self.j = j
            self.weight = weight
        }
    }

    public struct Result: Sendable, Equatable {
        /// 그룹마다 사람 번호(오름차순). 큰 그룹부터, 같으면 가장 작은 번호 순. 혼자인 사람도 한 그룹이다.
        public let communities: [[Int]]
        /// 원래 그래프에서의 모듈성 Q (해상도 γ 반영).
        public let modularity: Double
    }

    public static func louvain(nodeCount n: Int, links: [Link], resolution: Double = 1.0,
                               epsilon: Double = 1e-7, maxLevels: Int = 10, maxPasses: Int = 50) -> Result {
        guard n > 0 else { return Result(communities: [], modularity: 0) }
        let base = Graph(nodeCount: n, links: links)
        guard base.totalWeight > 0 else {
            return Result(communities: (0..<n).map { [$0] }, modularity: 0)
        }

        var membership = Array(0..<n)          // 원래 사람 → 지금 단계의 점
        var graph = base
        for _ in 0..<maxLevels {
            let (community, moved) = localMoving(graph, resolution: resolution, epsilon: epsilon, maxPasses: maxPasses)
            guard moved else { break }
            let (renumbered, count) = renumber(community)
            membership = membership.map { renumbered[$0] }
            graph = aggregate(graph, community: renumbered, count: count)
        }

        var groups: [[Int]] = Array(repeating: [], count: (membership.max() ?? -1) + 1)
        for (person, group) in membership.enumerated() { groups[group].append(person) }
        let split = splitConnected(groups.filter { !$0.isEmpty }, nodeCount: n, links: links)
        return Result(communities: split, modularity: modularity(split, nodeCount: n, links: links, resolution: resolution))
    }

    /// 그룹마다 안쪽 선(무게 > 0)으로 연결 조각을 찾아 나눈다. 결과는 큰 그룹부터, 같으면 가장 작은 번호 순.
    public static func splitConnected(_ communities: [[Int]], nodeCount n: Int, links: [Link]) -> [[Int]] {
        var neighbors = Array(repeating: [Int](), count: n)
        for link in links where link.weight > 0 && link.i != link.j && link.i < n && link.j < n {
            neighbors[link.i].append(link.j)
            neighbors[link.j].append(link.i)
        }
        var result: [[Int]] = []
        for community in communities {
            let members = Set(community)
            var seen = Set<Int>()
            for start in community.sorted() where !seen.contains(start) {
                var component: [Int] = []
                var queue = [start]
                seen.insert(start)
                var head = 0
                while head < queue.count {
                    let node = queue[head]
                    head += 1
                    component.append(node)
                    for next in neighbors[node].sorted() where members.contains(next) && !seen.contains(next) {
                        seen.insert(next)
                        queue.append(next)
                    }
                }
                result.append(component.sorted())
            }
        }
        return result.sorted { $0.count != $1.count ? $0.count > $1.count : ($0.first ?? 0) < ($1.first ?? 0) }
    }

    /// Q = Σ_c [ 안쪽 무게_c / m − γ (차수합_c / 2m)² ].
    public static func modularity(_ communities: [[Int]], nodeCount n: Int, links: [Link], resolution: Double = 1.0) -> Double {
        var group = Array(repeating: -1, count: n)
        for (index, community) in communities.enumerated() {
            for node in community where node < n { group[node] = index }
        }
        var m = 0.0
        var inside = Array(repeating: 0.0, count: communities.count)
        var degree = Array(repeating: 0.0, count: communities.count)
        for link in links where link.i < n && link.j < n && link.weight > 0 {
            m += link.weight
            let gi = group[link.i], gj = group[link.j]
            if gi >= 0 { degree[gi] += link.weight }
            if gj >= 0 { degree[gj] += link.weight }
            if gi == gj && gi >= 0 { inside[gi] += link.weight }
        }
        guard m > 0 else { return 0 }
        var q = 0.0
        for c in communities.indices {
            let share = degree[c] / (2 * m)
            q += inside[c] / m - resolution * share * share
        }
        return q
    }

    // MARK: - 안쪽

    /// 무게 그래프. 이웃은 번호 순으로 정렬해 둔다 — 도는 차례가 늘 같게.
    struct Graph {
        var neighbors: [[(node: Int, weight: Double)]]
        /// 점 안쪽의 무게(묶인 그룹 안의 선들, 한 번씩).
        var selfLoop: [Double]
        var degree: [Double]
        var totalWeight: Double   // m

        init(neighbors: [[(node: Int, weight: Double)]], selfLoop: [Double]) {
            self.neighbors = neighbors
            self.selfLoop = selfLoop
            var degree = [Double](repeating: 0, count: selfLoop.count)
            var total = 0.0
            for i in selfLoop.indices {
                var k = 2 * selfLoop[i]
                for edge in neighbors[i] { k += edge.weight }
                degree[i] = k
                total += selfLoop[i]
                for edge in neighbors[i] where edge.node > i { total += edge.weight }
            }
            self.degree = degree
            self.totalWeight = total
        }

        init(nodeCount n: Int, links: [Link]) {
            var merged = Array(repeating: [Int: Double](), count: n)
            var loops = [Double](repeating: 0, count: n)
            for link in links where link.weight > 0 && link.i < n && link.j < n {
                if link.i == link.j {
                    loops[link.i] += link.weight
                } else {
                    merged[link.i][link.j, default: 0] += link.weight
                    merged[link.j][link.i, default: 0] += link.weight
                }
            }
            self.init(neighbors: merged.map { $0.sorted { $0.key < $1.key }.map { (node: $0.key, weight: $0.value) } }, selfLoop: loops)
        }
    }

    static func localMoving(_ graph: Graph, resolution: Double, epsilon: Double, maxPasses: Int) -> (community: [Int], moved: Bool) {
        let n = graph.selfLoop.count
        let twoM = 2 * graph.totalWeight
        var community = Array(0..<n)
        var total = graph.degree
        var movedAny = false
        // **빠르게 (D-47).** 사람마다 사전을 새로 만들지 않고 배열 둘을 돌려 쓴다 — 그룹 번호는 늘 0..<n 이다.
        // 더하는 차례 · 견주는 차례는 사전을 쓸 때와 같다(이웃 번호 순, 처음 만난 그룹 차례).
        var weightTo = [Double](repeating: 0, count: n)
        var touched = [Bool](repeating: false, count: n)
        var order: [Int] = []
        for _ in 0..<maxPasses {
            var movedThisPass = false
            for i in 0..<n {
                let k = graph.degree[i]
                let current = community[i]
                // 이웃 그룹마다 이어진 무게 — 처음 만난 차례(이웃 번호 순)로.
                order.removeAll(keepingCapacity: true)
                for edge in graph.neighbors[i] {
                    let c = community[edge.node]
                    if !touched[c] {
                        touched[c] = true
                        order.append(c)
                    }
                    weightTo[c] += edge.weight
                }
                total[current] -= k
                var best = current
                var bestGain = weightTo[current] - resolution * total[current] * k / twoM
                for c in order where c != current {
                    let gain = weightTo[c] - resolution * total[c] * k / twoM
                    if gain > bestGain + epsilon {
                        best = c
                        bestGain = gain
                    }
                }
                for c in order {
                    weightTo[c] = 0
                    touched[c] = false
                }
                total[best] += k
                if best != current {
                    community[i] = best
                    movedThisPass = true
                    movedAny = true
                }
            }
            if !movedThisPass { break }
        }
        return (community, movedAny)
    }

    /// 그룹 번호를 0 부터 처음 나온 차례(점 번호 순)로 다시 매긴다.
    static func renumber(_ community: [Int]) -> (renumbered: [Int], count: Int) {
        var map: [Int: Int] = [:]
        var result: [Int] = []
        result.reserveCapacity(community.count)
        for c in community {
            if map[c] == nil { map[c] = map.count }
            result.append(map[c] ?? 0)
        }
        return (result, map.count)
    }

    static func aggregate(_ graph: Graph, community: [Int], count: Int) -> Graph {
        var loops = [Double](repeating: 0, count: count)
        var merged = Array(repeating: [Int: Double](), count: count)
        for i in graph.selfLoop.indices {
            loops[community[i]] += graph.selfLoop[i]
            for edge in graph.neighbors[i] where edge.node > i {
                let a = community[i], b = community[edge.node]
                if a == b {
                    loops[a] += edge.weight
                } else {
                    merged[a][b, default: 0] += edge.weight
                    merged[b][a, default: 0] += edge.weight
                }
            }
        }
        return Graph(neighbors: merged.map { $0.sorted { $0.key < $1.key }.map { (node: $0.key, weight: $0.value) } }, selfLoop: loops)
    }
}

/// 모임 이름 제안 — 그룹 안에서 가장 많은 **소속 → 태그 → 알게 된 경로** 순으로, 두 사람 이상이 같은 값일 때만.
/// 없으면 nil (화면은 `묶음 1` 처럼 번호로). 이름은 제안이다 — 고쳐 저장하기는 나중 (D-30).
public enum CommunityNaming {
    public struct Member: Sendable {
        public let organization: String?
        public let tags: [String]
        public let metThrough: String?
        public init(organization: String?, tags: [String], metThrough: String?) {
            self.organization = organization
            self.tags = tags
            self.metThrough = metThrough
        }
    }

    public static func suggest(_ members: [Member]) -> String? {
        if let name = top(members.map { [$0.organization ?? ""] }) { return name }
        if let name = top(members.map(\.tags)) { return "#" + name }
        if let name = top(members.map { [$0.metThrough ?? ""] }) { return name }
        return nil
    }

    /// 두 사람 이상이 같은 값 중 가장 많은 것. 같으면 이름 열쇠 순. 한 사람이 같은 값을 두 번 내도 한 번.
    static func top(_ values: [[String]]) -> String? {
        var counts: [String: Int] = [:]
        var labels: [String: String] = [:]
        for personValues in values {
            var seen = Set<String>()
            for raw in personValues {
                let value = TextNormalization.normalized(raw)
                guard !value.isEmpty else { continue }
                let key = NameSort.key(value)
                guard seen.insert(key).inserted else { continue }
                counts[key, default: 0] += 1
                if labels[key] == nil { labels[key] = value }
            }
        }
        let best = counts.filter { $0.value >= 2 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first
        return best.flatMap { labels[$0.key] }
    }
}
