import UIKit
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

    /// 실패했을 때 화면에 무엇이 있었는지 — 로그로만 보는 원격 세션의 눈 (이슈 50).
    @MainActor
    private func screen(_ app: XCUIApplication) -> String {
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
        return "보이는 제목 막대: \(bars)\n" + String(app.debugDescription.prefix(5000))
    }

    /// 단추 목록 — 화면 덤프가 앞 5000자에서 잘려 위에 뜬 창(시트 · 말풍선)이 안 보일 때 (CI 136).
    @MainActor
    private func buttons(_ app: XCUIApplication) -> String {
        let list = app.buttons.allElementsBoundByIndex.prefix(80).map { "[\($0.identifier)|\($0.label)|\($0.frame)]" }
        return "말풍선 \(app.popovers.count)개 · 단추: " + list.joined(separator: " ")
    }

    /// 찾은 단추를 누를 수 있을 때까지 조금씩 올린다.
    /// 목록(List)은 화면 아래 줄을 **미리 만들지 않는다** — 첫 화면 밖의 줄은 올려야 비로소 생긴다(CI 151 · 아이폰에서
    /// 사람 상세 맨 위 칸 · 이야기할 것 칸이 길어져 타임라인 · 소개한 인연 줄이 첫 화면 밖으로 밀렸다). 그래서 없으면 먼저 올려 본다.
    @MainActor
    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication, _ what: String) {
        var scrolls = 0
        while !element.waitForExistence(timeout: scrolls == 0 ? 10 : 2) && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(element.exists, "\(what) 이(가) 보이지 않는다 (\(scrolls)번 올림)\n\(screen(app))")
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
        XCTAssertTrue(stamp.waitForExistence(timeout: 10), "타임라인 기록을 눌러도 기록 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// 사람 상세 → 소개한 인연 → 그 사람 상세.
    @MainActor
    func testIntroducedPersonOpensPersonDetail() {
        let app = launch(["-openPerson", "김하늘", "-detail.layout", "introduced"])
        tapWhenReady(app.buttons["introducedRow"].firstMatch, in: app, "소개한 인연")
        XCTAssertTrue(app.navigationBars["박서연"].waitForExistence(timeout: 10), "소개한 인연을 눌러도 그 사람 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// 사람 상세 → 맨 위 칸의 소개자 → 소개자 상세.
    @MainActor
    func testIntroducerLinkOpensPersonDetail() {
        let app = launch(["-openPerson", "박서연"])
        tapWhenReady(app.buttons["introducerLink"].firstMatch, in: app, "소개자")
        XCTAssertTrue(app.navigationBars["김하늘"].waitForExistence(timeout: 10), "소개자를 눌러도 소개자 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// 기록 상세 → 함께한 사람 → 그 사람 상세. 기록 상세는 실행 인자로 연다(코드로 쌓는 길).
    @MainActor
    func testRecordParticipantOpensPersonDetail() {
        let app = launch(["-openPerson", "김하늘", "-openRecord"])
        tapWhenReady(app.buttons["recordParticipantRow"].firstMatch, in: app, "함께한 사람")
        let opened = app.navigationBars.matching(NSPredicate(format: "identifier IN %@", ["김하늘", "정유진"])).firstMatch
        XCTAssertTrue(opened.waitForExistence(timeout: 10), "함께한 사람을 눌러도 그 사람 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// 아이패드 관계도 → 떠 있는 요약 카드 → 자세히 보기 → 그 사람 상세 → 뒤로 → 카드 그대로 (이슈 51).
    /// 아이폰에는 떠 있는 카드가 없다(관계도 아래 사람 칸) — 건너뛴다.
    @MainActor
    func testGraphCardOpensPersonDetailOnIPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "떠 있는 카드는 아이패드에만 있다")
        let app = launch(["-seedCommunitySample", "-openNetwork", "graph", "-graphSelect", "김하늘"])
        tapWhenReady(app.buttons["graphCardDetail"].firstMatch, in: app, "카드의 자세히 보기")
        let detail = app.navigationBars["김하늘"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "카드의 자세히 보기를 눌러도 사람 상세가 뜨지 않는다\n\(screen(app))")
        // 뒤로 단추는 앞 화면 제목(관계도)을 단다 — 글자가 접히면 첫 단추로.
        let titled = detail.buttons["관계도"]
        let back = titled.waitForExistence(timeout: 5) ? titled : detail.buttons.element(boundBy: 0)
        back.tap()
        XCTAssertTrue(app.buttons["graphCardDetail"].waitForExistence(timeout: 10), "뒤로 가면 관계도와 카드가 그대로 있다\n\(screen(app))")
    }

    /// 한 해 돌아보기 → 사람의 흐름(새로 함께한 사람) → 명단 → 그 사람 상세 (이슈 78).
    /// 내 인맥 → 돌아보기에서 값으로 연다(사용자가 가는 길) — 실행 인자로 바로 연 화면에서는 값으로 미는 길이 다르다(이슈 16).
    @MainActor
    func testYearReviewFlowOpensNames() {
        let app = launch(["-openNetwork", "overview"])
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "년 돌아보기")).firstMatch
        tapWhenReady(entry, in: app, "한 해 돌아보기")
        tapWhenReady(app.buttons["yearFresh"], in: app, "새로 함께한 사람 줄")
        let list = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS %@", "새로 함께한 사람")).firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "새로 함께한 사람을 눌러도 명단이 뜨지 않는다\n\(screen(app))")
        let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "처음 ")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10), "명단 줄에 처음 함께한 날이 없다\n\(screen(app))")
        tapWhenReady(app.buttons["peopleRouteRow"].firstMatch, in: app, "명단의 첫 사람")
        XCTAssertTrue(app.buttons["기록 추가"].waitForExistence(timeout: 10), "명단의 사람을 눌러도 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// 한 해 돌아보기 → 달 막대 → 그달 기록이 아래에 → 기록 상세 (이슈 79).
    @MainActor
    func testYearReviewMonthBarShowsRecords() {
        let app = launch(["-openNetwork", "overview"])
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "년 돌아보기")).firstMatch
        tapWhenReady(entry, in: app, "한 해 돌아보기")
        let bar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "monthBar")).firstMatch
        tapWhenReady(bar, in: app, "달 막대")
        // 그달 기록 칸은 막대 아래에 열린다 — 아이폰에서는 화면 아래로 벗어나 목록이 아직 그리지 않았을 수 있다(CI 125).
        // 칸 제목 대신 기록 줄을 찾으며 조금씩 올린다.
        let row = app.buttons["monthRecordRow"].firstMatch
        var tries = 0
        while !row.waitForExistence(timeout: 3) && tries < 4 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(row.exists, "달 막대를 눌러도 그달 기록이 보이지 않는다\n\(screen(app))")
        tapWhenReady(row, in: app, "그달 기록")
        let stamp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "만든 날")).firstMatch
        XCTAssertTrue(stamp.waitForExistence(timeout: 10), "그달 기록을 눌러도 기록 상세가 뜨지 않는다\n\(screen(app))")
    }

    /// **날짜까지 달력은 날을 눌러야 닫힌다** (이슈 83 · 2026-11-05 사용자) — 기록 추가의 날짜 칩 → 제목으로 열두 달 → 제목으로
    /// 열두 해 → 2025년 → 3월 → 15일. 해 · 달을 고르는 동안에는 말풍선이 떠 있고, 날을 누르면 닫히며 칩이 그 날이 된다.
    /// 빌드 57 까지는 해를 바꾸는 순간 닫혔다.
    @MainActor
    func testDayCalendarClosesOnlyOnDay() {
        let app = launch(["-openPerson", "김하늘", "-addRecord"])
        XCTAssertTrue(app.navigationBars["기록 추가"].waitForExistence(timeout: 20), "기록 추가 창이 열리지 않았다\n\(screen(app))")
        let chip = app.buttons["dateChip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "날짜 칩이 보이지 않는다\n\(screen(app))")
        // 칩은 줄 오른쪽 끝에 있다. 찾은 요소가 줄 전체로 잡히면 가운데(빈 곳)를 눌러 달력이 뜨지 않는다(CI 136) —
        // 칩이든 줄이든 칩 위에 떨어지는 오른쪽 자리를 누른다.
        let chipSpot = chip.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        chipSpot.tap()
        // 달력이 떴는지부터 가른다 — 날 칸(`2026년 11월 5일`)이 보이면 떴다. 안 보이면 칩을 한 번 더 누른다(첫 누름이 초점만 옮겼을 때).
        // 칩 자신의 글도 `…일` 로 끝나 칩은 뺀다 — CI 132 · 134 는 칩을 날 칸으로 잘못 보고 다시 누르지 않았다.
        let anyDay = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND identifier != %@", "일", "dateChip")).firstMatch
        if !anyDay.waitForExistence(timeout: 5) {
            chipSpot.tap()
        }
        XCTAssertTrue(anyDay.waitForExistence(timeout: 10),
                      "날짜 칩을 눌러도 달력이 뜨지 않는다 — 칩 \(chip.frame)\n\(buttons(app))\n\(screen(app))")
        let title = app.buttons["calendarTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "달력은 떴는데 제목 단추(calendarTitle)를 못 찾는다\n\(buttons(app))\n\(screen(app))")
        // 단계마다 화면이 바뀐 것을 본 뒤에 누른다 — 바뀌는 동안 누르면 사라지던 칸(달)이 눌려 날로 돌아간다(CI 137).
        let thisYear = Calendar.current.component(.year, from: Date())
        title.tap()
        let monthCell = app.buttons["\(thisYear)년 1월"].firstMatch
        XCTAssertTrue(monthCell.waitForExistence(timeout: 5), "제목을 눌러도 열두 달이 아니다\n\(buttons(app))")
        app.buttons["calendarTitle"].firstMatch.tap()
        XCTAssertTrue(monthCell.waitForNonExistence(timeout: 5), "열두 달 제목을 눌러도 열두 해가 아니다\n\(buttons(app))")
        let year = app.buttons["2025년"].firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: 5), "열두 해에 2025년이 없다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        year.tap()
        let march = app.buttons["2025년 3월"].firstMatch
        XCTAssertTrue(march.waitForExistence(timeout: 5), "해를 고르자 닫혔다 — 열두 달이 보여야 한다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        march.tap()
        let day = app.buttons["2025년 3월 15일"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "달을 고르자 닫혔다 — 그달의 날이 보여야 한다\n\(buttons(app))")
        _ = app.navigationBars["__없는 막대__"].waitForExistence(timeout: 0.6)
        day.tap()
        XCTAssertTrue(app.buttons["calendarTitle"].waitForNonExistence(timeout: 5), "날을 눌러도 닫히지 않았다\n\(buttons(app))")
        XCTAssertTrue(chip.label.contains("2025") && chip.label.contains("15"), "칩이 고른 날이 아니다: \(chip.label)\n\(screen(app))")
    }
}
