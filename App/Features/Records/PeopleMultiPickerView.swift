import Core
import SwiftUI

/// 함께한 사람 여러 명 고르기 (FR-042). `locked` 는 기록을 연 사람 — 새 기록에서는 빠질 수 없다.
struct PeopleMultiPickerView: View {
    let people: [Person]
    @Binding var selection: [Person]
    var locked: Person?

    @State private var searchText = ""

    private var filtered: [Person] {
        let key = TextNormalization.folded(searchText)
        guard !key.isEmpty else { return people }
        return people.filter { TextNormalization.folded($0.name).contains(key) }
    }

    private func isSelected(_ person: Person) -> Bool {
        selection.contains { $0 === person }
    }

    private func toggle(_ person: Person) {
        if let index = selection.firstIndex(where: { $0 === person }) {
            guard person !== locked else { return }
            selection.remove(at: index)
        } else {
            selection.append(person)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { person in
                Button {
                    toggle(person)
                } label: {
                    HStack {
                        PersonRow(person: person, evidence: nil)
                        Spacer()
                        if person === locked {
                            Text("기록을 연 사람").font(.scaled(12)).foregroundStyle(Color.faint)
                        }
                        Image(systemName: isSelected(person) ? "checkmark.circle.fill" : "circle")
                            .font(.scaled(20))
                            .foregroundStyle(isSelected(person) ? Color.accent : Color.faint)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected(person) ? .isSelected : [])
            }
            if filtered.isEmpty {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        .searchable(text: $searchText, prompt: "이름")
        .navigationTitle("함께한 사람 \(selection.count)명")
        .navigationBarTitleDisplayMode(.inline)
    }
}
