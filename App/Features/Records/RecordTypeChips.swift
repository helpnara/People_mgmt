import Core
import SwiftUI

/// 기록 유형 선택 (요구사항 6.4). 반드시 하나. 직접 입력은 없다 — 키가 고정값이라서.
struct RecordTypeChips: View {
    @Binding var selection: String

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(RecordType.all) { type in
                Button {
                    selection = type.key
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: type.symbol).font(.scaled(13))
                        Text(type.label)
                            .font(.scaled(14, weight: selection == type.key ? .semibold : .regular))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, Font.scaledLength(11))
                    .padding(.vertical, Font.scaledLength(6))
                    .foregroundStyle(selection == type.key ? Color.accent : Color.chipInk)
                    .background(selection == type.key ? Color.accentSoft : Color.chip, in: Capsule())
                    .overlay(Capsule().strokeBorder(selection == type.key ? Color.accent : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == type.key ? .isSelected : [])
            }
        }
    }
}
