import Core

/// 사람 고르기 화면의 검색 — 이름 · 별명 · 소속을 미리 접어 둔다. 초성으로도 찾는다(`ㄱㅎㄴ` → 김하늘 · FR-036).
/// 사람 수가 바뀔 때 한 번 만들고 검색어가 바뀔 때만 견준다 — 본문에서 전원을 접지 않는다 (전수조사 이슈 18).
struct PickerSearchKey {
    private let fields: [FoldedText]

    init(_ person: Person) {
        fields = [person.name, person.nickname ?? "", person.organization ?? ""]
            .filter { !$0.isEmpty }
            .map { FoldedText($0) }
    }

    /// `key` 는 `TextNormalization.folded` 를 거친 검색어.
    func matches(_ key: String) -> Bool {
        fields.contains { $0.contains(key) }
    }
}
