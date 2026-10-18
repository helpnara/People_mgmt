import UIKit
import XCTest
@testable import SlowConnection

/// 견본 명함 그림에서 글자를 읽어 메일 · 전화가 나오는가 (FR-050).
/// 해석 규칙은 Core 의 정답표가 따로 대조한다. 여기는 **Vision 글자 인식 → 해석** 의 길이 서는지만 본다.
/// 한글 이름은 시뮬레이터의 언어 모델에 따라 갈릴 수 있어 로그에만 남긴다.
final class CardReadingTests: XCTestCase {

    @MainActor
    func testSampleCardYieldsEmailAndPhone() async throws {
        let data = try XCTUnwrap(SampleData.renderCard(organization: "청림소프트 주식회사", name: "김하늘", role: "개발팀 팀장",
                                                       phone: "010-1234-5678", email: "haneul@example.com"))
        let summary = await CardReading.summary(data)
        print("읽은 줄: \(summary.lines) · 이름: \(summary.name ?? "없음")")
        XCTAssertTrue(summary.emails.contains("haneul@example.com"), "메일을 못 읽었다 — 읽은 줄: \(summary.lines)")
        XCTAssertFalse(summary.phones.isEmpty, "전화를 못 읽었다 — 읽은 줄: \(summary.lines)")
    }

    @MainActor
    func testNormalizedCardKeepsSmallImagesAndShrinksLargeOnes() async throws {
        let data = try XCTUnwrap(SampleData.renderCard(organization: "A", name: "B", role: "C", phone: "010-0000-0000", email: "a@example.com"))
        let normalized = try XCTUnwrap(await CardImaging.normalizedCard(from: data))
        let image = try XCTUnwrap(UIImage(data: normalized))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), CardImaging.maxLongSide)
        XCTAssertEqual(image.size.width, 1_050, accuracy: 1, "1,600px 보다 작으면 줄이지 않는다")
    }
}
