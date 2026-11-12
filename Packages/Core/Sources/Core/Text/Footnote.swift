import Foundation

/// **긴 설명은 첫 문장만** (1.1.11 · 이슈 111 · 디자인은 늘 고급스럽게) — 화면 아래의 설명을 첫 문장과 나머지로 나눈다.
/// 화면은 첫 문장만 보이고 `자세히` 를 누르면 나머지를 편다(`FootnoteText`). 문장 끝은 마침표 다음에 빈칸 · 줄바꿈이 오는 곳 —
/// 숫자 바로 뒤 마침표(`3.` · `1.5`)는 끝으로 보지 않는다. 파이썬 정답표(`Tools/golden` 의 `footnoteSplit`)와 같은 셈이다.
public enum Footnote {
    public static func split(_ text: String) -> (head: String, rest: String) {
        let chars = Array(text)
        var i = 1
        while i < chars.count - 1 {
            if chars[i] == ".", chars[i + 1].isWhitespace, !isDigit(chars[i - 1]) {
                let head = String(chars[0...i]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rest = String(chars[(i + 1)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (head, rest)
            }
            i += 1
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }

    private static func isDigit(_ c: Character) -> Bool {
        c.isASCII && c.isNumber
    }
}
