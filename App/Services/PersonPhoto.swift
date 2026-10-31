import Foundation
import SwiftUI
import UIKit

/// **사람 사진** (FR-012 · 7판) — 받은 사진을 긴 변 1,024px JPEG 로 줄여 담는다. 원본을 그대로 담지 않는다(휴대폰 사진은 수 MB · 이슈 10).
enum PersonPhoto {
    static let maxLongSide: CGFloat = 1_024

    /// 주 스레드 밖에서 ImageIO 로 **풀기 전에** 줄인다 (`CardImaging.thumbnail` 과 같은 길).
    static func normalized(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let image = CardImaging.thumbnail(data, maxPixel: maxLongSide) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
        }.value
    }
}

/// 사진 미리보기 — 한 번 풀어 둔 그림을 사람 · 고친 시각으로 기억한다. **본문에서 사진을 풀지 않는다** (CLAUDE.md · 이슈 10).
@MainActor
final class PhotoThumbnails {
    static let shared = PhotoThumbnails()
    private let cache = NSCache<NSString, UIImage>()
    /// 사진이 없다고 알아 둔 열쇠 — 다시 읽지 않게.
    private var empty = Set<String>()

    func cached(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func isKnownEmpty(_ key: String) -> Bool { empty.contains(key) }

    /// 사진 칸을 한 번 읽어(저장소 밖 파일) ImageIO 로 **풀기 전에** 줄인다 — 1,024px 사진을 목록 크기로 줄이는 일이라 가볍다
    /// (`BusinessCardThumbnail` 과 같은 길).
    func load(_ key: String, data: Data?, pixel: CGFloat) -> UIImage? {
        if let image = cached(key) { return image }
        guard let data, let image = CardImaging.thumbnail(data, maxPixel: pixel).map({ UIImage(cgImage: $0) }) else {
            empty.insert(key)
            return nil
        }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

/// 둥근 사진 — 사진이 없으면 이름 첫 글자. 목록 · 상세 · 수정 화면이 같은 모양을 쓴다.
struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 40
    /// 사진이 없을 때 첫 글자 대신 쓸 그림 — 목록 맨 위 `나` 줄의 사람 그림.
    var placeholderSymbol: String?

    @State private var image: UIImage?

    private var key: String { "\(person.uuid.uuidString)-\(person.updatedAt.timeIntervalSince1970)-\(Int(size))" }

    var body: some View {
        if person.isGone {
            EmptyView()
        } else {
            AvatarCircle(image: image, initial: String(person.name.prefix(1)), size: size, symbol: placeholderSymbol)
                .task(id: key) {
                    let key = key
                    if let hit = PhotoThumbnails.shared.cached(key) {
                        image = hit
                        return
                    }
                    guard !PhotoThumbnails.shared.isKnownEmpty(key) else {
                        image = nil
                        return
                    }
                    image = PhotoThumbnails.shared.load(key, data: person.photo, pixel: Font.scaledLength(size) * 3)
                }
        }
    }
}

/// 둥근 그림 한 장 — 그림이 없으면 첫 글자.
struct AvatarCircle: View {
    let image: UIImage?
    let initial: String
    let size: CGFloat
    var symbol: String?

    var body: some View {
        // 큰 글씨에서는 커지되 처음 크기의 1.6배에서 멈춘다 — 이름 칸을 밀어내지 않게.
        let side = min(Font.scaledLength(size), size * 1.6)
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let symbol {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.accent)
            } else {
                Text(initial)
                    .font(.scaled(size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentSoft)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// 수정 화면의 사진 미리보기 — 아직 저장하지 않은 사진(Data)을 한 번만 풀어 보인다.
struct DraftPhotoPreview: View {
    let data: Data?
    let initial: String
    var size: CGFloat = 72

    @State private var image: UIImage?

    var body: some View {
        AvatarCircle(image: image, initial: initial, size: size)
            .task(id: data) {
                image = data.flatMap { CardImaging.thumbnail($0, maxPixel: Font.scaledLength(size) * 3) }.map { UIImage(cgImage: $0) }
            }
    }
}
