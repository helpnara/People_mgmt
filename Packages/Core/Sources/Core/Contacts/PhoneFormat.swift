import Foundation

/// **전화번호를 한 모양으로** (이슈 139 · 2026-11-27 사용자 — 보여 주기 + 새로 저장 · `+82` 는 국내 모양).
///
/// - 국내: `010-5555-0101` · `02-555-0100` · `031-555-0100` · `0505-555-0100` · `1588-0000`
/// - `+82` 가 붙은 한국 번호는 국내 모양으로(`+82 (0)2-…` · `(+82 10) …` 도)
/// - 다른 나라: `+65 9555 0101` 처럼 국가번호 + 빈칸(구분 기호만 빈칸 하나로)
/// - 숫자 · `+` · 빈칸 · `-` · `.` · 괄호 말고 다른 글자가 있거나(내선 · `~3`) 길이를 모르면 **손대지 않는다**(앞뒤 빈칸만 뗌)
///
/// 파이썬 정답표 `Tools/golden/generate.py` 의 `phone_format` 과 글자 하나 다르지 않아야 한다.
public enum PhoneFormat {

    static let allowed: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", " ", "-", ".", "(", ")"]
    static let separatorPattern = #"[\s.()-]+"#

    public static func normalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        guard !trimmed.isEmpty, trimmed.allSatisfy({ allowed.contains($0) }) else { return trimmed }
        var digits = String(trimmed.filter { $0.isASCII && $0.isNumber })
        let head = String(trimmed.drop { $0 == "(" })
        let shape: [Int]
        if head.hasPrefix("+") {
            if digits.hasPrefix("82") {
                var rest = String(digits.dropFirst(2))
                if !rest.hasPrefix("0") { rest = "0" + rest }
                guard let found = domesticShape(rest) else { return trimmed }
                digits = rest
                shape = found
            } else {
                let body = String(head.dropFirst())
                if body.contains("+") { return trimmed }
                let spaced = BusinessCardParser.replacing(separatorPattern, in: body, with: " ")
                return "+" + spaced.trimmingCharacters(in: CharacterSet(charactersIn: " "))
            }
        } else {
            if trimmed.contains("+") { return trimmed }
            guard let found = domesticShape(digits) else { return trimmed }
            shape = found
        }
        var parts: [String] = []
        var rest = Substring(digits)
        for size in shape {
            parts.append(String(rest.prefix(size)))
            rest = rest.dropFirst(size)
        }
        return parts.joined(separator: "-")
    }

    /// 국내 번호 숫자 → 덩어리 길이. 모르는 길이면 nil.
    static func domesticShape(_ digits: String) -> [Int]? {
        let count = digits.count
        if digits.hasPrefix("02") {
            return count == 9 ? [2, 3, 4] : count == 10 ? [2, 4, 4] : nil
        }
        if digits.hasPrefix("050") {
            return count == 11 ? [4, 3, 4] : count == 12 ? [4, 4, 4] : nil
        }
        if digits.hasPrefix("0") {
            return count == 10 ? [3, 3, 4] : count == 11 ? [3, 4, 4] : nil
        }
        if digits.hasPrefix("15") || digits.hasPrefix("16") || digits.hasPrefix("18") {
            return count == 8 ? [4, 4] : nil
        }
        return nil
    }
}
