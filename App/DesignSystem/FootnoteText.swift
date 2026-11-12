import Core
import SwiftUI

/// **긴 설명은 첫 문장만** (1.1.11 · 이슈 111 · CLAUDE.md 디자인은 늘 고급스럽게) — 칸 아래 설명이 몇 줄씩 이어지면
/// 화면이 설명서처럼 보인다. 첫 문장만 보이고, 나머지가 있으면 `자세히` 로 편다(`접기` 로 다시 접는다).
/// 나누는 규칙은 `Core.Footnote` 하나다(정답표 `footnoteSplit`). 큰 글씨 · VoiceOver 는 펼친 글을 그대로 읽는다.
struct FootnoteText: View {
    let text: String
    @State private var expanded = false

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let parts = Footnote.split(text)
        if parts.rest.isEmpty {
            Text(text)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(expanded ? parts.head + " " + parts.rest : parts.head)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Text(expanded ? "접기" : "자세히")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.scaled(10, weight: .semibold))
                    }
                    .font(.scaled(12, weight: .semibold))
                    .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "설명 접기" : "설명 자세히 보기")
            }
        }
    }
}
