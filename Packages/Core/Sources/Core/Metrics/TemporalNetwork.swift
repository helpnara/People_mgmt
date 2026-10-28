import Foundation

/// **시점에 따른 관계 변화** (8번째 묶음 · D-32 · docs/community-detection-review.md 5-1 · 9절).
///
/// 같은 사람들이라도 3년 전의 묶음과 지금의 묶음은 다르다. 기록마다 날짜가 있어 지난 시점의 관계도를 되살린다.
/// - **시점 t 의 진한 선**: 창(t 이전 365일) 안의 함께한 기록을 반감기 182.625일(6개월)로 줄여 더한다.
///   소개 · 아는 사이는 날짜가 없으므로 **두 사람이 그 시점에 있으면** 1 씩 더한다.
/// - **그 시점에 있던 사람**: 처음 만난 날과 첫 기록일 중 이른 날이 t 이전. 둘 다 없으면 그리지 않는다.
/// - **모임**: 진한 선이 10개 이상일 때 Louvain(지금의 모임 찾기와 같은 문턱 — 모듈성 0.3 · 3명 이상).
/// - **함께한 기록의 무게**: n명 기록의 각 쌍에 1/(n−1) (빌드 16) — 큰 회식 하나가 모임을 덮지 않게.
/// - **변화**: 앞 시점의 모임과 구성원 겹침으로 짝짓고 중립적인 말로 판정한다 (원칙 5). 겹침은 Jaccard 0.3 이상이거나
///   **작은 쪽의 절반 이상이 큰 쪽에 들어 있으면** 같은 모임의 앞뒤로 본다 (GED 포함도 · 빌드 16) — 작은 모임이 큰 모임에
///   들어간 것을 `최근 기록 없음 + 사람이 늘었습니다` 가 아니라 `두 모임이 이어졌습니다` 로.
///   크기가 비슷하면 `그대로`, 앞에서 최근 기록 없음이 된 모임이 다시 보이면 `다시 모임`.
///
/// 사람 · 기록 · 아는 사이는 **번호**로 받는다 — 부르는 쪽이 이름 순으로 번호를 매긴다(점 차례가 늘 같게).
/// 같은 소속은 넣지 않는다 — 소속에는 날짜가 없어 틀린 과거를 그리게 된다.
/// 파이썬 정답표(`Tools/golden` 의 `temporal`)와 같은 셈이다.
public enum TemporalNetwork {
    public static let windowDays = 365
    public static let halfLifeDays = 182.625
    public static let minimumStrongEdges = 10
    public static let matchThreshold = 0.3
    public static let sizeChange = 0.3
    /// 작은 쪽이 큰 쪽에 이만큼 들어 있으면 짝짓는다 (GED 의 포함도 50% · 조사 보고서 지금 1).
    public static let inclusionThreshold = 0.5

    public struct Member: Sendable, Equatable {
        public let firstMetDay: Int?
        /// 이 사람을 소개한 사람의 번호.
        public let introducedBy: Int?
        public init(firstMetDay: Int?, introducedBy: Int?) {
            self.firstMetDay = firstMetDay
            self.introducedBy = introducedBy
        }
    }

    public struct Meeting: Sendable, Equatable {
        public let day: Int
        public let participants: [Int]
        public init(day: Int, participants: [Int]) {
            self.day = day
            self.participants = participants
        }
    }

    public struct Edge: Sendable, Equatable {
        public let a: Int
        public let b: Int
        public let weight: Double
    }

    public enum Status: String, Sendable {
        /// 진한 선이 모자라다 — `이 시기는 기록이 적습니다`.
        case sparse
        /// 선은 넉넉하지만 뚜렷하게 나뉘지 않는다.
        case unclear
        case shown
    }

