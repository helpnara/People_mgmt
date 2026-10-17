import Foundation

/// 제목이 없는 기록을 목록에 보여 줄 이름 (요구사항 6.2 `displayTitle`).
///
/// 제목이 있으면 제목. 없으면 메모의 **첫 줄**을 40자까지. 둘 다 없는 기록은
/// 저장되지 않으므로(제목 또는 메모 중 하나 필수) 마지막 분기는 안전망이다.
public enum DisplayTitle {
    public static let maxLength = 40
    public static let fallback = "(내용 없음)"

    public static func make(title: String?, note: String?) -> String {
        if let title, case let cleaned = TextNormalization.normalized(title), !cleaned.isEmpty {
            return cleaned
        }
        if let note {
            for rawLine in note.precomposedStringWithCanonicalMapping.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { continue }
                if line.count > maxLength {
                    return String(line.prefix(maxLength)) + "…"
                }
                return line
            }
        }
        return fallback
    }
}
