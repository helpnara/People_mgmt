import Core
import SwiftUI

/// 날짜의 정밀도 고르기 (FR-033) — 날짜까지 · 월까지 · 연도만. 월 · 연도를 고르면 저장했을 때 보일 글을 바로 아래에 쓴다.
/// 날짜 칸(DatePicker)은 그대로 두고, 저장할 때 `Core.ApproximateDate` 가 그달 1일 · 그해 1월 1일로 접는다.
struct PrecisionPicker: View {
    let date: Date
    @Binding var selection: DatePrecision

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("정밀도", selection: $selection) {
                ForEach(DatePrecision.allCases) { precision in
                    Text(precision.label).tag(precision)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("날짜를 얼마나 정확히 아나요")
            if selection != .day, let preview {
                Text("저장하면 이렇게 보입니다 — \(preview)")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.vertical, 2)
    }

    /// 저장했을 때 보일 글 — 저장 규칙과 같은 함수로 접어 본다.
    private var preview: String? {
        let stored = ApproximateDate.noon(of: date, precision: selection, calendar: .current)
        return ApproximateDate.label(of: stored, precision: selection)
    }
}
