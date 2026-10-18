import XCTest
@testable import Core

/// 관계도 자리 잡기의 **성질**을 본다 (요구사항 5.5 — 소형 그래프로 단위 테스트).
/// 좌표 자체는 정답표로 대조하지 않는다 — 소수 끝자리가 기기 수학 라이브러리마다 다를 수 있다.
final class GraphLayoutTests: XCTestCase {

    /// 나(6) + 두 덩어리(0-1-2 삼각형, 3-4-5 삼각형).
    private let twoClumps: [GraphLayout.Link] = [
        .init(i: 0, j: 1, weight: 1), .init(i: 1, j: 2, weight: 1), .init(i: 0, j: 2, weight: 1),
        .init(i: 3, j: 4, weight: 1), .init(i: 4, j: 5, weight: 1), .init(i: 3, j: 5, weight: 1),
    ]

    private func distance(_ a: GraphLayout.Point, _ b: GraphLayout.Point) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    func testSameInputGivesSameLayout() {
        let first = GraphLayout.layout(nodeCount: 7, center: 6, links: twoClumps)
        let second = GraphLayout.layout(nodeCount: 7, center: 6, links: twoClumps)
        XCTAssertEqual(first, second, "난수가 없다 — 같은 자료면 같은 그림")
    }

    func testPointsStayInsideAndCenterIsFixed() {
        let points = GraphLayout.layout(nodeCount: 7, center: 6, links: twoClumps)
        XCTAssertEqual(points.count, 7)
        XCTAssertEqual(points[6], GraphLayout.Point(x: 0.5, y: 0.5), "나는 가운데")
        for point in points {
            XCTAssertTrue(point.x.isFinite && point.y.isFinite)
            XCTAssertTrue((0...1).contains(point.x) && (0...1).contains(point.y))
        }
    }

    func testConnectedPeopleSitCloserThanStrangers() {
        let p = GraphLayout.layout(nodeCount: 7, center: 6, links: twoClumps)
        let inside = [distance(p[0], p[1]), distance(p[1], p[2]), distance(p[0], p[2]),
                      distance(p[3], p[4]), distance(p[4], p[5]), distance(p[3], p[5])]
        let across = [0, 1, 2].flatMap { i in [3, 4, 5].map { j in distance(p[i], p[j]) } }
        let meanInside = inside.reduce(0, +) / Double(inside.count)
        let meanAcross = across.reduce(0, +) / Double(across.count)
        XCTAssertLessThan(meanInside, meanAcross, "이어진 사람끼리 모인다 — 안 \(meanInside) · 밖 \(meanAcross)")
    }

    func testPeopleDoNotPileOnOnePoint() {
        // 아무 연결 없는 30명 — 밀어내는 힘으로 퍼져야 한다.
        let p = GraphLayout.layout(nodeCount: 31, center: 30, links: [])
        var closest = Double.infinity
        for i in 0..<31 {
            for j in (i + 1)..<31 { closest = min(closest, distance(p[i], p[j])) }
        }
        XCTAssertGreaterThan(closest, 0.01, "가장 가까운 두 사람이 겹치지 않는다")
    }

    func testEmptyAndSingle() {
        XCTAssertTrue(GraphLayout.layout(nodeCount: 0, center: nil, links: []).isEmpty)
        XCTAssertEqual(GraphLayout.layout(nodeCount: 1, center: 0, links: []), [GraphLayout.Point(x: 0.5, y: 0.5)])
    }

    /// 먼 칸을 무게중심 하나로 보는 셈(이슈 15)이 모두와 하나씩 센 값과 크게 다르지 않다.
    /// 파이썬으로 같은 300명을 셌을 때 평균 1.7% 차이 (θ 1.0) — 문턱은 두 배 가까이.
    func testFarCellsApproximateExactRepulsion() {
        let n = 300
        let points = (0..<n).map { i in
            GraphLayout.Point(x: 0.05 + 0.9 * (Double(i) * 0.6180339887498949).truncatingRemainder(dividingBy: 1),
                              y: 0.05 + 0.9 * (Double(i) * 0.41421356237309515).truncatingRemainder(dividingBy: 1))
        }
        let k2 = 0.36 / Double(n)
        let tree = GraphLayout.QuadTree(points)
        var stack: [Int] = []
        var total = 0.0
        for i in 0..<n {
            let approx = tree.repulsion(on: i, positions: points, k2: k2, stack: &stack)
            var ex = 0.0
            var ey = 0.0
            for j in 0..<n where j != i {
                let dx = points[i].x - points[j].x
                let dy = points[i].y - points[j].y
                let d = max((dx * dx + dy * dy).squareRoot(), 1e-4)
                ex += dx / d * k2 / d
                ey += dy / d * k2 / d
            }
            let error = ((approx.x - ex) * (approx.x - ex) + (approx.y - ey) * (approx.y - ey)).squareRoot()
            total += error / (ex * ex + ey * ey).squareRoot()
        }
        XCTAssertLessThan(total / Double(n), 0.03, "평균 상대 차이")
    }

    /// 사람이 많고 먼 사람끼리도 이어져 있으면 빌드 10 까지는 가운데로 뭉쳤다(5,000명 반지름 0.07 · 이슈 15).
    /// 600명 고리 + 건너뛰는 선 (반복 133번) — 파이썬으로 같은 셈을 돌리면 가운데에서 반지름 중앙값 0.30, 가장 가까운 두 사람 0.0105.
    func testManyLinkedPeopleSpreadInsteadOfCollapsing() {
        let m = 600
        var links: [GraphLayout.Link] = (0..<m).map { .init(i: $0, j: ($0 + 1) % m, weight: 1) }
        links += (0..<m).compactMap { i in
            let j = (i * 37 + 11) % m
            return j == i ? nil : .init(i: i, j: j, weight: 1)
        }
        let p = GraphLayout.layout(nodeCount: m + 1, center: m, links: links)
        let radii = p.map { ((($0.x - 0.5) * ($0.x - 0.5)) + (($0.y - 0.5) * ($0.y - 0.5))).squareRoot() }.sorted()
        XCTAssertGreaterThan(radii[radii.count / 2], 0.15, "가운데로 뭉치지 않는다")
        var closest = Double.infinity
        for i in 0..<p.count {
            for j in (i + 1)..<p.count { closest = min(closest, distance(p[i], p[j])) }
        }
        XCTAssertGreaterThan(closest, 0.003, "겹치지 않는다")
    }
}
