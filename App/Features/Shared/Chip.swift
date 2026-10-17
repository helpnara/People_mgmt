import SwiftUI

/// 선택지 · 태그에 쓰는 알약. 색은 토큰으로만, 크기는 글자를 따라간다.
struct Chip: View {
    let text: String
    var selected = false
    var showsRemove = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.scaled(14, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .fixedSize()
            if showsRemove {
                Image(systemName: "xmark.circle.fill")
                    .font(.scaled(13))
                    .foregroundStyle(Color.faint)
            }
        }
        .padding(.horizontal, Font.scaledLength(11))
        .padding(.vertical, Font.scaledLength(6))
        .foregroundStyle(selected ? Color.accent : Color.chipInk)
        .background(selected ? Color.accentSoft : Color.chip, in: Capsule())
        .overlay(Capsule().strokeBorder(selected ? Color.accent : Color.clear, lineWidth: 1))
    }
}
