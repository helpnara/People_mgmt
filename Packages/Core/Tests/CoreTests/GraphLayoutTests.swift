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
}
