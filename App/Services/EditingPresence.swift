import SwiftUI

/// **입력 창이 열려 있는가** (이슈 77 · 2026-11-04 사용자 — 아이폰에서 기록 편집 중 가로로 돌리자 편집 창이 닫혔다).
///
/// 뿌리 화면(`PeopleListView`)은 넓은 폭이면 칸 나누기, 좁은 폭이면 스택 하나로 **화면 뼈대를 통째로 바꾼다**. 뼈대가 바뀌면
/// 그 안의 화면(사람 상세 · 기록 상세 · 채울 사람 목록)이 띄운 창도 함께 내려가 적던 내용이 사라진다.
/// 아이폰은 뼈대를 바꾸지 않게 했고(`PeopleListView.splitsByWidth`), 아이패드는 화면 나누기로 폭이 바뀔 수 있어
/// **입력 창이 열린 동안에는 뼈대를 그대로 둔다** — 닫힌 뒤에 새 폭을 따른다.
///
/// 입력 창은 `.holdsLayout()` 을 붙인다(기록 · 사람 편집 · vCard 가져오기). 열린 창마다 표를 하나씩 들고 있어
/// 창이 겹쳐 열리고 닫혀도 셈이 어긋나지 않는다.
@MainActor
@Observable
final class EditingPresence {
    static let shared = EditingPresence()

    private var tokens: Set<UUID> = []

    /// 입력 창이 하나라도 열려 있다.
    var isEditing: Bool { !tokens.isEmpty }

    func enter(_ token: UUID) { tokens.insert(token) }
    func leave(_ token: UUID) { tokens.remove(token) }
}

private struct HoldsLayout: ViewModifier {
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { EditingPresence.shared.enter(token) }
            .onDisappear { EditingPresence.shared.leave(token) }
    }
}

extension View {
    /// 이 창이 열린 동안 뿌리 화면의 뼈대(칸 나누기 ↔ 스택)를 바꾸지 않는다 (이슈 77).
    func holdsLayout() -> some View { modifier(HoldsLayout()) }
}