    public struct Slice: Sendable {
        public let day: Int
        /// 그 시점에 있던 사람 (번호 오름차순).
        public let present: [Int]
        /// 진한 선이 하나라도 있는 사람.
        public let linked: [Int]
        public let status: Status
        /// (a < b) 차례.
        public let edges: [Edge]
        /// 큰 모임부터. 모임마다 번호 오름차순.
        public let communities: [[Int]]
    }

    public enum ChangeKind: String, Sendable {
        case new, grew, shrank, merged, split, faded
        /// 앞 시점과 같은 모임 · 크기도 비슷하다 — 변화 목록에는 넣지 않고 시점 설명에 수로만 쓴다 (빌드 16).
        case steady
        /// 앞에서 최근 기록 없음이 된 모임이 다시 보인다 (빌드 16 · 조사 보고서 지금 2).
        case returned

        /// 보여 줄 말 — 판단하지 않는다 (`사라졌다` · `끊겼다` 대신 `최근 기록 없음`).
        public var phrase: String {
            switch self {
            case .new: return "새로 생긴 모임"
            case .grew: return "사람이 늘었습니다"
            case .shrank: return "사람이 줄었습니다"
            case .merged: return "두 모임이 이어졌습니다"
            case .split: return "한 모임이 나뉘었습니다"
            case .faded: return "최근 기록 없음"
            case .steady: return "전 해와 같습니다"
            case .returned: return "다시 함께한 기록이 생겼습니다"
            }
        }
    }

    public struct Change: Sendable, Equatable {
        /// 이 변화가 보인 시점 (`slices` 의 자리). 늘 1 이상 — 앞 시점과 견준다.
        public let slice: Int
        public let kind: ChangeKind
        /// 나뉨 · 최근 기록 없음은 앞 시점의 모임, 나머지는 이 시점의 모임.
        public let members: [Int]
    }

    private struct Pair: Hashable, Comparable {
        let a: Int
        let b: Int
        init(_ x: Int, _ y: Int) {
            a = min(x, y)
            b = max(x, y)
        }
        static func < (l: Pair, r: Pair) -> Bool { l.a != r.a ? l.a < r.a : l.b < r.b }
    }

