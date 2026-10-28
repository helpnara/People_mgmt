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
        // 검색 칸을 늘 보이게 (이슈 49) — 기본 자리에서는 목록을 끌어내려야 나타나 없는 줄 알았다.
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "이름 · 별명 · 소속 · 초성")
        .task(id: people.count) { refold() }
        .onChange(of: searchText) { _, _ in refilter() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
