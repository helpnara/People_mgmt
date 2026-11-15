import SwiftUI

/// **아래 가장자리 흐림** (1.1.12 · 이슈 113 · 디자인 정리 2) — 화면 아래에 떠 있는 것(홈의 찾기 칸 · 사람 상세의 `기록 추가`)
/// 뒤로 목록 글자가 비쳐 겹쳐 보였다. 바탕색으로 아래로 갈수록 진해지게 덮어 겹침을 지운다. 누르기 · 읽어 주기는 그대로 통과한다.
/// 목록의 배치는 바꾸지 않는다(덧그림) — 끝까지 내리면 마지막 줄은 떠 있는 것 위로 올라온다.
/// 띠는 안전 영역 아래 끝(떠 있는 것의 위)에서 `height` 만큼 위로 시작해 화면 맨 아래까지 덮는다.
struct BottomFade: ViewModifier {
    /// 흐림 띠의 높이(글자 크기에 맞춰 커진다).
    var height: CGFloat = 40

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            LinearGradient(colors: [Color.ground.opacity(0), Color.ground.opacity(0.94)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: Font.scaledLength(height))
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func bottomFade(height: CGFloat = 40) -> some View {
        modifier(BottomFade(height: height))
    }
}
