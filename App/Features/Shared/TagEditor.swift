import Core
import SwiftUI

/// 태그 입력 (요구사항 4.2.2 · 7.2). 줄바꿈 · 쉼표로 넣고, 칩의 ⓧ 로 뺀다. 정리 규칙은 `Core.TagNormalizer` 하나다.
struct TagEditor: View {
    @Binding var tags: [String]
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                WrapLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Chip(text: "#\(tag)", showsRemove: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tag) 태그 제거")
                    }
                }
            }
            TextField("태그 입력 후 줄바꿈 (쉼표로 여러 개)", text: $input)
                .font(.scaled(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: input) { _, newValue in
                    if newValue.contains(",") || newValue.contains("\n") { commit() }
                }
                .disabled(tags.count >= TagNormalizer.maxCount)
            if tags.count >= TagNormalizer.maxCount {
                Text("태그는 \(TagNormalizer.maxCount)개까지 붙일 수 있습니다")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
        }
    }

    private func commit() {
        let parsed = TagNormalizer.parse(input)
        tags = TagNormalizer.normalizeList(tags + parsed)
        input = ""
    }
}
