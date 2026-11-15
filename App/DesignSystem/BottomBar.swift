import SwiftUI

/// **화면 아래에 떠 있는 것** (1.1.12 · 이슈 114) — 홈의 찾기 칸 · 사람 상세의 `기록 추가`.
///
/// 빌드 73 의 직접 그린 흐림 띠(`BottomFade`)는 화면 맨 아래까지 내려가지 못하고 떠 있는 것 위에 40pt 회색 띠로만 남아
/// 위 경계가 칼로 자른 듯 보였다(2026-11-15 사용자 화면 사진). iOS 26 의 시스템 가장자리 흐림(scroll edge effect)을 쓴다 —
/// 시스템 막대처럼 뒤 목록 글자를 부드럽게 흐린다. iOS 17 · 18 에서는 흐림 없이 그대로 둔다.
extension View {
    /// 목록의 아래 가장자리를 시스템 흐림으로 — 아래 찾기 칸 뒤 글자가 비치지 않게.
    @ViewBuilder
    func softBottomEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }

    /// 떠 있는 아래 막대 — iOS 26 은 `safeAreaBar`(뒤 목록이 시스템 흐림을 받는다), 그 앞은 `safeAreaInset`.
    @ViewBuilder
    func floatingBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, content: bar)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self.safeAreaInset(edge: .bottom, content: bar)
        }
    }
}
