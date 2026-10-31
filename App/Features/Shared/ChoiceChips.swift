import Core
import SwiftUI

/// 선택지 칩 + `직접 입력` (요구사항 4.2.2). 하나만 고르고, 다시 누르면 푼다.
/// 선택지에는 전에 직접 입력해 쓴 값도 붙어 온다 (이슈 13 — `RelationshipPresets.choices`).
///
/// 저장값은 표시 라벨 문자열 하나다 — 선택지에서 골랐는지 직접 썼는지 구분하지 않는다 (6.3).
struct ChoiceChips: View {
    let options: [String]
    @Binding var selection: String?
    var customPrompt = "직접 입력"
    var maxLength = 50

    @State private var customText = ""
    @State private var showingCustom = false

    /// 지금 값이 선택지에 없는 직접 입력인가.
    private var isCustomSelected: Bool {
        guard let selection, !selection.isEmpty else { return false }
        return !options.contains(selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WrapLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selection == option {
                            selection = nil
                        } else {
                            selection = option
                        }
                        showingCustom = false
                        customText = ""
                    } label: {
                        Chip(text: option, selected: selection == option)
                            .tapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
                Button {
                    showingCustom.toggle()
                    if showingCustom {
                        customText = isCustomSelected ? (selection ?? "") : ""
                        if !isCustomSelected { selection = nil }
                    }
                } label: {
                    Chip(text: customPrompt, selected: isCustomSelected || showingCustom)
                        .tapTarget()
                }
                .buttonStyle(.plain)
            }
            if showingCustom || isCustomSelected {
                TextField(customPrompt, text: $customText)
                    .font(.scaled(16))
                    .textFieldStyle(.roundedBorder)
                    .limited($customText, to: maxLength)
                    .onChange(of: customText) { _, newValue in
                        // 선택지 칩을 누르며 비운 글자는 선택을 지우지 않는다 — 그때는 showingCustom 이 이미 false 다.
                        guard showingCustom else { return }
                        selection = TextNormalization.nilIfEmpty(newValue)
                    }
            }
        }
        .onAppear {
            // 수정 화면에서 직접 입력값으로 들어오면 칸을 열어 둔다 — 글자를 다 지워도 칸이 사라지지 않게.
            if isCustomSelected {
                showingCustom = true
                customText = selection ?? ""
            }
        }
        .onChange(of: options) { _, newOptions in
            // 직접 입력해 쓴 값이 선택지로 붙으면(이슈 13) 그 칩이 골라진 것으로 보이고 입력 칸은 닫는다.
            if let selection, newOptions.contains(selection), showingCustom {
                showingCustom = false
                customText = ""
            }
        }
    }
}
