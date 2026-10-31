import XCTest
@testable import Core

/// 관계도 이름표 자리 잡기의 **성질**을 본다 (이슈 30) — 겹치지 않는다 · 막힌 곳은 비운다 · 같은 입력이면 같은 자리.
final class LabelPlacementTests: XCTestCase {
    private typealias Box = LabelPlacement.Box
    private typealias Request = LabelPlacement.Request

    private func dot(_ x: Double, _ y: Double, radius: Double = 5) -> Box {
        Box(centerX: x, centerY: y, width: radius * 2, height: radius * 2)
    }

    private func request(_ x: Double, _ y: Double) -> Request {
        Request(anchorX: x, anchorY: y, radius: 5, width: 40, height: 14)
    }

    func testFreeLabelGoesBelowItsDot() {
        let placed = LabelPlacement.place([request(100, 100)], obstacles: [dot(100, 100)])
        let box = try? XCTUnwrap(placed.first ?? nil)
        XCTAssertNotNil(box)
        XCTAssertEqual(box?.centerX, 100)
        XCTAssertGreaterThan(box?.y ?? 0, 105, "점 아래에 — 점과 겹치지 않게")
    }

    func testCrowdedLabelsNeverOverlapEachOtherOrDots() {
        // 사람 서른 명을 좁은 곳에 몰아 둔다 — 겹치는 이름은 비우고, 놓은 이름끼리는 겹치지 않는다.
        var anchors: [(Double, Double)] = []
        for i in 0..<30 {
            let x: Double = 100 + Double(i % 6) * 18
            let y: Double = 100 + Double(i / 6) * 16
            anchors.append((x, y))
        }
        let dots = anchors.map { dot($0.0, $0.1) }
        let placed = LabelPlacement.place(anchors.map { request($0.0, $0.1) }, obstacles: dots)
        let boxes = placed.compactMap { $0 }
        XCTAssertFalse(boxes.isEmpty)
        XCTAssertLessThan(boxes.count, anchors.count, "모두 놓을 자리는 없다 — 일부는 비운다")
        for (a, first) in boxes.enumerated() {
            for second in boxes[(a + 1)...] { XCTAssertFalse(first.intersects(second), "이름끼리 겹치지 않는다") }
            for d in dots { XCTAssertFalse(first.intersects(d), "이름이 점을 덮지 않는다") }
        }
    }

    func testFarApartLabelsAllFit() {
        let anchors = [(50.0, 50.0), (200.0, 50.0), (50.0, 200.0), (200.0, 200.0)]
        let placed = LabelPlacement.place(anchors.map { request($0.0, $0.1) }, obstacles: anchors.map { dot($0.0, $0.1) })
        XCTAssertEqual(placed.compactMap { $0 }.count, 4)
    }

    func testBlockedBelowMovesToAnotherSide() {
        // 아래를 막아 두면 다른 자리로 — 비우지 않는다.
        let blocker = Box(x: 60, y: 106, width: 80, height: 30)
        let placed = LabelPlacement.place([request(100, 100)], obstacles: [dot(100, 100), blocker])
        let box = placed.first ?? nil
        XCTAssertNotNil(box)
        if let box { XCTAssertFalse(box.intersects(blocker)) }
    }

    func testStaysInsideBounds() {
        let bounds = Box(x: 0, y: 0, width: 300, height: 120)
        // 아래 끝에 붙은 점 — 아래 자리는 칸 밖이라 위로.
        let placed = LabelPlacement.place([request(150, 112)], obstacles: [dot(150, 112)], bounds: bounds)
        if let box = placed.first ?? nil {
            XCTAssertLessThanOrEqual(box.y + box.height, 120)
            XCTAssertLessThan(box.centerY, 112)
        } else {
            XCTFail("위 자리가 비어 있다")
        }
    }

    func testSameInputGivesSamePlacement() {
        // 식을 나눠 쓴다 — 한 줄에 몰면 macOS 컴파일러가 타입을 제때 못 정한다 (CI 실행 53).
        var anchors: [(Double, Double)] = []
        for i in 0..<20 {
            let x: Double = Double((i * 13) % 97) + 50
            let y: Double = Double((i * 29) % 83) + 50
            anchors.append((x, y))
        }
        let requests = anchors.map { request($0.0, $0.1) }
        let dots = anchors.map { dot($0.0, $0.1) }
        XCTAssertEqual(LabelPlacement.place(requests, obstacles: dots), LabelPlacement.place(requests, obstacles: dots))
    }
}
