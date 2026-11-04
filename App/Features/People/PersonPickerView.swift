import Core
import SwiftUI

/// 등록된 사람 가운데 한 명을 고른다 — 소개한 사람(FR-043), 나중에는 함께한 사람(FR-042)에도 쓴다.
struct PersonPickerView: View {
    let people: [Person]
    @Binding var selection: Person?
    /// 제목 — 사람 편집에서는 `소개한 사람`, 단축어 `기록 추가` 에서는 `누구와의 기록인가요` (빌드 16).
    var title = "소개한 사람"

    @Environment(\.dismiss) private var dismiss
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
                        PersonRow(person: person, evidence: evidence[person.uuid])
                        Spacer()
                        if selection === person { Image(systemName: "checkmark").foregroundStyle(Color.accent) }
                    }
                }
            }
            if noMatch {
                Text("일치하는 사람이 없습니다").foregroundStyle(Color.muted)
            }
        }
        // 검색 칸을 늘 보이게 (이슈 49) — 기본 자리에서는 목록을 끌어내려야 나타나 없는 줄 알았다.
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: PeopleSearch.prompt)
        // 찾는 동안 키보드가 가린 아래 줄까지 내려갈 수 있게 (이슈 80).
        .keyboardScrollRoom()
        .task(id: people.count) {
            filtered = people
            index = await SearchIndexBuilder.build(container: context.container)
        }
        .task(id: SearchKey(text: searchText, ready: index != nil, count: people.count)) { await refilter() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
