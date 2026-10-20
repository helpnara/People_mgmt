import Core
import Foundation

extension Date {
    /// 정밀도를 따른 보이는 글 (FR-033) — 월까지 `2021년 3월`, 연도만 `2019년`(`Core.ApproximateDate`), 날짜까지는 기기 형식 그대로.
    func shown(precision: Int, style: Date.FormatStyle.DateStyle) -> String {
        ApproximateDate.label(of: self, precision: .of(precision)) ?? formatted(date: style, time: .omitted)
    }
}
