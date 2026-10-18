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

    /// 진한 선인가 — 함께한 기록이나 소개.
    public var isStrong: Bool { together > 0 || introduced }
}

public enum RelationGraph {
    /// 같은 소속이 이보다 많으면 모두를 서로 잇지 않고 이름 순 고리로 잇는다 — 100명 회사가 4,950줄이 되지 않게.
    public static let organizationCliqueLimit = 12

    /// - Parameters:
    ///   - records: 기록마다 참여자들. `people` 에 없는 사람(나 · 지운 사람)은 무시한다.
    public static func edges(people: [GraphPerson], records: [[UUID]], organizationCliqueLimit: Int = organizationCliqueLimit) -> [GraphEdge] {
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

        // 세기는 파이썬으로 같은 셈을 돌려 골랐다 (2026-10-18): 끄는 힘이 세면(1.5) 모두 가운데로 뭉쳐
        // 이어진 사람끼리 모이는 것이 묻힌다. 0.6 · 0.6 이면 두 덩어리가 갈리고 30명이 겹치지 않으며 가장자리에 붙지 않는다.
        let k = (1.0 / Double(n)).squareRoot() * 0.6
        let cell = 2 * k
        let gravity = 0.6 * min(1, (10.0 / Double(n)).squareRoot())
        struct Cell: Hashable { let x: Int; let y: Int }

        for iteration in 0..<iterations {
            let temperature = 0.08 * (1 - Double(iteration) / Double(iterations)) + 0.002
            var dx = [Double](repeating: 0, count: n)
            var dy = [Double](repeating: 0, count: n)

            var grid: [Cell: [Int]] = [:]
            for i in 0..<n {
                grid[Cell(x: Int(positions[i].x / cell), y: Int(positions[i].y / cell)), default: []].append(i)
            }
            for i in 0..<n {
                let home = Cell(x: Int(positions[i].x / cell), y: Int(positions[i].y / cell))
                for ox in -1...1 {
                    for oy in -1...1 {
                        guard let others = grid[Cell(x: home.x + ox, y: home.y + oy)] else { continue }
                        for j in others where j > i {
                            let ddx = positions[i].x - positions[j].x
                            let ddy = positions[i].y - positions[j].y
                            let distance = max((ddx * ddx + ddy * ddy).squareRoot(), 1e-4)
                            guard distance < cell else { continue }
                            let force = k * k / distance
                            // 같은 자리에 겹치면 차례로 비켜선다 — 방향이 0 이 되지 않게.
                            let ux = ddx == 0 && ddy == 0 ? 1.0 : ddx / distance
                            let uy = ddx == 0 && ddy == 0 ? 0.0 : ddy / distance
                            dx[i] += ux * force
                            dy[i] += uy * force
                            dx[j] -= ux * force
                            dy[j] -= uy * force
                        }
                    }
                }
            }
            for link in links where link.i != link.j && link.i < n && link.j < n {
                let ddx = positions[link.i].x - positions[link.j].x
                let ddy = positions[link.i].y - positions[link.j].y
                let distance = max((ddx * ddx + ddy * ddy).squareRoot(), 1e-4)
                let force = distance * distance / k * link.weight
                dx[link.i] -= ddx / distance * force
                dy[link.i] -= ddy / distance * force
                dx[link.j] += ddx / distance * force
                dy[link.j] += ddy / distance * force
            }
            for i in 0..<n {
                dx[i] -= (positions[i].x - 0.5) * gravity
                dy[i] -= (positions[i].y - 0.5) * gravity
                guard i != center else { continue }
                let length = (dx[i] * dx[i] + dy[i] * dy[i]).squareRoot()
                guard length > 0 else { continue }
                let step = min(length, temperature)
                positions[i].x = min(max(positions[i].x + dx[i] / length * step, 0.02), 0.98)
                positions[i].y = min(max(positions[i].y + dy[i] / length * step, 0.02), 0.98)
            }
        }
        return positions
    }
}
