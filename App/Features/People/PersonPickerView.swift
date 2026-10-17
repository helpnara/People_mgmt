import Core
import SwiftUI

/// 등록된 사람 가운데 한 명을 고른다 — 소개한 사람(FR-043), 나중에는 함께한 사람(FR-042)에도 쓴다.
struct PersonPickerView: View {
    let people: [Person]
    @Binding var selection: Person?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Person] {
        let key = TextNormalization.folded(searchText)
        guard !key.isEmpty else { return people }
        return people.filter { TextNormalization.folded($0.name).contains(key) }
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
            if filtered.isEmpty {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        .searchable(text: $searchText, prompt: "이름")
        .navigationTitle("소개한 사람")
        .navigationBarTitleDisplayMode(.inline)
    }
}
