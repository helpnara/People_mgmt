import Core
import CoreImage
import Foundation
import ImageIO
import UIKit
import Vision

/// 명함 사진 다루기 (FR-050). **전부 기기 안에서** — 네트워크가 없다.
///
/// - 사진첩 사진: 명함 테두리(사각형)를 찾아 반듯하게 편다. 못 찾으면 그대로 줄인다
/// - 문서 카메라 사진: 카메라가 이미 테두리를 찾아 폈으므로 줄이기만 한다
/// - 글자 읽기: Vision 의 글자 인식(한국어 · 영어)으로 줄과 그 높이를 돌려준다 — 해석은 `Core.BusinessCardParser`
///
/// 무거운 일은 `Task.detached` 에서 한다. 주고받는 것은 `Data` · 값뿐이다 (`Sendable`).
///
/// **사진은 원본 해상도로 풀지 않는다 (이슈 10).** 2,400만 화소 사진을 통째로 풀면 중간 그림 하나가 수백 MB 다 —
/// iOS 가 메모리 초과로 앱을 끈다(느린 여백 181 과 같은 모양). ImageIO 로 **처음부터 줄여 읽는다**.
enum CardImaging {
    /// 저장하는 사진의 긴 변. 명함 글자를 다시 읽기에 넉넉하고 저장소를 덜 먹는 크기.
    static let maxLongSide: CGFloat = 1_600
    /// 테두리를 찾고 펼 때 쓰는 사진의 긴 변. 명함이 사진의 절반만 차지해도 편 뒤 긴 변이 1,600px 가까이 남는다.
    static let workingLongSide: CGFloat = 3_200

    /// 사진첩 사진 → 테두리를 찾아 편 명함 JPEG.
    static func straightenedCard(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) { straighten(data) }.value
    }

    /// 이미 편 사진(문서 카메라) → 줄인 JPEG.
    static func normalizedCard(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            thumbnail(data, maxPixel: maxLongSide).flatMap { jpeg(UIImage(cgImage: $0)) }
        }.value
    }

    /// 명함 글자를 위에서 아래 순서의 줄로.
    static func recognizeLines(in data: Data) async -> [CardLine] {
        await Task.detached(priority: .userInitiated) { recognize(data) }.value
    }

    // MARK: - 안쪽 (어느 스레드에서든)

    private static func straighten(_ data: Data) -> Data? {
        // 줄여 읽으면서 사진의 방향(세로로 찍은 사진)도 바로 세운다.
        guard let working = thumbnail(data, maxPixel: workingLongSide) else { return nil }
        let source = CIImage(cgImage: working)
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
        // 중간 그림을 붙들어 두지 않는다 — 한 번 쓰고 버리는 그림이다.
        let context = CIContext(options: [.cacheIntermediates: false])
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

    /// ImageIO 로 **풀기 전에** 줄인다. 원본 전체를 메모리에 올리지 않는다. 방향(EXIF)을 적용한 그림을 준다.
    /// 원본이 `maxPixel` 보다 작으면 원본 크기 그대로.
    static func thumbnail(_ data: Data, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
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
