import Foundation

/// 명함에서 읽은 한 줄 — 글자와, 명함 높이에 대한 그 줄의 높이(0~1). 큰 글자가 대개 이름이다.
public struct CardLine: Sendable, Equatable {
    public let text: String
    public let height: Double

    public init(text: String, height: Double) {
        self.text = text
        self.height = height
    }
}

/// 명함 글자에서 고른 **제안** (FR-050). 앱은 이것을 그대로 넣지 않고 사용자에게 보여 고르게 한다.
public struct CardSuggestion: Sendable, Equatable {
    public var name: String?
    public var organization: String?
    public var role: String?
    public var phones: [String]
    public var emails: [String]
    /// 정리한 모든 줄 (위에서 아래 순서). 제안이 틀렸을 때 사용자가 직접 고르는 재료다.
    public var lines: [String]

    public var hasSuggestion: Bool {
        name != nil || organization != nil || role != nil || !phones.isEmpty || !emails.isEmpty
    }
}

/// 명함 글자를 이름 · 소속 · 직무 · 전화 · 메일로 가른다. **기기 안에서만** 돈다 — 네트워크가 없다.
///
/// 규칙은 단순하고 결정적이다 (파이썬 정답표 `Tools/golden/generate.py` 가 같은 규칙으로 대조한다).
/// 한 줄씩 차례로 본다:
/// 1. 메일 · 전화 · 웹 주소가 있으면 **연락 줄** — 메일 · 전화를 뽑는다. `Fax` · `팩스` · `F` 로 시작하는 줄의 전화는 뺀다
/// 2. 소속 낱말(주식회사 · ㈜ · 대학교 · Inc …)이 있으면 **소속** (처음 것)
/// 3. `한글이름 직무` 꼴이면 이름 후보 + 직무
/// 4. 직무 낱말(팀장 · 대표 · Engineer …)로 끝나는 낱말이 있으면 **직무** (처음 것)
/// 5. 한글 2~4음절(띄어 쓴 한 글자씩도) 또는 `Alice Park` 꼴이면 **이름 후보**
/// 이름 후보가 여럿이면 **글자가 가장 큰 줄**, 같으면 먼저 나온 줄.
public enum BusinessCardParser {

    static let roleKeywords = [
        "대표이사", "대표", "회장", "사장", "부사장", "전무", "상무", "이사", "본부장", "실장", "센터장",
        "부장", "차장", "과장", "팀장", "대리", "주임", "사원", "책임", "선임", "수석", "연구원", "교수",
        "원장", "매니저", "디자이너", "개발자", "엔지니어", "컨설턴트",
        "ceo", "cto", "cfo", "coo", "director", "manager", "engineer", "designer", "developer",
        "consultant", "president", "founder", "professor", "lead",
    ]
    static let koreanOrgKeywords = ["주식회사", "(주)", "㈜", "유한회사", "재단", "협회", "대학교", "병원", "연구소", "은행", "그룹"]
    static let latinOrgKeywords: Set<String> = ["inc", "corp", "co", "ltd", "llc", "company", "university", "labs", "lab"]
    /// 부서 이름 끝 — `개발팀` 을 사람 이름으로 보지 않으려고.
    static let departmentSuffixes = ["팀", "부", "실", "과", "처", "국", "센터", "본부", "그룹"]

    static let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    static let phonePattern = #"(?:\+82[\s.-]?)?\(?0?\d{1,2}\)?[\s.-]?\d{3,4}[\s.-]?\d{4}"#
    static let latinNamePattern = #"^[A-Z][A-Za-z'-]+(?: [A-Z][A-Za-z'-]+){1,2}$"#

    public static func parse(_ raw: [CardLine]) -> CardSuggestion {
        var suggestion = CardSuggestion(name: nil, organization: nil, role: nil, phones: [], emails: [], lines: [])
        var nameCandidate: (text: String, height: Double)?

        func offer(name: String, height: Double) {
            if let current = nameCandidate, current.height >= height { return }
            nameCandidate = (name, height)
        }

        for line in raw {
            let text = TextNormalization.collapsedSpaces(TextNormalization.normalized(line.text))
            guard !text.isEmpty else { continue }
            suggestion.lines.append(text)
            let lower = text.lowercased()

            // 1. 연락 줄
            let emails = matches(emailPattern, in: text)
            let phones = matches(phonePattern, in: text)
            if !emails.isEmpty || !phones.isEmpty || lower.contains("www.") || lower.contains("http") {
                for email in emails.map({ $0.lowercased() }) where !suggestion.emails.contains(email) {
                    suggestion.emails.append(email)
                }
                if !isFaxLine(lower) {
                    for phone in phones.map({ $0.trimmingCharacters(in: .whitespaces) }) where !suggestion.phones.contains(phone) {
                        suggestion.phones.append(phone)
                    }
                }
                continue
            }

            // 2. 소속
            if isOrganization(text) {
                if suggestion.organization == nil { suggestion.organization = text }
                continue
            }

            // 3. 한글이름 + 직무
            let tokens = text.split(separator: " ").map(String.init)
            if tokens.count >= 2, isHangulName(tokens[0]), tokens.dropFirst().contains(where: isRoleToken) {
                offer(name: tokens[0], height: line.height)
                if suggestion.role == nil { suggestion.role = tokens.dropFirst().joined(separator: " ") }
                continue
            }

            // 4. 직무
            if tokens.contains(where: isRoleToken) {
                if suggestion.role == nil { suggestion.role = text }
                continue
            }

            // 5. 이름 후보
            if isHangulName(text) {
                offer(name: text.replacingOccurrences(of: " ", with: ""), height: line.height)
            } else if !matches(latinNamePattern, in: text).isEmpty {
                offer(name: text, height: line.height)
            }
        }
        suggestion.name = nameCandidate?.text
        return suggestion
    }

    // MARK: - 판정

    static func isFaxLine(_ lower: String) -> Bool {
        lower.hasPrefix("fax") || lower.hasPrefix("팩스") || lower.hasPrefix("f.") || lower.hasPrefix("f ")
    }

    static func latinLetters(_ token: String) -> String {
        String(token.filter { $0.isASCII && $0.isLetter }).lowercased()
    }

    static func isOrganization(_ text: String) -> Bool {
        if koreanOrgKeywords.contains(where: { text.contains($0) }) { return true }
        return text.split(separator: " ").contains { latinOrgKeywords.contains(latinLetters(String($0))) }
    }

    static func isRoleToken(_ token: String) -> Bool {
        let latin = latinLetters(token)
        for keyword in roleKeywords {
            if keyword.unicodeScalars.first.map({ $0.isASCII }) == true {
                if latin == keyword { return true }
            } else if token.hasSuffix(keyword) {
                return true
            }
        }
        return false
    }

    /// 한글 2~4음절 — 한 낱말이거나, 한 글자씩 띄어 쓴 것(`김 하 늘`). 부서 이름 끝(`팀` · `부` …)은 뺀다.
    static func isHangulName(_ text: String) -> Bool {
        let tokens = text.split(separator: " ")
        guard tokens.count == 1 || tokens.allSatisfy({ $0.count == 1 }) else { return false }
        let joined = tokens.joined()
        guard (2...4).contains(joined.count) else { return false }
        guard joined.unicodeScalars.allSatisfy({ (0xAC00...0xD7A3).contains($0.value) }) else { return false }
        return !departmentSuffixes.contains { joined.hasSuffix($0) }
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
