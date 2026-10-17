import Foundation

/// 한글 조사 — 받침 유무로 `을/를` · `과/와` · `이/가` 를 고른다.
///
/// 삭제 확인 문구(`'홍길동'을 삭제`, `'김하늘'과 기록 3건`)에 쓴다. 받침을 못 가리는
/// 글자(영문 · 숫자 · 기호)로 끝나면 `을(를)` 처럼 둘 다 적는다 — 틀린 조사보다 낫다.
/// 느린 부자에서 앱 이름을 바꾸다 `느린 부자은` 이 스토어 설명에 나간 적이 있다.
public enum Josa {

    /// 마지막 글자가 한글 음절이면 받침이 있는지. 한글이 아니면 `nil`.
    public static func hasFinalConsonant(_ text: String) -> Bool? {
        guard let scalar = text.unicodeScalars.last(where: { !$0.properties.isWhitespace }) else { return nil }
        let value = scalar.value
        guard (0xAC00...0xD7A3).contains(value) else { return nil }
        return (value - 0xAC00) % 28 != 0
    }

    public static func eulReul(_ text: String) -> String {
        switch hasFinalConsonant(text) {
        case true?: return "을"
        case false?: return "를"
        case nil: return "을(를)"
        }
    }

    public static func gwaWa(_ text: String) -> String {
        switch hasFinalConsonant(text) {
        case true?: return "과"
        case false?: return "와"
        case nil: return "과(와)"
        }
    }

    public static func iGa(_ text: String) -> String {
        switch hasFinalConsonant(text) {
        case true?: return "이"
        case false?: return "가"
        case nil: return "이(가)"
        }
    }
}
