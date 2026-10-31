import SwiftUI
import UIKit

extension Font {
    /// **글자 크기 설정을 따르는 서체.** 글꼴 크기를 숫자로 못 박지 않는다 (느린 부자 교훈 8 — 275곳을 나중에 고쳤다).
    ///
    /// 설계 크기가 기준이고 사용자의 설정 배율을 곱한다. **접근성 다섯 단계(AX1~AX5, 최대 3.1배)까지 따른다** (D-33 · 요구사항 8.6).
    /// 빌드 13 까지는 xxxLarge 에서 멈췄다 — 넘치는 칩 · 표는 줄바꿈(`Chip` · `WrapLayout`)과 세로 배치(`AdaptiveStack`)로 받는다.
    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight)
    }

    /// 글자에 맞춰 커져야 하는 **길이** (칩 높이 · 아이콘 자리 · 누르는 자리). `scaled` 와 같은 배율.
    static func scaledLength(_ length: CGFloat) -> CGFloat {
        UIFontMetrics.default.scaledValue(for: length)
    }

    /// **관계도 그림 안의 이름처럼 좁은 자리에 겹쳐 그리는 글자** — xxxLarge 에서 멈춘다. 점 수백 개 옆의 이름이 세 배로
    /// 커지면 서로 덮어 아무것도 못 읽는다. 같은 정보는 목록(특성 · 돌아보기 · 누른 사람 칸)에서 큰 글씨로 읽힌다.
    static func scaledCapped(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let user = UIFontMetrics.default.scaledValue(for: size)
        let cap = UIFontMetrics.default.scaledValue(for: size, compatibleWith: capTraits)
        return .system(size: min(user, cap), weight: weight)
    }

    private static let capTraits = UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)
}

/// 옆으로 놓던 것을 **큰 글씨(접근성 크기)에서는 아래로** (D-33). 이름 옆의 날짜 · 막대 옆의 수처럼 둘이 한 줄에 서는 자리.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: spacing))
        layout { content }
    }
}

private struct ReadableLineLimit: ViewModifier {
    let lines: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content.lineLimit(typeSize.isAccessibilitySize ? lines * 3 : lines)
    }
}

extension View {
    /// 보통 크기에서는 `lines` 줄, 큰 글씨에서는 세 배까지 — 한 줄로 자르면 큰 글씨에서 몇 글자만 남는다 (D-33).
    func readableLineLimit(_ lines: Int) -> some View {
        modifier(ReadableLineLimit(lines: lines))
    }
}
