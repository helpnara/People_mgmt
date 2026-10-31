import Foundation

/// **초성 검색** (FR-036 · 2026-10-20 사용자 — 모든 검색 칸에서).
///
/// - 검색어 글자 가운데 **자음(ㄱ~ㅎ)** 은 그 자리 한글 음절의 **첫소리**와 견준다. `ㄱㅎㄴ` 으로 `김하늘` 을 찾는다.
/// - 자음이 아닌 글자는 지금처럼 그대로 견준다 — 섞어 써도 된다. `김ㅎ` 은 `김하늘` 을 찾고 `고하늘` 은 찾지 않는다.
/// - 자음이 하나도 없는 검색어는 지금과 똑같이 찾는다(부분 일치).
/// - 된소리는 따로 — `ㄱ` 은 `까` 를 찾지 않는다. 키보드가 치는 낱자(호환 자모 U+3131~314E)를 자음으로 본다.
///
/// 비교하는 두 글은 모두 `TextNormalization.folded` 를 거친 것이다. 정답표 `chosung` · `search` 가 대조한다.
public enum Chosung {

    private static let initialConsonants: [Unicode.Scalar] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    static func isSyllable(_ scalar: Unicode.Scalar) -> Bool {
        (0xAC00...0xD7A3).contains(scalar.value)
    }

    /// 키보드로 친 자음 낱자인가.
    public static func isConsonant(_ scalar: Unicode.Scalar) -> Bool {
        (0x3131...0x314E).contains(scalar.value)
    }

    /// 글자마다 — 한글 음절은 첫소리 자음으로, 나머지는 그대로. 글자 수(유니코드 스칼라)가 바뀌지 않는다.
    public static func initials(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            out.append(initial(of: scalar))
        }
        return String(out)
    }

    static func initial(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        guard isSyllable(scalar) else { return scalar }
        return initialConsonants[Int(scalar.value - 0xAC00) / 588]
    }

    /// 검색어에 자음 낱자가 있는가 — 없으면 초성 비교를 하지 않는다.
    public static func hasConsonant(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isConsonant)
    }

    /// `folded` 안에 `term` 이 있는가 (둘 다 접은 글). 초성 규칙은 위.
    public static func contains(_ folded: String, term: String) -> Bool {
        FoldedText(folded: folded).contains(term)
    }
}

/// 검색용으로 **미리 접어 둔** 글 하나 — 접은 글과 그 초성 글. 검색할 때마다 초성을 다시 만들지 않는다 (이슈 6 과 같은 까닭).
public struct FoldedText: Sendable, Equatable {
    public let folded: String
    /// 한글 음절이 없으면 `nil` — 접은 글과 같다.
    let initials: String?

    public init(folded: String) {
        self.folded = folded
        initials = folded.unicodeScalars.contains(where: Chosung.isSyllable) ? Chosung.initials(folded) : nil
    }

    public init(_ raw: String) {
        self.init(folded: TextNormalization.folded(raw))
    }

    /// 접은 검색어 `term` 이 들어 있는가.
    public func contains(_ term: String) -> Bool {
        guard Chosung.hasConsonant(term) else { return folded.contains(term) }
        let pool = initials ?? folded
        // 자리마다 초성으로 바꾼 검색어가 초성 글 안에 없으면 맞을 수 없다 — 대부분 여기서 끝난다.
        guard pool.contains(Chosung.initials(term)) else { return false }
        let wanted = Array(term.unicodeScalars)
        // 자음만이면 초성 글에서 찾은 것이 곧 답이다.
        if wanted.allSatisfy(Chosung.isConsonant) { return true }
        let text = Array(folded.unicodeScalars)
        let firsts = Array(pool.unicodeScalars)
        guard wanted.count <= text.count, text.count == firsts.count else { return false }
        for start in 0...(text.count - wanted.count) {
            var matched = true
            for (k, scalar) in wanted.enumerated() {
                let same = Chosung.isConsonant(scalar) ? firsts[start + k] == scalar : text[start + k] == scalar
                if !same {
                    matched = false
                    break
                }
            }
            if matched { return true }
        }
        return false
    }
}