    public static func slices(members: [Member], meetings: [Meeting], ties: [(Int, Int)], sliceDays: [Int]) -> [Slice] {
        let n = members.count
        var firstRecord = [Int?](repeating: nil, count: n)
        for meeting in meetings {
            for x in Set(meeting.participants) where x >= 0 && x < n {
                if firstRecord[x].map({ meeting.day < $0 }) ?? true { firstRecord[x] = meeting.day }
            }
        }
        let known: [Int?] = (0..<n).map { i in
            [members[i].firstMetDay, firstRecord[i]].compactMap { $0 }.min()
        }
        var introduced = Set<Pair>()
        for (i, member) in members.enumerated() {
            if let j = member.introducedBy, j >= 0, j < n, j != i { introduced.insert(Pair(i, j)) }
        }
        var acquainted = Set<Pair>()
        for (a, b) in ties where a != b && a >= 0 && a < n && b >= 0 && b < n {
            acquainted.insert(Pair(a, b))
        }
        let timeless = introduced.union(acquainted).sorted()

        // **빠르게 (D-47).** 기록마다 참여자를 한 번만 정리하고(중복 빼고 · 번호 순 · 범위 안), 날짜 순 색인으로 창 안의
        // 기록만 찾는다 — 시점마다 50,000건을 모두 돌지 않는다. 창 안의 기록은 **원래 차례로** 더한다(무게 합의 마지막 자리까지
        // 예전과 같게 — 모임 찾기가 같은 답을 내도록).
        let cleaned: [[Int]] = meetings.map { Set($0.participants.filter { $0 >= 0 && $0 < n }).sorted() }
        let byDay = meetings.indices.sorted { meetings[$0].day != meetings[$1].day ? meetings[$0].day < meetings[$1].day : $0 < $1 }
        /// `byDay` 에서 날이 `day` 보다 큰 첫 자리.
        func upperBound(_ day: Int) -> Int {
            var low = 0, high = byDay.count
            while low < high {
                let mid = (low + high) / 2
                if meetings[byDay[mid]].day <= day { low = mid + 1 } else { high = mid }
            }
            return low
        }

        /// 시점 하나 — 다른 시점과 기대지 않는다.
        func slice(at t: Int) -> Slice {
            let present = (0..<n).filter { i in known[i].map { $0 <= t } ?? false }
            var isPresent = [Bool](repeating: false, count: n)
            for i in present { isPresent[i] = true }
            var inWindow = Array(byDay[upperBound(t - windowDays)..<upperBound(t)])
            inWindow.sort()
            var weight: [Pair: Double] = [:]
            for index in inWindow {
                let d = meetings[index].day
                let ps = cleaned[index].filter { isPresent[$0] }
                guard ps.count > 1 else { continue }
                let w = pow(0.5, Double(t - d) / halfLifeDays) / Double(ps.count - 1)
                for x in 0..<ps.count {
                    for y in (x + 1)..<ps.count {
                        weight[Pair(ps[x], ps[y]), default: 0] += w
                    }
                }
            }
            for pair in timeless where isPresent[pair.a] && isPresent[pair.b] {
                let add = (introduced.contains(pair) ? 1.0 : 0) + (acquainted.contains(pair) ? 1.0 : 0)
                weight[pair, default: 0] += add
            }
            let pairs = weight.keys.sorted()
            let edges = pairs.map { Edge(a: $0.a, b: $0.b, weight: weight[$0] ?? 0) }
            let linked = Set(pairs.flatMap { [$0.a, $0.b] }).sorted()

            var status = Status.sparse
            var communities: [[Int]] = []
            if edges.count >= minimumStrongEdges {
                var node: [Int: Int] = [:]
                for (k, p) in present.enumerated() { node[p] = k }
                let links = edges.compactMap { edge -> CommunityDetection.Link? in
                    guard let i = node[edge.a], let j = node[edge.b] else { return nil }
                    return CommunityDetection.Link(i: i, j: j, weight: edge.weight)
                }
                let found = CommunityDetection.louvain(nodeCount: present.count, links: links)
                let groups = found.communities
                    .filter { $0.count >= CommunityDetection.minimumGroupSize }
                    .map { $0.map { present[$0] } }
                if found.modularity >= CommunityDetection.minimumModularity && !groups.isEmpty {
                    status = .shown
                    communities = groups
                } else {
                    status = .unclear
                }
            }
            return Slice(day: t, present: present, linked: linked, status: status, edges: edges, communities: communities)
        }

        // 시점마다 따로 센다 — 여러 코어로 나눠 센다 (D-47 · 빌드 24). 시점마다 쓰는 자리가 달라 결과는 차례로 셀 때와 같다.
        var out = [Slice?](repeating: nil, count: sliceDays.count)
        out.withUnsafeMutableBufferPointer { buffer in
            Parallel.chunks(sliceDays.count, minimumChunk: 1) { range in
                for k in range { buffer[k] = slice(at: sliceDays[k]) }
            }
        }
        return out.compactMap { $0 }
    }

    /// 두 모임을 같은 모임의 앞뒤로 볼까 — Jaccard 가 문턱 이상이거나, 작은 쪽의 절반 이상이 큰 쪽에 들어 있다.
    public static func matches(_ x: [Int], _ y: [Int], threshold: Double = matchThreshold) -> Bool {
        let a = Set(x), b = Set(y)
        guard !a.isEmpty, !b.isEmpty else { return false }
        let both = Double(a.intersection(b).count)
        return both / Double(a.union(b).count) >= threshold || both / Double(min(a.count, b.count)) >= inclusionThreshold
    }

