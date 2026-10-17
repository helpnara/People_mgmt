import Foundation

/// 검색어 한 줄을 낱말로 가른다 (요구사항 5.3).
///
/// - 빈칸으로 나눈 낱말이 **모두**(AND) 어딘가에 있어야 한다. 낱말마다 다른 칸이어도 된다.
/// - `#멘토` 처럼 `#` 을 붙이면 태그만 본다. 안 붙이면 태그를 포함한 모든 칸을 본다.
/// - 비교는 `TextNormalization.folded` 열쇠로 — NFC · 소문자.
public struct SearchQuery: Equatable, Sendable {

    public struct Term: Equatable, Sendable {
        public let text: String
        public let tagOnly: Bool

        public init(text: String, tagOnly: Bool) {
            self.text = text
            self.tagOnly = tagOnly
        }
    }

    public let terms: [Term]

    public init(parsing raw: String) {
        var terms: [Term] = []
        for word in raw.split(whereSeparator: { $0.isWhitespace }) {
            var body = String(word)
            var tagOnly = false
            if body.hasPrefix("#") {
                tagOnly = true
                body.removeFirst()
            }
            let folded = TextNormalization.folded(body)
            guard !folded.isEmpty else { continue }
            terms.append(Term(text: folded, tagOnly: tagOnly))
        }
        self.terms = terms
    }

    public var isEmpty: Bool { terms.isEmpty }
}
