import Foundation

/// 태그 규칙 (요구사항 7.2).
///
/// - 앞뒤 공백 제거, 선행 `#` 제거, 안쪽 연속 공백은 빈칸 하나, 1~30자
/// - 목록은 대소문자를 무시하고 중복을 지우며 최대 20개
///
/// `#멘토`, `멘토 `, `멘토` 는 **하나의 태그**다 (수용 기준 AC-18).
public enum TagNormalizer {
    public static let maxLength = 30
    public static let maxCount = 20

    /// 태그 하나를 정리한다. 빈 것 · 30자를 넘는 것은 `nil`.
    public static func normalize(_ raw: String) -> String? {
        var text = TextNormalization.normalized(raw)
        while text.hasPrefix("#") { text.removeFirst() }
        text = TextNormalization.collapsedSpaces(text)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxLength else { return nil }
        return text
    }

    /// 같은 태그인지 가르는 열쇠 — 정리한 뒤 소문자. 태그가 될 수 없으면 `nil`. 목록 정리 · 태그 모음 · 거르기가 이것 하나로 견준다.
    public static func key(_ raw: String) -> String? {
        normalize(raw)?.lowercased()
    }

    /// 목록을 정리한다. 먼저 나온 표기를 남기고(`Mentor` 뒤의 `mentor` 는 버림) 20개에서 자른다.
    public static func normalizeList(_ raws: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in raws {
            guard let tag = normalize(raw), let key = Self.key(tag) else { continue }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(tag)
            if result.count >= maxCount { break }
        }
        return result
    }

    /// 한 칸에 `회사, 멘토` 처럼 여러 개를 적었을 때 가른다. 쉼표 · 세미콜론 · 줄바꿈이 경계다.
    public static func split(_ input: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        return input.components(separatedBy: separators)
    }

    /// 가르고 정리까지. 입력 칸에서 바로 부른다.
    public static func parse(_ input: String) -> [String] {
        normalizeList(split(input))
    }
}
