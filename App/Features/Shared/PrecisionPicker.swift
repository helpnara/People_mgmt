import Core
import SwiftUI

/// 날짜의 정밀도 고르기 (FR-033) — 날짜까지 · 월까지 · 연도만. 바로 아래 날짜 칸(`ApproxDateField`)이 고른 정밀도의
/// 고르개(달력 · 열두 달 · 열두 해)를 띄우고, 저장했을 때 보일 글 그대로 값을 보인다 (빌드 39 · 이슈 60).
struct PrecisionPicker: View {
    @Binding var selection: DatePrecision

    var body: some View {
        Picker("정밀도", selection: $selection) {
            ForEach(DatePrecision.allCases) { precision in
                Text(precision.label).tag(precision)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("날짜를 얼마나 정확히 아나요")
        .padding(.vertical, 2)
    }
}
