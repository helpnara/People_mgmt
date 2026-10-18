import Core
import CoreImage
import Foundation
import UIKit
import Vision

/// 명함 사진 다루기 (FR-050). **전부 기기 안에서** — 네트워크가 없다.
///
/// - 사진첩 사진: 명함 테두리(사각형)를 찾아 반듯하게 편다. 못 찾으면 그대로 줄인다
/// - 문서 카메라 사진: 카메라가 이미 테두리를 찾아 폈으므로 줄이기만 한다
/// - 글자 읽기: Vision 의 글자 인식(한국어 · 영어)으로 줄과 그 높이를 돌려준다 — 해석은 `Core.BusinessCardParser`
///
/// 무거운 일은 `Task.detached` 에서 한다. 주고받는 것은 `Data` · 값뿐이다 (`Sendable`).
enum CardImaging {
    /// 저장하는 사진의 긴 변. 명함 글자를 다시 읽기에 넉넉하고 저장소를 덜 먹는 크기.
    static let maxLongSide: CGFloat = 1_600

    /// 사진첩 사진 → 테두리를 찾아 편 명함 JPEG.
    static func straightenedCard(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) { straighten(data) }.value
    }

    /// 이미 편 사진(문서 카메라) → 줄인 JPEG.
    static func normalizedCard(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            UIImage(data: data).flatMap { jpeg(downscaled($0)) }
        }.value
    }

    /// 명함 글자를 위에서 아래 순서의 줄로.
    static func recognizeLines(in data: Data) async -> [CardLine] {
        await Task.detached(priority: .userInitiated) { recognize(data) }.value
    }

    // MARK: - 안쪽 (어느 스레드에서든)

    private static func straighten(_ data: Data) -> Data? {
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return UIImage(data: data).flatMap { jpeg(downscaled($0)) }
        }
        let request = VNDetectRectanglesRequest()
        // 명함은 짧은 변 / 긴 변이 0.55~0.6 쯤이다. 넉넉히 잡는다.
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.25
        request.minimumConfidence = 0.6
        request.quadratureTolerance = 25
        request.maximumObservations = 1
        let handler = VNImageRequestHandler(ciImage: source, options: [:])
        try? handler.perform([request])

        var output = source
        if let rectangle = request.results?.first, let filter = CIFilter(name: "CIPerspectiveCorrection") {
            let extent = source.extent
            func point(_ normalized: CGPoint) -> CIVector {
                CIVector(x: extent.origin.x + normalized.x * extent.width, y: extent.origin.y + normalized.y * extent.height)
            }
            filter.setValue(source, forKey: kCIInputImageKey)
            filter.setValue(point(rectangle.topLeft), forKey: "inputTopLeft")
            filter.setValue(point(rectangle.topRight), forKey: "inputTopRight")
            filter.setValue(point(rectangle.bottomLeft), forKey: "inputBottomLeft")
            filter.setValue(point(rectangle.bottomRight), forKey: "inputBottomRight")
            if let corrected = filter.outputImage { output = corrected }
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return jpeg(downscaled(UIImage(cgImage: cgImage)))
    }

    private static func recognize(_ data: Data) -> [CardLine] {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // 이름 · 회사 이름은 사전에 없는 낱말이라 고쳐 읽기를 끈다.
        request.usesLanguageCorrection = false
        // 기기 · 시뮬레이터가 갖춘 언어만 고른다 — 없는 언어를 적으면 인식 전체가 실패한다.
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let wanted = ["ko-KR", "en-US"].filter { supported.contains($0) }
        if !wanted.isEmpty { request.recognitionLanguages = wanted }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])
        let observations = request.results ?? []
        // Vision 의 좌표는 아래가 0 이다 — 위에서 아래로 읽으려면 윗변이 큰 것부터.
        return observations
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { observation in
                observation.topCandidates(1).first.map {
                    CardLine(text: $0.string, height: Double(observation.boundingBox.height))
                }
            }
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else { return image }
        let scale = maxLongSide / longSide
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func jpeg(_ image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.82)
    }
}

/// 명함 글자 읽기를 한 번에 — 화면과 앱 테스트가 같은 길을 쓴다.
enum CardReading {
    static func read(_ data: Data) async -> CardSuggestion {
        BusinessCardParser.parse(await CardImaging.recognizeLines(in: data))
    }

    /// 앱 테스트용 요약 (테스트 대상에 Core 를 따로 잇지 않으려고 글자만 넘긴다).
    static func summary(_ data: Data) async -> (emails: [String], phones: [String], lines: [String], name: String?) {
        let suggestion = await read(data)
        return (suggestion.emails, suggestion.phones, suggestion.lines, suggestion.name)
    }
}
