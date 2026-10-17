import SwiftUI
import UIKit

extension Font {
    /// **글자 크기 설정을 따르는 서체.** 글꼴 크기를 숫자로 못 박지 않는다 (느린 부자 교훈 8 — 275곳을 나중에 고쳤다).
    ///
    /// 설계 크기가 기준이고 사용자의 설정 배율을 곱한다. 접근성 다섯 단계(최대 3.1배)는
    /// xxxLarge 에서 멈춘다 — 그 위는 칩 · 표가 못 받는다. 애플도 xxxLarge 까지를 기본 요구로 본다.
    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let user = UIFontMetrics.default.scaledValue(for: size)
        let cap = UIFontMetrics.default.scaledValue(for: size, compatibleWith: capTraits)
        return .system(size: min(user, cap), weight: weight)
    }

    /// 글자에 맞춰 커져야 하는 **길이** (칩 높이 · 아이콘 자리). `scaled` 와 같은 배율, 같은 상한.
    static func scaledLength(_ length: CGFloat) -> CGFloat {
        let user = UIFontMetrics.default.scaledValue(for: length)
        let cap = UIFontMetrics.default.scaledValue(for: length, compatibleWith: capTraits)
        return min(user, cap)
    }

    private static let capTraits = UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)
}
