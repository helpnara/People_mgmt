import SwiftUI

/// 선택지 · 태그에 쓰는 알약. 색은 토큰으로만, 크기는 글자를 따라간다.
///
/// 큰 글씨(AX1~AX5)에서는 화면보다 넓어질 수 있어 **두 줄까지 접는다** (`WrapLayout` 이 폭을 넘겨준다 · D-33).
/// 누르는 칩은 `.tapTarget()` 으로 누르는 자리를 44pt 까지 넓힌다 — 보여 주기만 하는 칩(상세의 유형 · 태그)은 그대로.
struct Chip: View {
    let text: String
    var selected = false
    var showsRemove = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.scaled(14, weight: selected ? .semibold : .regular))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if showsRemove {
                Image(systemName: "xmark.circle.fill")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.horizontal, Font.scaledLength(11))
        .padding(.vertical, Font.scaledLength(6))
        .foregroundStyle(selected ? Color.accent : Color.chipInk)
        .background(selected ? Color.accentSoft : Color.chip, in: Capsule())
        .overlay(Capsule().strokeBorder(selected ? Color.accent : Color.clear, lineWidth: 1))
    }
}

extension View {
    /// **누르는 자리 44pt** (글자 배율을 따라 · 요구사항 8.6 · D-33) — 보이는 알약은 그대로 두고 둘레를 눌러도 되게.
    func tapTarget() -> some View {
        frame(minHeight: Font.scaledLength(44))
            .contentShape(Rectangle())
    }
}
