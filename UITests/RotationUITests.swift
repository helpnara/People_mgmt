import UIKit
import XCTest

/// **돌려도 편집 창이 그대로인가** (이슈 77 · 2026-11-04 사용자 — 아이폰에서 기록 편집 중 가로로 돌리자 편집 창이 닫혔다).
///
/// 큰 아이폰(Pro Max)은 가로가 넓은 폭이라 빌드 52 까지 뿌리 화면의 뼈대가 스택 → 칸 나누기로 바뀌며 창이 내려갔다.
/// ios.yml 이 이 시험만 **스토어용 Pro Max 시뮬레이터**에서도 돌린다 — 보통 아이폰(좁은 가로)에서는 원래 통과한다.
/// 사람 상세 · 기록 상세가 띄우는 입력 창 셋(기록 추가 · 기록 수정 · 사람 수정)을 연 채 가로 → 세로로 돌린다.
final class RotationUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func screen(_ app: XCUIApplication) -> String {
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
        return "보이는 제목 막대: \(bars)\n" + String(app.debugDescription.prefix(5000))
    }

    /// 창이 열린 것을 본 뒤 가로 · 세로로 돌려 가며 창이 남아 있는지 본다.
    @MainActor
    private func rotate(keeping title: String, _ arguments: [String]) {
        // 앞 시험이 가로에서 멈췄어도 세로에서 시작한다.
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"] + arguments
        app.launch()
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "\(title) 창이 열리지 않았다\n\(screen(app))")
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            // 돌리는 몸짓과 뼈대 바꾸기가 끝날 때까지 — 창이 내려가는 데는 1초가 채 안 걸린다.
            _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 2)
            XCTAssertTrue(bar.exists, "\(orientation == .portrait ? "세로" : "가로")로 돌리자 \(title) 창이 닫혔다\n\(screen(app))")
        }
    }

    /// 사람 상세 → 기록 추가.
    @MainActor
    func testAddRecordSurvivesRotation() {
        rotate(keeping: "기록 추가", ["-openPerson", "김하늘", "-addRecord"])
    }

    /// 기록 상세 → 기록 수정 (사용자가 잡은 것).
    @MainActor
    func testEditRecordSurvivesRotation() {
        rotate(keeping: "기록 수정", ["-openPerson", "김하늘", "-openRecord", "-editRecord"])
    }

    /// 사람 상세 → 사람 수정.
    @MainActor
    func testEditPersonSurvivesRotation() {
        rotate(keeping: "사람 수정", ["-openPerson", "김하늘", "-editPerson"])
    }

    /// **키보드가 올라와도 마지막 칸까지 내려간다** (이슈 80 · 2026-11-04 사용자) — 기록 추가에서 장소 칸에 키보드를 올린 채
    /// 아래로 끌면 태그 칸이 키보드 위로 올라와 머문다. 빌드 55 까지는 끝이 키보드 뒤에 있어 튕겨 돌아왔다.
    /// 시뮬레이터가 화면 키보드를 띄우지 않으면(하드웨어 키보드) 잴 것이 없어 건너뛴다.
    @MainActor
    func testLastFieldReachableAboveKeyboard() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData", "-openPerson", "김하늘", "-addRecord"]
        app.launch()
        XCTAssertTrue(app.navigationBars["기록 추가"].waitForExistence(timeout: 20), "기록 추가 창이 열리지 않았다\n\(screen(app))")
        let place = app.textFields["장소"]
        var tries = 0
        while !(place.exists && place.isHittable) && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        place.tap()
        let keyboard = app.keyboards.firstMatch
        try XCTSkipUnless(keyboard.waitForExistence(timeout: 5), "화면 키보드가 뜨지 않는 시뮬레이터")
        let tag = app.textFields["태그 입력 후 줄바꿈 (쉼표로 여러 개)"]
        tries = 0
        while !(tag.exists && tag.frame.maxY <= keyboard.frame.minY) && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        // 손을 뗀 뒤에도 그 자리에 머무는가 — 튕겨 돌아오면 다시 키보드 뒤로 숨는다.
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 1.5)
        XCTAssertTrue(tag.exists, "태그 칸이 없다\n\(screen(app))")
        XCTAssertLessThanOrEqual(tag.frame.maxY, keyboard.frame.minY + 1,
                                 "키보드가 올라온 채로는 태그 칸까지 내려가지 못한다(키보드 뒤에 숨는다)\n\(screen(app))")
    }
}
