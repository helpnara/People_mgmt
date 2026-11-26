import Foundation

/// **명함 읽기 시험의 가린 복사** (이슈 127 · 2026-11-26 사용자) — 실제 명함의 이름 · 번호 · 메일을 대화에 붙이지 않고도
/// 왜 틀렸는지 볼 수 있게, 글자의 **모양만** 남긴다.
///
/// - 숫자 → `#` · 영문 → `x`(대문자는 `X`) · 한글 → `○` · 한자 · 가나 → `◇`
/// - 번호의 앞자리는 남긴다 — `0` 으로 시작하는 세 자리 이하 숫자 덩어리(`010` · `02` · `031`)와 `+82`. 휴대전화 · 사무실을 가르는 모양이다
/// - **읽기 규칙이 보는 낱말은 남긴다** — 직무(`팀장` · `Manager`) · 회사(`주식회사` · `Inc`) · 연락 이름표(`휴대폰` · `Tel` · `E`) ·
///   흔한 메일 도메인 · 부서 끝(`…팀`). 그래서 `Tools/card-reading/from_paste.py` 가 `#` → `5`, `○` → `가` 로 되돌려
///   `BusinessCardParser` 와 같은 규칙을 다시 돌릴 수 있다.
/// - 기호 · 빈칸 · 줄 모양은 그대로다 — `010-####-####` · `xxxx@xxxx.com` 처럼 틀린 모양이 남는다.
///
/// 규칙은 파이썬 정답표 `Tools/golden/generate.py` 의 `card_mask` 와 글자 하나 다르지 않아야 한다.
public enum CardMasking {

    /// 남기는 한글 낱말 — **긴 것부터** 찾는다(같은 길이는 이 차례대로). 파이썬과 같은 차례로 적어 둔다.
    static let hangulKeep: [String] = [
        "대표이사", "주식회사", "유한회사", "휴대전화", "엔지니어", "컨설턴트", "디자이너", "홈페이지",
        "부사장", "본부장", "센터장", "연구원", "매니저", "개발자", "대학교", "연구소", "휴대폰", "핸드폰", "모바일", "이메일", "사무실",
        "대표", "회장", "사장", "전무", "상무", "이사", "실장", "부장", "차장", "과장", "팀장", "대리", "주임", "사원", "책임", "선임",
        "수석", "교수", "원장", "재단", "협회", "병원", "은행", "그룹", "휴대", "전화", "팩스", "메일", "직통", "직장", "회사", "주소",
    ]

    /// 남기는 영문 낱말 — 영문자 덩어리 하나가 통째로(소문자로) 이 안에 있을 때만.
    static let latinKeep: Set<String> = [
        "ceo", "cto", "cfo", "coo", "director", "manager", "engineer", "designer", "developer", "consultant", "president",
        "founder", "professor", "lead",
        "inc", "corp", "co", "ltd", "llc", "company", "university", "labs", "lab",
        "m", "t", "f", "e", "o", "p", "h", "hp", "tel", "phone", "mobile", "cell", "fax", "email", "mail", "office", "direct",
        "main", "dir", "www", "http", "https",
        "com", "net", "org", "kr", "io", "gmail", "naver", "daum", "hanmail", "kakao", "nate",
    ]

    static let digitMark: Unicode.Scalar = "#"
    static let upperMark: Unicode.Scalar = "X"
    static let lowerMark: Unicode.Scalar = "x"
    static let hangulMark: Unicode.Scalar = "○"
    static let otherMark: Unicode.Scalar = "◇"
    static let zero: Unicode.Scalar = "0"
    static let plus: Unicode.Scalar = "+"
    static let countryCode: [Unicode.Scalar] = ["8", "2"]

    public static func mask(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let value = scalars[index].value
            if isHangulSyllable(value) {
                var end = index
                while end < scalars.count, isHangulSyllable(scalars[end].value) { end += 1 }
                out.append(contentsOf: maskHangul(Array(scalars[index..<end])))
                index = end
            } else if isLatinLetter(value) {
                var end = index
                while end < scalars.count, isLatinLetter(scalars[end].value) { end += 1 }
                let run = Array(scalars[index..<end])
                let word = String(String.UnicodeScalarView(run)).lowercased()
                if latinKeep.contains(word) {
                    out.append(contentsOf: run)
                } else {
                    let masked: [Unicode.Scalar] = run.map { (0x41...0x5A).contains($0.value) ? upperMark : lowerMark }
                    out.append(contentsOf: masked)
                }
                index = end
            } else if isDigit(value) {
                var end = index
                while end < scalars.count, isDigit(scalars[end].value) { end += 1 }
                let run = Array(scalars[index..<end])
                // 번호의 앞자리(`010` · `02` · `031` · `+82`)는 남긴다 — 휴대전화 · 사무실을 가르는 모양이고 누구인지는 드러내지 않는다.
                let isPrefix = run.first == zero && run.count <= 3
                let isCountry = run == countryCode && index > 0 && scalars[index - 1] == plus
                let masked: [Unicode.Scalar] = isPrefix || isCountry ? run : run.map { _ in digitMark }
                out.append(contentsOf: masked)
                index = end
            } else if isHangulJamo(value) {
                out.append(hangulMark)
                index += 1
            } else if isIdeographOrKana(value) {
                out.append(otherMark)
                index += 1
            } else {
                out.append(scalars[index])
                index += 1
            }
        }
        return String(out)
    }

    /// 한글 덩어리 하나 — 남길 낱말 자리만 두고 나머지는 `○`.
    static func maskHangul(_ run: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var keep = Array(repeating: false, count: run.count)
        for keyword in hangulKeep {
            let word = Array(keyword.unicodeScalars)
            var start = 0
            while start + word.count <= run.count {
                guard let found = firstIndex(of: word, in: run, from: start) else { break }
                if keep[found..<found + word.count].contains(true) {
                    start = found + 1
                } else {
                    for position in found..<found + word.count { keep[position] = true }
                    start = found + word.count
                }
            }
        }
        // 부서 끝(`개발팀` 의 `팀`) — 덩어리가 그 끝보다 길 때만.
        for suffix in BusinessCardParser.departmentSuffixes {
            let word = Array(suffix.unicodeScalars)
            if run.count > word.count, Array(run.suffix(word.count)) == word {
                for position in (run.count - word.count)..<run.count { keep[position] = true }
            }
        }
        return run.indices.map { keep[$0] ? run[$0] : hangulMark }
    }

    static func firstIndex(of word: [Unicode.Scalar], in run: [Unicode.Scalar], from start: Int) -> Int? {
        guard !word.isEmpty, run.count >= word.count, start <= run.count - word.count else { return nil }
        for position in start...(run.count - word.count) where Array(run[position..<position + word.count]) == word {
            return position
        }
        return nil
    }

    static func isDigit(_ value: UInt32) -> Bool { (0x30...0x39).contains(value) }
    static func isHangulSyllable(_ value: UInt32) -> Bool { (0xAC00...0xD7A3).contains(value) }
    static func isHangulJamo(_ value: UInt32) -> Bool { (0x3131...0x318E).contains(value) || (0x1100...0x11FF).contains(value) }
    static func isLatinLetter(_ value: UInt32) -> Bool { (0x41...0x5A).contains(value) || (0x61...0x7A).contains(value) }
    static func isIdeographOrKana(_ value: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value) || (0x3040...0x30FF).contains(value)
    }
}
