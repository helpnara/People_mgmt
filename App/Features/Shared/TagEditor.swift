import Core
import SwiftUI

/// 태그 입력 (요구사항 4.2.2 · 7.2). 줄바꿈 · 쉼표로 넣고, 칩의 ⓧ 로 뺀다. 정리 규칙은 `Core.TagNormalizer` 하나다.
///
/// **치던 글자는 부르는 쪽이 쥔다** (전수조사 이슈 19). 태그를 치다가 줄바꿈 없이 바로 `저장` 을 누르면 그 태그가
/// 조용히 버려졌다. 입력 칸 글자(`input`)를 바인딩으로 올려, 저장할 때 `TagEditor.merged(_:pending:)` 로 넣는다.
///
/// **자동완성** (FR-026) — 치는 동안 앱에 있는 태그 가운데 맞는 것을 칩으로 보인다(초성도). 누르면 붙는다.
/// 모음(`TagCatalog`)은 부르는 쪽이 주 스레드 밖에서 만들어 넘긴다. 아직 없으면 자동완성 없이 그대로 쓴다.
struct TagEditor: View {
    @Binding var tags: [String]
    @Binding var input: String
    var catalog: TagCatalog?

    /// 치는 글자 · 붙인 태그가 바뀔 때만 센다 — 본문에서 모음을 훑지 않는다.
    @State private var suggestions: [String] = []

    /// 저장할 때 — 아직 칩이 되지 않은 글자까지 넣은 태그 목록.
    static func merged(_ tags: [String], pending: String) -> [String] {
        let parsed = TagNormalizer.parse(pending)
        guard !parsed.isEmpty else { return tags }
        return TagNormalizer.normalizeList(tags + parsed)
    }

    var body: some View {
        content
            .onChange(of: input) { _, _ in refreshSuggestions() }
            .onChange(of: tags) { _, _ in refreshSuggestions() }
            .onChange(of: catalog) { _, _ in refreshSuggestions() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                WrapLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Chip(text: "#\(tag)", showsRemove: true)
                                .tapTarget()
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
            if !suggestions.isEmpty && tags.count < TagNormalizer.maxCount {
                WrapLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button {
                            tags = TagNormalizer.normalizeList(tags + [tag])
                            input = ""
                        } label: {
                            // 최근 함께한 사람 칩과 같은 모양 — `Label` 로 그렸더니 입력 화면 안에서 글자가 빠지고 + 만 보였다
                            // (빌드 27 실기기 · 사용자 화면 사진).
                            Chip(text: "+ #\(tag)", selected: false)
                                .tapTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tag) 태그 붙이기")
                    }
                }
            }
            if tags.count >= TagNormalizer.maxCount {
                Text("태그는 \(TagNormalizer.maxCount)개까지 붙일 수 있습니다")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
        }
    }

    private func refreshSuggestions() {
        suggestions = catalog?.suggestions(for: input, excluding: tags, limit: 6) ?? []
    }

    private func commit() {
        tags = Self.merged(tags, pending: input)
        input = ""
    }
}
