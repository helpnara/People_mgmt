import Foundation

/// **관계도 모임 색 고르기** (이슈 75 · 2026-11-03 사용자) — 모임 이름이 같으면 늘 같은 색.
///
/// 앱을 다시 켜도, 시점 막대로 지난 해를 봐도 같은 이름의 모임은 같은 색이 기본이다. 한 화면의 두 모임이 같은 색이 되면
/// 작은 모임이 빈 색으로 옮긴다(`assign` · 이슈 76 — 모임이 많으면 겹친 색이 구분되지 않았다).
/// 이름을 NFC 로 맞춘 UTF-8 글자에 FNV-1a(32비트)를 걸어 색 수로 나눈 나머지. `hashValue` 는 켤 때마다 달라서 쓰지 않는다.
/// 파이썬 정답표(`Tools/golden` 의 `communityColor`)와 같은 셈이다.
public enum CommunityColor {
    public static let count = 8

    public static func index(for name: String, count: Int = count) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt32 = 0x811C9DC5
        for byte in name.precomposedStringWithCanonicalMapping.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return Int(hash % UInt32(count))
    }

    /// 한 화면에 그릴 모임 하나 — 이름 · 사람 수 · 가운데 자리(0 ~ 1).
    public struct Group: Sendable, Equatable {
        public let name: String
        public let size: Int
        public let x: Double
        public let y: Double
        public init(name: String, size: Int, x: Double, y: Double) {
            self.name = name
            self.size = size
            self.x = x
            self.y = y
        }
    }

    /// **화면의 모임들에 색 주기** (이슈 76 · 2026-11-03 사용자) — 이름 색(`index(for:)`)이 기본, 다른 모임이 이미 그 색이면 빈 색으로.
    /// 큰 모임부터(같으면 이름 · 차례) 정한다 — 큰 모임일수록 늘 제 색을 지킨다. 빈 색은 이름 색 다음 번호부터 찾는다.
    /// 색보다 모임이 많으면 같은 색을 다시 쓰되, 그 색을 쓰는 모임들과 **가장 멀리 떨어진** 색을 준다(같으면 이름 색에 가까운 번호).
    /// 결과는 들어온 차례 그대로의 색 번호. 파이썬 정답표(`communityColorAssign`)와 같은 셈이다.
    public static func assign(_ groups: [Group], count: Int = count) -> [Int] {
        guard count > 0 else { return groups.map { _ in 0 } }
        let order = groups.indices.sorted { a, b in
            if groups[a].size != groups[b].size { return groups[a].size > groups[b].size }
            if groups[a].name != groups[b].name { return groups[a].name < groups[b].name }
            return a < b
        }
        var result = Array(repeating: 0, count: groups.count)
        var users: [[Int]] = Array(repeating: [], count: count)
        for g in order {
            let preferred = index(for: groups[g].name, count: count)
            var chosen: Int?
            for step in 0..<count where users[(preferred + step) % count].isEmpty {
                chosen = (preferred + step) % count
                break
            }
            if chosen == nil {
                var best = (color: preferred, distance: -1.0)
                for step in 0..<count {
                    let color = (preferred + step) % count
                    // 식 하나로 쓰면 리눅스 컴파일러가 형식을 제때 못 맞춘다(Core 테스트 47) — 거리는 따로 센다.
                    var nearest = Double.infinity
                    for other in users[color] {
                        nearest = min(nearest, distance(groups[g], groups[other]))
                    }
                    if nearest > best.distance { best = (color, nearest) }
                }
                chosen = best.color
            }
            result[g] = chosen ?? preferred
            users[result[g]].append(g)
        }
        return result
    }

    /// 두 모임 가운데 사이의 거리.
    private static func distance(_ a: Group, _ b: Group) -> Double {
        let dx: Double = a.x - b.x
        let dy: Double = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
