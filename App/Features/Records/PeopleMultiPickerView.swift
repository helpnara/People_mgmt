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
    @Environment(\.modelContext) private var context
    /// 홈 검색과 같은 색인 · 규칙 (`PeopleSearch` · 이슈 64) — 기록 내용 · 태그 · 초성까지.
    @State private var index: SearchIndex?
    @State private var filtered: [Person] = []
    @State private var evidence: [UUID: String] = [:]
    /// 검색어가 있는데 맞는 사람이 없을 때.
    @State private var noMatch = false

    private struct SearchKey: Hashable {
        let text: String
        let ready: Bool
        let count: Int
    }

    /// 홈과 같이 — 검색어가 멈춘 뒤 한 번, 견주기는 주 스레드 밖에서.
    private func refilter() async {
        let query = SearchQuery(parsing: searchText)
        guard !query.isEmpty else {
            filtered = people
            evidence = [:]
            noMatch = false
            return
        }
        guard let index else { return }
        try? await Task.sleep(for: PeopleSearch.debounce)
        guard !Task.isCancelled else { return }
        let hits = await Task.detached(priority: .userInitiated) { SearchMatcher.hits(query, in: index) }.value
        guard !Task.isCancelled else { return }
        let picked = PeopleSearch.pick(hits, from: people)
        filtered = picked.people
        evidence = picked.evidence
        noMatch = picked.people.isEmpty
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
                        PersonRow(person: person, evidence: evidence[person.uuid])
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
            if noMatch {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        // 검색 칸을 늘 보이게 (이슈 49) — 기본 자리에서는 목록을 끌어내려야 나타나 없는 줄 알았다.
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: PeopleSearch.prompt)
        .task(id: people.count) {
            filtered = people
            index = await SearchIndexBuilder.build(container: context.container)
        }
        .task(id: SearchKey(text: searchText, ready: index != nil, count: people.count)) { await refilter() }
        .navigationTitle("\(title) \(selection.count)명")
        .navigationBarTitleDisplayMode(.inline)
    }
}
