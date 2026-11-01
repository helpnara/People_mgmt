import SwiftUI

/// **날짜 고르개 — 날을 누르면 달력이 바로 닫힌다** (빌드 39 · 1.1 · 2026-11-01 사용자).
///
/// 기본 날짜 고르개(작은 꼴)는 날을 골라도 달력이 떠 있고, 바깥을 눌러야 닫히며 값이 들어간 것처럼 보였다.
/// 고른 **날**이 바뀌면 고르개를 새로 만들어(`id`) 떠 있던 달력을 닫는다. 달 넘기기 · 연월 고르기는 고른 날을 바꾸지
/// 않아 닫히지 않는다. 시각 고르개(돌림판)에는 쓰지 않는다 — 돌리는 동안 값이 바뀌어 매번 닫힌다.
struct DayPicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date

    init(_ title: LocalizedStringKey, selection: Binding<Date>) {
        self.title = title
        self._selection = selection
    }

    var body: some View {
        DatePicker(title, selection: $selection, displayedComponents: .date)
            .id(DayIndex.of(selection))
    }
}
