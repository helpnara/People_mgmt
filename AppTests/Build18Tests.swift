import XCTest
@testable import SlowConnection

/// **빌드 18** — 모임 짝짓기 문턱을 설정에서 고른다 (D-39). 기본은 0.3, 저장해 둔 값이 없거나 낯선 값이면 기본으로.
/// 문턱마다 판정이 어떻게 달라지는지는 Core 정답표(`temporal` 의 `thresholdChanges`)가 본다.
final class Build18Tests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GroupMatchSetting.key)
        super.tearDown()
    }

    func testDefaultIsStandardAndStoredChoiceIsRead() {
        UserDefaults.standard.removeObject(forKey: GroupMatchSetting.key)
        XCTAssertEqual(GroupMatchSetting.current, .standard, "고른 적이 없으면 보통")
        XCTAssertEqual(GroupMatchSetting.standard.threshold, 0.3, accuracy: 1e-12)

        UserDefaults.standard.set(GroupMatchSetting.looser.rawValue, forKey: GroupMatchSetting.key)
        XCTAssertEqual(GroupMatchSetting.current, .looser)
        XCTAssertEqual(GroupMatchSetting.current.threshold, 0.1, accuracy: 1e-12)

        UserDefaults.standard.set("unknown", forKey: GroupMatchSetting.key)
        XCTAssertEqual(GroupMatchSetting.current, .standard, "낯선 값이면 보통")
    }
}
