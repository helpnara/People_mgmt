import XCTest

/// **화면 이동 시험** (이슈 50 · 2026-10-28 사용자 — 아이패드에서 사람 상세의 타임라인 기록이 열리지 않았다).
///
/// 아이폰 · 아이패드 시뮬레이터에서 앱을 띄워 **실제로 눌러** 다음 화면이 뜨는지 본다. 앱 테스트(인메모리 저장소)는
/// 저장 규칙만 보고, 스크린샷은 눌러 볼 수 없어 이 칸이 비어 있었다. 견본 자료(`-seedSampleData` · 메모리 저장소)만 쓴다.
final class NavigationUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"] + arguments
        app.launch()
        return app
    }

    /// 찾은 단추를 누를 수 있을 때까지 조금씩 올린다.
    @MainActor
    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(what) 이(가) 보이지 않는다")
        var tries = 0
        while !element.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        element.tap()
    }

    /// 사람 상세 → 타임라인 기록 → 기록 상세 (아이패드에서 잡힌 것).
    @MainActor
    func testTimelineRecordOpensRecordDetail() {
        let app = launch(["-openPerson", "김하늘", "-detail.layout", "timeline"])
        tapWhenReady(app.buttons["timelineRow"].firstMatch, in: app, "타임라인 기록")
        let stamp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "만든 날")).firstMatch
        XCTAssertTrue(stamp.waitForExistence(timeout: 10), "타임라인 기록을 눌러도 기록 상세가 뜨지 않는다")
    }

    /// 사람 상세 → 소개한 인연 → 그 사람 상세.
    @MainActor
    func testIntroducedPersonOpensPersonDetail() {
        let app = launch(["-openPerson", "김하늘", "-detail.layout", "introduced"])
        tapWhenReady(app.buttons["introducedRow"].firstMatch, in: app, "소개한 인연")
        XCTAssertTrue(app.navigationBars["박서연"].waitForExistence(timeout: 10), "소개한 인연을 눌러도 그 사람 상세가 뜨지 않는다")
    }

    /// 사람 상세 → 맨 위 칸의 소개자 → 소개자 상세.
    @MainActor
    func testIntroducerLinkOpensPersonDetail() {
        let app = launch(["-openPerson", "박서연"])
        tapWhenReady(app.buttons["introducerLink"].firstMatch, in: app, "소개자")
        XCTAssertTrue(app.navigationBars["김하늘"].waitForExistence(timeout: 10), "소개자를 눌러도 소개자 상세가 뜨지 않는다")
    }

    /// 기록 상세 → 함께한 사람 → 그 사람 상세. 기록 상세는 실행 인자로 연다(코드로 쌓는 길).
    @MainActor
    func testRecordParticipantOpensPersonDetail() {
        let app = launch(["-openPerson", "김하늘", "-openRecord"])
        tapWhenReady(app.buttons["recordParticipantRow"].firstMatch, in: app, "함께한 사람")
        let opened = app.navigationBars.matching(NSPredicate(format: "identifier IN %@", ["김하늘", "정유진"])).firstMatch
        XCTAssertTrue(opened.waitForExistence(timeout: 10), "함께한 사람을 눌러도 그 사람 상세가 뜨지 않는다")
    }
}
