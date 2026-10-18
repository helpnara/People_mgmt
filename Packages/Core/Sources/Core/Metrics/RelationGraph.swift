import Foundation

/// 관계도에 오르는 사람 하나 (FR-047 · 048). 나는 넣지 않는다 — 나는 그림의 가운데에 따로 선다.
public struct GraphPerson: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let organization: String?
    public let introducedBy: UUID?

    public init(id: UUID, name: String, organization: String?, introducedBy: UUID?) {
        self.id = id
        self.name = name
        self.organization = organization
        self.introducedBy = introducedBy
    }
}

/// 두 사람 사이의 선. 무엇으로 이어졌는지 셋을 따로 든다 (2026-10-18 사용자 결정):
/// 함께한 기록 · 소개는 진한 선, 같은 소속은 옅은 선.
public struct GraphEdge: Sendable, Equatable {
    /// `a.uuidString < b.uuidString`.
    public let a: UUID
    public let b: UUID
    /// 둘이 함께 참여한 기록 수.
    public var together: Int
    /// 한쪽이 다른 쪽을 소개했다.
    public var introduced: Bool
    /// 같은 소속(대소문자 · 공백 무시).
    public var sameOrganization: Bool
    /// 서로 아는 사이로 이었다 (D-30).
    public var acquainted: Bool = false

    /// 진한 선인가 — 함께한 기록 · 소개 · 아는 사이.
    public var isStrong: Bool { together > 0 || introduced || acquainted }
}

public enum RelationGraph {
    /// 같은 소속이 이보다 많으면 모두를 서로 잇지 않고 이름 순 고리로 잇는다 — 100명 회사가 4,950줄이 되지 않게.
    public static let organizationCliqueLimit = 12

    /// - Parameters:
    ///   - records: 기록마다 참여자들. `people` 에 없는 사람(나 · 지운 사람)은 무시한다.
    ///   - ties: 아는 사이 연결 (D-30). 방향이 없다.
    public static func edges(people: [GraphPerson], records: [[UUID]], ties: [(UUID, UUID)] = [],
                             organizationCliqueLimit: Int = organizationCliqueLimit) -> [GraphEdge] {
        let known = Set(people.map(\.id))
        var edges: [String: GraphEdge] = [:]

        func touch(_ x: UUID, _ y: UUID, _ change: (inout GraphEdge) -> Void) {
            guard x != y, known.contains(x), known.contains(y) else { return }
            let (a, b) = x.uuidString < y.uuidString ? (x, y) : (y, x)
            let key = a.uuidString + b.uuidString
            var edge = edges[key] ?? GraphEdge(a: a, b: b, together: 0, introduced: false, sameOrganization: false)
            change(&edge)
            edges[key] = edge
        }

        for participants in records {
            var seen = Set<UUID>()
            let unique = participants.filter { known.contains($0) && seen.insert($0).inserted }
            for i in unique.indices {
                for j in unique.indices where j > i {
                    touch(unique[i], unique[j]) { $0.together += 1 }
                }
            }
        }

        for person in people {
            if let introducer = person.introducedBy {
                touch(person.id, introducer) { $0.introduced = true }
            }
        }

        for (x, y) in ties {
            touch(x, y) { $0.acquainted = true }
        }

        var groups: [String: [GraphPerson]] = [:]
        for person in people {
            let key = NameSort.key(person.organization ?? "")
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(person)
        }
        for key in groups.keys.sorted() {
            let members = (groups[key] ?? []).sorted { a, b in
                let ka = NameSort.key(a.name), kb = NameSort.key(b.name)
                return ka != kb ? ka < kb : a.id.uuidString < b.id.uuidString
            }
            guard members.count >= 2 else { continue }
            if members.count <= organizationCliqueLimit {
                for i in members.indices {
                    for j in members.indices where j > i {
                        touch(members[i].id, members[j].id) { $0.sameOrganization = true }
                    }
                }
            } else {
                for i in members.indices {
                    touch(members[i].id, members[(i + 1) % members.count].id) { $0.sameOrganization = true }
                }
            }
        }

        return edges.values.sorted { $0.a.uuidString != $1.a.uuidString ? $0.a.uuidString < $1.a.uuidString : $0.b.uuidString < $1.b.uuidString }
    }
}

