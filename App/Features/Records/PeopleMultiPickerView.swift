import Core
import SwiftUI

/// 함께한 사람 여러 명 고르기 (FR-042). `locked` 는 기록을 연 사람 — 새 기록에서는 빠질 수 없다.
struct PeopleMultiPickerView: View {
    let people: [Person]
    @Binding var selection: [Person]
    var locked: Person?
    /// 제목 앞말 — 기록에서는 `함께한 사람`, 사람 편집에서는 `아는 사람` (D-30).
    var title = "함께한 사람"

    /// CI 스크린샷 — 검색어를 넣은 채 연다 (`-pickerSearch ㅈㅇ`).
    @State private var searchText = LaunchArguments.current.pickerSearch ?? ""
    /// 접은 이름 · 별명 · 소속(`people` 과 같은 차례)과 거른 결과 — `PickerSearchKey` (이슈 49).
    @State private var foldedNames: [PickerSearchKey] = []
    @State private var filtered: [Person] = []

    private func refold() {
        foldedNames = people.map { PickerSearchKey($0) }
        refilter()
    }

    private func refilter() {
        let key = TextNormalization.folded(searchText)
        guard !key.isEmpty, foldedNames.count == people.count else {
            filtered = people
            return
        }
        filtered = zip(people, foldedNames).filter { $0.1.matches(key) }.map { $0.0 }
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
                            Text("기록을 연 사람").font(.scaled(12)).foregroundStyle(Color.muted)
                        }
                        Image(systemName: isSelected(person) ? "checkmark.circle.fill" : "circle")
                            .font(.scaled(20))
                            .foregroundStyle(isSelected(person) ? Color.accent : Color.faint)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected(person) ? .isSelected : [])
            }
            if filtered.isEmpty && foldedNames.count == people.count {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        // 검색 칸을 늘 보이게 (이슈 49) — 기본 자리에서는 목록을 끌어내려야 나타나 없는 줄 알았다.
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "이름 · 별명 · 소속 · 초성")
        .task(id: people.count) { refold() }
        .onChange(of: searchText) { _, _ in refilter() }
        .navigationTitle("\(title) \(selection.count)명")
        .navigationBarTitleDisplayMode(.inline)
    }
}
