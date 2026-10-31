import Foundation

/// **관계도 이름표 자리 잡기** (이슈 30) — 이름끼리 · 이름과 점이 겹치지 않는 자리를 찾는다.
///
/// - 점마다 자리 후보 여덟 곳을 차례로 본다: 아래 → 위 → 오른쪽 → 왼쪽 → 오른아래 → 왼아래 → 오른위 → 왼위.
///   이미 놓은 이름표 · 다른 점 · 미리 막아 둔 칸(나 · 모임 이름)과 겹치지 않고 그림 칸 안에 드는 첫 자리에 놓는다.
/// - 놓을 자리가 없으면 그 이름은 **이번 크기에서는 쓰지 않는다**(`nil`). 두 손가락으로 키우면 점 사이가 벌어져 자리가 생긴다.
/// - 차례는 부르는 쪽이 정한다 — 누른 사람 · 강조한 사람을 앞에 둔다. 나머지는 이름 순이다(누가 더 중요한지 줄 세우지 않는다 · ADR-0004).
/// - 칸을 격자로 나눠 가까운 것만 견준다 — 이름표 150개 · 점 수천 개여도 프레임마다 돈다.
///
/// 좌표는 화면 점(pt) 단위. 난수가 없다 — 같은 입력이면 같은 자리.
public enum LabelPlacement {
    /// 축에 나란한 네모 — `x` · `y` 는 왼쪽 위.
    public struct Box: Sendable, Equatable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        /// 가운데와 크기로.
        public init(centerX: Double, centerY: Double, width: Double, height: Double) {
            self.init(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
        }

        public var centerX: Double { x + width / 2 }
        public var centerY: Double { y + height / 2 }

        public func intersects(_ other: Box) -> Bool {
            x < other.x + other.width && other.x < x + width && y < other.y + other.height && other.y < y + height
        }

        func contains(_ other: Box) -> Bool {
            other.x >= x && other.y >= y && other.x + other.width <= x + width && other.y + other.height <= y + height
        }
    }

    /// 이름표 하나 — 점 가운데(`anchorX` · `anchorY`), 점 반지름, 글자 크기.
    public struct Request: Sendable, Equatable {
        public let anchorX: Double
        public let anchorY: Double
        public let radius: Double
        public let width: Double
        public let height: Double

        public init(anchorX: Double, anchorY: Double, radius: Double, width: Double, height: Double) {
            self.anchorX = anchorX
            self.anchorY = anchorY
            self.radius = radius
            self.width = width
            self.height = height
        }
    }

    /// 이름표와 점 사이 · 이름표끼리의 틈.
    public static let gap = 2.0

    /// 요청 차례대로 자리를 잡는다. 결과는 요청과 같은 차례 — 놓은 이름표의 네모, 못 놓았으면 `nil`.
    /// `obstacles` 는 피할 칸(점 · 나 · 모임 이름). 자기 점은 후보가 처음부터 비켜 서므로 함께 넣어도 된다.
    /// `bounds` 가 있으면 그 안에 다 드는 자리만 쓴다.
    public static func place(_ requests: [Request], obstacles: [Box], bounds: Box? = nil) -> [Box?] {
        var grid = Grid()
        for box in obstacles { grid.add(box) }
        var result: [Box?] = []
        result.reserveCapacity(requests.count)
        for request in requests {
            var chosen: Box?
            for candidate in candidates(for: request) {
                if let bounds, !bounds.contains(candidate) { continue }
                if grid.hits(candidate) { continue }
                chosen = candidate
                break
            }
            if let chosen { grid.add(chosen) }
            result.append(chosen)
        }
        return result
    }

    /// 여덟 자리 — 점의 네모(반지름)에서 틈만큼 떨어진다. 모서리 자리는 글자 모서리가 점 네모의 모서리 바깥에.
    /// 그래서 자기 점을 피할 칸에 함께 넣어도 후보가 자기 점에 걸리지 않는다.
    static func candidates(for request: Request) -> [Box] {
        let w = request.width, h = request.height
        let reach = request.radius + gap
        let cx = request.anchorX, cy = request.anchorY
        let diagonal = reach
        let centers: [(Double, Double)] = [
            (cx, cy + reach + h / 2),                                   // 아래
            (cx, cy - reach - h / 2),                                   // 위
            (cx + reach + w / 2, cy),                                   // 오른쪽
            (cx - reach - w / 2, cy),                                   // 왼쪽
            (cx + diagonal + w / 2, cy + diagonal + h / 2),             // 오른아래
            (cx - diagonal - w / 2, cy + diagonal + h / 2),             // 왼아래
            (cx + diagonal + w / 2, cy - diagonal - h / 2),             // 오른위
            (cx - diagonal - w / 2, cy - diagonal - h / 2),             // 왼위
        ]
        return centers.map { Box(centerX: $0.0, centerY: $0.1, width: w, height: h) }
    }

    /// 격자 — 칸 하나에 걸친 네모들을 쥔다. 견줄 때는 겹친 칸들만 본다.
    struct Grid {
        static let cellSize = 32.0
        private var cells: [Cell: [Box]] = [:]

        struct Cell: Hashable {
            let x: Int
            let y: Int
        }

        private func cells(of box: Box) -> [Cell] {
            let x0 = Int((box.x / Self.cellSize).rounded(.down)), x1 = Int(((box.x + box.width) / Self.cellSize).rounded(.down))
            let y0 = Int((box.y / Self.cellSize).rounded(.down)), y1 = Int(((box.y + box.height) / Self.cellSize).rounded(.down))
            var out: [Cell] = []
            for x in x0...max(x0, x1) {
                for y in y0...max(y0, y1) { out.append(Cell(x: x, y: y)) }
            }
            return out
        }

        mutating func add(_ box: Box) {
            guard box.width.isFinite, box.height.isFinite, box.x.isFinite, box.y.isFinite else { return }
            for cell in cells(of: box) { cells[cell, default: []].append(box) }
        }

        func hits(_ box: Box) -> Bool {
            guard box.width.isFinite, box.height.isFinite, box.x.isFinite, box.y.isFinite else { return true }
            // 틈만큼 넓혀 견준다 — 맞닿은 글자도 붙어 보인다.
            let padded = Box(x: box.x - gap / 2, y: box.y - gap / 2, width: box.width + gap, height: box.height + gap)
            for cell in cells(of: padded) {
                for other in cells[cell] ?? [] where padded.intersects(other) { return true }
            }
            return false
        }
    }
}