/// 관계도의 자리 잡기 — **나를 가운데 두고** 이어진 사람끼리 가까이 모이게 (2026-10-18 사용자 결정).
///
/// 힘 배치(Fruchterman–Reingold)를 정해진 횟수만 돈다. 처음 자리는 해바라기 꼴(황금각)이라 **난수가 없다** —
/// 같은 자료면 늘 같은 그림이다. 밀어내는 힘은 격자로 이웃 칸만 봐서 5,000명에서도 돈다.
/// **거리 · 크기로 사람을 줄 세우지 않는다** (ADR-0004) — 거리는 연결에서만 나오고, 나와의 거리는 뜻이 없다.
public enum GraphLayout {
    public struct Point: Sendable, Equatable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Link: Sendable, Equatable {
        public let i: Int
        public let j: Int
        /// 끄는 힘의 세기. 진한 선 1 이상, 옅은 선은 작게.
        public let weight: Double
        public init(i: Int, j: Int, weight: Double) {
            self.i = i
            self.j = j
            self.weight = weight
        }
    }

    /// 0~1 정사각형 안의 자리. `center` 는 가운데(0.5, 0.5)에 고정된다.
    ///
    /// **미는 힘은 모든 사람 사이에, 먼 무리는 무게중심 하나로** (이슈 15 · 2026-10-18 사용자 선택 ①).
    /// 빌드 10 까지는 미는 힘을 이웃 칸(2k) 안에서만 셌다. 5,000명이면 먼 사람끼리 잇는 선이 모두를 끌어당기는데
    /// 밀어낼 힘이 없어 가운데로 뭉쳤고(반지름 0.07), 이웃 비교가 반복마다 220만 쌍으로 불어 자리 잡기가 92초 걸렸다.
    /// 이제 사분 나무(Barnes–Hut)로 **멀리 있는 칸은 칸 무게중심 하나로** 밀어낸다 — 한 사람당 100곳 안팎만 본다.
    /// 세기는 파이썬으로 같은 셈을 돌려 골랐다: 미는 힘의 합은 사람 수와 상관없이 같으므로 당기는 힘(gravity)은 1.5 로 고정,
    /// 끄는 힘은 사람이 30명을 넘으면 (30/n)^0.75 로 줄인다 — 5,000명이 고르게 퍼지고(반지름 90% 0.39) 작은 그림은 그대로다.
    public static func layout(nodeCount n: Int, center: Int?, links: [Link], iterations: Int = 160) -> [Point] {
        guard n > 0 else { return [] }
        let goldenAngle = 2.399963229728653
        var positions = (0..<n).map { i -> Point in
            let r = 0.45 * ((Double(i) + 0.5) / Double(n)).squareRoot()
            let angle = Double(i) * goldenAngle
            return Point(x: 0.5 + r * cos(angle), y: 0.5 + r * sin(angle))
        }
        if let center { positions[center] = Point(x: 0.5, y: 0.5) }
        guard n > 1 else { return positions }

        let k = (1.0 / Double(n)).squareRoot() * 0.6
        let k2 = k * k
        let gravity = 1.5
        let attraction = pow(min(1, 30.0 / Double(n)), 0.75)
        var stack: [Int] = []
        stack.reserveCapacity(64)

        for iteration in 0..<iterations {
            let temperature = 0.08 * (1 - Double(iteration) / Double(iterations)) + 0.002
            var dx = [Double](repeating: 0, count: n)
            var dy = [Double](repeating: 0, count: n)

            let tree = QuadTree(positions)
            for i in 0..<n {
                let force = tree.repulsion(on: i, positions: positions, k2: k2, stack: &stack)
                dx[i] += force.x
                dy[i] += force.y
            }
            for link in links where link.i != link.j && link.i < n && link.j < n {
                let ddx = positions[link.i].x - positions[link.j].x
                let ddy = positions[link.i].y - positions[link.j].y
                let distance = max((ddx * ddx + ddy * ddy).squareRoot(), 1e-4)
                let force = distance * distance / k * link.weight * attraction
                dx[link.i] -= ddx / distance * force
                dy[link.i] -= ddy / distance * force
                dx[link.j] += ddx / distance * force
                dy[link.j] += ddy / distance * force
            }
            var next = positions
            for i in 0..<n {
                dx[i] -= (positions[i].x - 0.5) * gravity
                dy[i] -= (positions[i].y - 0.5) * gravity
                guard i != center else { continue }
                let length = (dx[i] * dx[i] + dy[i] * dy[i]).squareRoot()
                guard length > 0 else { continue }
                let step = min(length, temperature)
                next[i].x = min(max(positions[i].x + dx[i] / length * step, 0.02), 0.98)
                next[i].y = min(max(positions[i].y + dy[i] / length * step, 0.02), 0.98)
            }
            positions = next
        }
        return positions
    }

    /// 사분 나무 — 0~1 정사각형을 넷씩 나눈다. 칸마다 사람 수(무게)와 무게중심을 쥔다.
    struct QuadTree {
        /// 칸을 열지 말지 — 칸 크기 / 거리가 이보다 작으면 무게중심 하나로 본다.
        static let theta = 0.9
        /// 같은 자리에 겹친 사람이 끝없이 나뉘지 않게.
        static let maxDepth = 16