    /// `matches` 와 같은 셈 — 모임마다 집합을 한 번만 만들어 둔 쪽.
    private static func matches(_ a: Set<Int>, _ b: Set<Int>, threshold: Double) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        let both = Double(a.intersection(b).count)
        return both / Double(a.union(b).count) >= threshold || both / Double(min(a.count, b.count)) >= inclusionThreshold
    }

    /// **빠르게 (D-47).** 겹치는 사람이 하나도 없는 두 모임은 짝이 될 수 없다(두 문턱 모두 0 보다 크다). 그래서 사람 → 모임
    /// 색인으로 겹치는 모임만 견준다 — 시점마다 모임이 수백 개여도 모든 쌍을 보지 않는다. 판정 · 차례는 모든 쌍을 볼 때와 같다.
    public static func changes(_ slices: [Slice], threshold: Double = matchThreshold) -> [Change] {
        var events: [Change] = []
        /// 앞에서 최근 기록 없음이 된 모임 — 다시 보이면 `다시 모임`.
        var dormant: [[Int]] = []
        var dormantSets: [Set<Int>] = []
        // 문턱이 0 이면 겹침 없는 쌍도 짝이 된다 — 그때만 모든 쌍을 본다.
        let everyPair = threshold <= 0
        for s in slices.indices.dropFirst() {
            let previous = slices[s - 1].communities
            let current = slices[s].communities
            let previousSets = previous.map(Set.init)
            let currentSets = current.map(Set.init)
            var currentOf: [Int: [Int]] = [:]
            for (c, group) in current.enumerated() {
                for person in group { currentOf[person, default: []].append(c) }
            }
            var successors: [[Int]] = []
            var predecessors = [[Int]](repeating: [], count: current.count)
            for (p, group) in previous.enumerated() {
                var candidates = everyPair ? Set(current.indices) : Set<Int>()
                for person in group { candidates.formUnion(currentOf[person] ?? []) }
                let found = candidates.sorted().filter { matches(previousSets[p], currentSets[$0], threshold: threshold) }
                successors.append(found)
                for c in found { predecessors[c].append(p) }
            }
            var dormantOf: [Int: [Int]] = [:]
            for (d, group) in dormant.enumerated() {
                for person in group { dormantOf[person, default: []].append(d) }
            }
            var woke = Set<Int>()
            for (c, group) in current.enumerated() {
                let pred = predecessors[c]
                if pred.isEmpty {
                    // 가장 최근에 쉰 모임부터 견준다.
                    var candidates = everyPair ? Set(dormant.indices) : Set<Int>()
                    for person in group { candidates.formUnion(dormantOf[person] ?? []) }
                    if let back = candidates.sorted(by: >).first(where: { matches(dormantSets[$0], currentSets[c], threshold: threshold) }) {
                        woke.insert(back)
                        events.append(Change(slice: s, kind: .returned, members: group))
                    } else {
                        events.append(Change(slice: s, kind: .new, members: group))
                    }
                } else if pred.count >= 2 {
                    events.append(Change(slice: s, kind: .merged, members: group))
                } else {
                    let p = pred[0]
                    guard successors[p].count < 2 else { continue }
                    let ratio = Double(group.count - previous[p].count) / Double(previous[p].count)
                    if ratio > sizeChange {
                        events.append(Change(slice: s, kind: .grew, members: group))
                    } else if ratio < -sizeChange {
                        events.append(Change(slice: s, kind: .shrank, members: group))
                    } else {
                        events.append(Change(slice: s, kind: .steady, members: group))
                    }
                }
            }
            let kept = dormant.indices.filter { !woke.contains($0) }
            dormant = kept.map { dormant[$0] }
            dormantSets = kept.map { dormantSets[$0] }
            for (p, group) in previous.enumerated() {
                if successors[p].isEmpty {
                    events.append(Change(slice: s, kind: .faded, members: group))
                    dormant.append(group)
                    dormantSets.append(previousSets[p])
                } else if successors[p].count >= 2 {
                    events.append(Change(slice: s, kind: .split, members: group))
                }
            }
        }
        return events
    }
}
