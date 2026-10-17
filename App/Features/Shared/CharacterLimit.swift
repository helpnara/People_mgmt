import SwiftUI

extension View {
    /// 글자 수 제한 (요구사항 7.2). 넘는 입력은 그 자리에서 자른다.
    func limited(_ text: Binding<String>, to limit: Int) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > limit {
                text.wrappedValue = String(newValue.prefix(limit))
            }
        }
    }
}
