import Foundation

/// 글자를 다루기 전에 **한 모양**으로 맞춘다.
///
/// 한글은 iCloud · 키보드 · 붙여넣기를 거치며 NFD(자모 분리)로 올 수 있다.
/// 저장 · 비교 · 검색은 전부 NFC 로 한 뒤에 한다 (요구사항 7.2 · 5.3).
public enum TextNormalization {

    /// NFC 로 합치고 앞뒤 공백 · 줄바꿈을 지운다. **저장 전에 한 번** 거친다.
    public static func normalized(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 비교 · 검색용 열쇠. `normalized` 에 소문자를 더한다.
    /// 대소문자를 가리지 않는 것이 요구사항(5.3)이고, 한글은 그대로다.
    public static func folded(_ text: String) -> String {
        normalized(text).lowercased()
    }

    /// 안쪽의 연속 공백을 빈칸 하나로. 태그(`a   b` → `a b`)에 쓴다.
    public static func collapsedSpaces(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// 비어 있으면 `nil`. 선택 입력 칸을 저장할 때 빈 문자열 대신 `nil` 을 넣는다.
    public static func nilIfEmpty(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = normalized(text)
        return cleaned.isEmpty ? nil : cleaned
    }
}
