import SwiftUI
import UIKit

/// 명함 사진 한 장 — 상세 · 편집에서 같은 모양으로.
///
/// **본문에서 사진을 풀지 않는다 (이슈 10).** 사진은 자료가 바뀔 때 한 번만, 보여 줄 크기로 줄여 푼다 —
/// 빌드 4 에서 펴지 못한 원본(수 MB)이 저장되면 화면이 그려질 때마다 원본 크기로 다시 풀렸다.
struct BusinessCardThumbnail: View {
    let data: Data
    var maxHeight: CGFloat = 180

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.rule.opacity(0.3))
                    .aspectRatio(1.75, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: Font.scaledLength(maxHeight))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.rule, lineWidth: 1))
        .accessibilityLabel("명함 사진")
        .task(id: data) {
            image = CardImaging.thumbnail(data, maxPixel: 900).map { UIImage(cgImage: $0) }
        }
    }
}

/// 명함 크게 보기. 두 손가락으로 키우고, 닫기로 나간다.
///
/// **바깥 틀은 늘 있는 `ZStack` 이다 (이슈 14).** 빌드 5 ~ 7 은 `Group { if let image { … } }` 이었다 —
/// 그림을 풀기 전에는 `Group` 이 비고, SwiftUI 는 빈 `Group` 에 붙은 수식어(`.task` · `.toolbar`)를 붙일 곳이 없어 버린다.
/// 그래서 그림을 푸는 일도 `닫기` 도 사라져 빈 화면에 갇혔다. 조건만 있는 `Group` 에 수식어를 붙이지 않는다.
struct BusinessCardViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    /// 크게 볼 때도 원본 크기로 풀지 않는다 — 화면 두 배면 넉넉하다 (이슈 10).
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ground.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 4) }
                                .onEnded { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            scale = scale > 1 ? 1 : 2
                            lastScale = scale
                        }
                        .padding()
                        .accessibilityLabel("명함 사진")
                } else if failed {
                    ContentUnavailableView("명함 사진을 열지 못했습니다", systemImage: "photo",
                                           description: Text("편집에서 명함을 다시 고르거나 촬영해 주세요."))
                } else {
                    ProgressView()
                }
            }
            .task(id: data) {
                let decoded = CardImaging.thumbnail(data, maxPixel: 2_400).map { UIImage(cgImage: $0) }
                image = decoded
                failed = decoded == nil
            }
            .navigationTitle("명함")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