        private var start: [Int] = []
        private var end: [Int] = []
        private var originX: [Double] = []
        private var originY: [Double] = []
        private var size: [Double] = []
        private var mass: [Double] = []
        private var centerX: [Double] = []
        private var centerY: [Double] = []
        /// 아이 칸들 — `childStart[t] ..< childStart[t] + childCount[t]` 가 `children` 안의 자리.
        private var childStart: [Int] = []
        private var childCount: [Int] = []
        private var children: [Int] = []
        /// 칸이 덮는 사람들 — `order[start ..< end]`.
        private var order: [Int]

        init(_ positions: [Point]) {
            order = Array(positions.indices)
            _ = makeNode(start: 0, end: positions.count, originX: 0, originY: 0, size: 1, depth: 0, positions: positions)
        }

        private mutating func makeNode(start s: Int, end e: Int, originX x0: Double, originY y0: Double,
                                       size side: Double, depth: Int, positions: [Point]) -> Int {
            let t = start.count
            var sumX = 0.0
            var sumY = 0.0
            for a in s..<e {
                sumX += positions[order[a]].x
                sumY += positions[order[a]].y
            }
            let count = Double(e - s)
            start.append(s)
            end.append(e)
            originX.append(x0)
            originY.append(y0)
            size.append(side)
            mass.append(count)
            centerX.append(sumX / count)
            centerY.append(sumY / count)
            childStart.append(0)
            childCount.append(0)
            guard e - s > 1, depth < Self.maxDepth else { return t }

            // 넷으로 나눠 차례대로 다시 놓는다 (왼아래 · 오른아래 · 왼위 · 오른위).
            let half = side / 2
            var buckets: [[Int]] = [[], [], [], []]
            for a in s..<e {
                let p = positions[order[a]]
                let q = (p.x >= x0 + half ? 1 : 0) + (p.y >= y0 + half ? 2 : 0)
                buckets[q].append(order[a])
            }
            var made: [Int] = []
            var cursor = s
            for q in 0..<4 where !buckets[q].isEmpty {
                let bucket = buckets[q]
                for (offset, index) in bucket.enumerated() { order[cursor + offset] = index }
                let child = makeNode(start: cursor, end: cursor + bucket.count,
                                     originX: x0 + (q & 1 == 1 ? half : 0), originY: y0 + (q & 2 == 2 ? half : 0),
                                     size: half, depth: depth + 1, positions: positions)
                made.append(child)
                cursor += bucket.count
            }
            childStart[t] = children.count
            childCount[t] = made.count
            children.append(contentsOf: made)
            return t
        }

        /// 사람 `i` 가 받는 미는 힘. 잎 칸은 한 사람씩, 먼 칸은 무게중심 하나로.
        /// `stack` 은 부르는 쪽이 하나를 돌려 쓴다 — 사람마다 새로 만들면 5,000명 × 160번이다.
        func repulsion(on i: Int, positions: [Point], k2: Double, stack: inout [Int]) -> (x: Double, y: Double) {
            let px = positions[i].x
            let py = positions[i].y
            var fx = 0.0
            var fy = 0.0
            stack.removeAll(keepingCapacity: true)
            stack.append(0)
            while let t = stack.popLast() {
                if childCount[t] == 0 {
                    for a in start[t]..<end[t] {
                        let j = order[a]
                        guard j != i else { continue }
                        let ddx = px - positions[j].x
                        let ddy = py - positions[j].y
                        let distance = (ddx * ddx + ddy * ddy).squareRoot()
                        if distance < 1e-12 {
                            // 같은 자리에 겹치면 번호 차례로 서로 반대쪽으로 비켜선다.
                            fx += (i < j ? 1.0 : -1.0) * k2 / 1e-4
                            continue
                        }
                        let force = k2 / max(distance, 1e-4)
                        fx += ddx / distance * force
                        fy += ddy / distance * force
                    }
                    continue
                }
                let inside = px >= originX[t] && px < originX[t] + size[t] && py >= originY[t] && py < originY[t] + size[t]
                let ddx = px - centerX[t]
                let ddy = py - centerY[t]
                let distance = (ddx * ddx + ddy * ddy).squareRoot()
                if !inside && distance > 0 && size[t] / distance < Self.theta {
                    let force = mass[t] * k2 / max(distance, 1e-4)
                    fx += ddx / distance * force
                    fy += ddy / distance * force
                } else {
                    for c in childStart[t]..<(childStart[t] + childCount[t]) { stack.append(children[c]) }
                }
            }
            return (fx, fy)
        }
    }
}
