import SwiftUI

/// **꺼진 단추는 회색** (빌드 46 실기기 · 2026-11-03 사용자) — 양식(Form) 안의 그림 + 글자 단추(`Label`)는 꺼지면 글자가 검게 남아
/// 눌리는 단추처럼 보였다. 꺼졌을 때만 보충 설명과 같은 `Color.muted` 로 칠한다. 켜져 있으면 손대지 않는다(강조색 · 빨강 그대로).
/// 단추 안의 `Label` 에 붙인다 — `.disabled` 가 안쪽으로 `isEnabled` 를 내려 준다.
private struct MutedWhenDisabled: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if isEnabled {
            content
        } else {
            content.foregroundStyle(Color.muted)
        }
    }
}

extension View {
    func mutedWhenDisabled() -> some View {
        modifier(MutedWhenDisabled())
    }
}
