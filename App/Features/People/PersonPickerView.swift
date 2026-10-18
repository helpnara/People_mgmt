import Core
import SwiftUI

/// 등록된 사람 가운데 한 명을 고른다 — 소개한 사람(FR-043), 나중에는 함께한 사람(FR-042)에도 쓴다.
struct PersonPickerView: View {
    let people: [Person]
    @Binding var selection: Person?
    /// 제목 — 사람 편집에서는 `소개한 사람`, 단축어 `기록 추가` 에서는 `누구와의 기록인가요` (빌드 16).
    var title = "소개한 사람"

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    /// 접은 이름(`people` 과 같은 차례)과 거른 결과. **본문에서 전원을 접지 않는다** (전수조사 이슈 18) —
    /// 사람 수가 바뀔 때 한 번 접고, 검색어가 바뀔 때만 거른다.
    @State private var foldedNames: [String] = []
    @State private var filtered: [Person] = []

    private func refold() {
        foldedNames = people.map { TextNormalization.folded($0.name) }
        refilter()
    }

    private func refilter() {
        let key = TextNormalization.folded(searchText)
        guard !key.isEmpty, foldedNames.count == people.count else {
            filtered = people
            return
        }
        filtered = zip(people, foldedNames).filter { $0.1.contains(key) }.map { $0.0 }
    }

    var body: some View {
        List {
            Button {
                selection = nil
                dismiss()
            } label: {
                HStack {
                    Text("선택 안 함").foregroundStyle(Color.bodyText)
                    Spacer()
                    if selection == nil { Image(systemName: "checkmark").foregroundStyle(Color.accent) }
                }
            }
            ForEach(filtered) { person in
                Button {
                    selection = person
                    dismiss()
                } label: {
                    HStack {
                        PersonRow(person: person, evidence: nil)
                        Spacer()
                        if selection === person { Image(systemName: "checkmark").foregroundStyle(Color.accent) }
                    }
                }
            }
            if filtered.isEmpty && foldedNames.count == people.count {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        .searchable(text: $searchText, prompt: "이름")
        .task(id: people.count) { refold() }
        .onChange(of: searchText) { _, _ in refilter() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
