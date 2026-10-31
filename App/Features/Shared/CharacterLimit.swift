import SwiftUI

extension View {
    /// 글자 수 제한 (요구사항 7.2). 넘는 입력은 그 자리에서 자르고, **한도의 80% 를 넘으면 남은 글자 수를 보인다**
    /// (`120/200` · 전수조사 이슈 22). 숫자는 칸 위에 겹쳐 그려 줄 높이가 바뀌지 않는다.
    func limited(_ text: Binding<String>, to limit: Int) -> some View {
        modifier(CharacterLimitModifier(text: text, limit: limit))
    }
}

private struct CharacterLimitModifier: ViewModifier {
    @Binding var text: String
    let limit: Int

    func body(content: Content) -> some View {
        // 이 칸 하나의 글자 수 — 사람 전원을 훑는 셈이 아니다.
        let count = text.count
        let near = limit > 0 && count * 5 >= limit * 4
        content
            .onChange(of: text) { _, newValue in
                if newValue.count > limit {
                    text = String(newValue.prefix(limit))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if near {
                    Text("\(count)/\(limit)")
                        .font(.scaled(11))
                        .monospacedDigit()
                        .foregroundStyle(count >= limit ? Color.danger : Color.muted)
                        .padding(.horizontal, 4)
                        .background(Color.raised.opacity(0.9), in: Capsule())
                        .allowsHitTesting(false)
                        .accessibilityLabel("\(limit)자 중 \(count)자")
                }
            }
    }
}
