import SwiftUI
import UIKit

/// 명함 사진 한 장 — 상세 · 편집에서 같은 모양으로.
struct BusinessCardThumbnail: View {
    let data: Data
    var maxHeight: CGFloat = 180

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: Font.scaledLength(maxHeight))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.rule, lineWidth: 1))
                .accessibilityLabel("명함 사진")
        }
    }
}

/// 명함 크게 보기. 두 손가락으로 키우고, 닫기로 나간다.
struct BusinessCardViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(data: data) {
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ground)
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
