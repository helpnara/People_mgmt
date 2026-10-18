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
        // XCTUnwrap 의 인자는 비동기 호출을 받지 못한다 — 먼저 받고 감싼다.
        let result = await CardImaging.normalizedCard(from: data)
        let normalized = try XCTUnwrap(result)
        let image = try XCTUnwrap(UIImage(data: normalized))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), CardImaging.maxLongSide)
        XCTAssertEqual(image.size.width, 1_050, accuracy: 1, "1,600px 보다 작으면 줄이지 않는다")
    }

    /// **사진첩 경로 (이슈 10).** 빌드 4 실기기에서 사진첩 명함을 고르면 앱이 죽었다. 그 길(`straightenedCard`)을
    /// CI 가 한 번도 지나지 않았다 — 견본 명함은 작고 반듯해서 테두리 찾기 · 펴기를 건너뛴다.
    /// 휴대폰 사진 크기(2,400만 화소)에 명함을 비스듬히 놓고 같은 길로 보낸다.
    @MainActor
    func testLargePhotoOfTiltedCardIsStraightenedAndRead() async throws {
        let card = try XCTUnwrap(SampleData.renderCard(organization: "청림소프트 주식회사", name: "김하늘", role: "개발팀 팀장",
                                                       phone: "010-1234-5678", email: "haneul@example.com"))
        let photo = try XCTUnwrap(Self.photo(of: card, size: CGSize(width: 6_000, height: 4_000), degrees: 8))
        print("사진 \(photo.count / 1_024)KB")

        let started = Date()
        let result = await CardImaging.straightenedCard(from: photo)
        let straightened = try XCTUnwrap(result, "사진첩 사진을 펴지 못했다")
        let image = try XCTUnwrap(UIImage(data: straightened))
        print("편 명함 \(Int(image.size.width))×\(Int(image.size.height)) · \(straightened.count / 1_024)KB · \(Int(Date().timeIntervalSince(started) * 1_000))ms")
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), CardImaging.maxLongSide + 1)

        let summary = await CardReading.summary(straightened)
        print("읽은 줄: \(summary.lines)")
        XCTAssertTrue(summary.emails.contains("haneul@example.com"), "편 명함에서 메일을 못 읽었다 — 읽은 줄: \(summary.lines)")
    }

    /// 어두운 책상 위에 명함을 비스듬히 놓은 사진.
    private static func photo(of card: Data, size: CGSize, degrees: CGFloat) -> Data? {
        guard let cardImage = UIImage(data: card) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.18, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let width = size.width * 0.45
            let height = width * cardImage.size.height / cardImage.size.width
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: degrees * .pi / 180)
            cardImage.draw(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.9)
    }
}
