import Foundation

/// 연락처의 성 · 이름을 한 칸으로 (FR-015).
///
/// 한글 · 한자 이름은 성 + 이름을 붙여 쓰고(`김` + `하늘` → `김하늘`), 그 밖에는 이름 + 빈칸 + 성
/// (`Alice` + `Park` → `Alice Park`). 한쪽이 비면 다른 쪽만.
public enum ContactName {

    public static func compose(given: String, family: String) -> String {
        let g = TextNormalization.collapsedSpaces(TextNormalization.normalized(given))
        let f = TextNormalization.collapsedSpaces(TextNormalization.normalized(family))
        if g.isEmpty { return f }
        if f.isEmpty { return g }
        if isEastAsian(f) && isEastAsian(g) { return f + g }
        return g + " " + f
    }

    /// 한글 음절 · 한자로만 되어 있는가 (빈칸 제외).
    static func isEastAsian(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return false }
        return scalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }
}

/// 전화 · 메일을 연락 수단 메모 한 칸으로 (FR-032). 같은 것은 한 번만, ` · ` 로 잇고 500자에서 자른다.
public enum ContactNote {
    public static func compose(phones: [String], emails: [String]) -> String {
        var seen = Set<String>()
        var parts: [String] = []
        for raw in phones + emails {
            let item = TextNormalization.collapsedSpaces(TextNormalization.normalized(raw))
            guard !item.isEmpty, !seen.contains(item) else { continue }
            seen.insert(item)
            parts.append(item)
        }
        return String(parts.joined(separator: " · ").prefix(Limits.contactNote))
    }
}
