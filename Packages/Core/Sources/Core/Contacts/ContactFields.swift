import Foundation

/// 연락 수단 다섯 칸 (FR-032 · 빌드 7 · 이슈 11) — 휴대전화 · 사무실 전화 · 팩스 · 이메일 · 기타.
///
/// 칸마다 **하나씩** 담는다. 같은 종류가 또 오면(휴대전화 둘) 기타로 간다. 같은 값은 한 번만.
/// 기타는 ` · ` 로 잇는다 — 빌드 4 · 5 의 한 칸(`contactNote`)과 같은 모양이다.
public struct ContactFields: Sendable, Equatable {
    public enum Kind: String, Sendable, CaseIterable {
        case mobile, office, fax, email, other
    }

    public var mobile: String
    public var office: String
    public var fax: String
    public var email: String
    public var other: String

    public init(mobile: String = "", office: String = "", fax: String = "", email: String = "", other: String = "") {
        self.mobile = mobile
        self.office = office
        self.fax = fax
        self.email = email
        self.other = other
    }

    public var isEmpty: Bool {
        mobile.isEmpty && office.isEmpty && fax.isEmpty && email.isEmpty && other.isEmpty
    }

    public subscript(kind: Kind) -> String {
        switch kind {
        case .mobile: return mobile
        case .office: return office
        case .fax: return fax
        case .email: return email
        case .other: return other
        }
    }

    /// 값 하나를 그 칸에. 이미 어디 있는 값이면 넣지 않는다. 칸이 차 있으면 기타로.
    public mutating func place(_ raw: String, as kind: Kind) {
        let value = TextNormalization.collapsedSpaces(TextNormalization.normalized(raw))
        guard !value.isEmpty, !contains(value) else { return }
        switch kind {
        case .mobile where mobile.isEmpty: mobile = value
        case .office where office.isEmpty: office = value
        case .fax where fax.isEmpty: fax = value
        case .email where email.isEmpty: email = value
        default: other = other.isEmpty ? value : other + " · " + value
        }
    }

    func contains(_ value: String) -> Bool {
        mobile == value || office == value || fax == value || email == value
            || other.components(separatedBy: " · ").contains(value)
    }
}

/// 전화 · 메일을 다섯 칸으로 가른다 (FR-032 · 이슈 11). **기기 안에서만** 돈다.
///
/// 규칙은 파이썬 정답표(`Tools/golden/generate.py` 의 `contact_*`)와 글자 하나 다르지 않아야 한다.
///
/// - **연락처** — 번호마다 붙은 이름표(휴대전화 · 직장 · 직장 팩스 …)로 가른다. 이름표가 없거나 `전화` 같은
///   두루뭉술한 것이면 번호 모양으로: `010` · `011` · `016~019` 로 시작하면 휴대전화, 아니면 사무실.
///   알 수 없는 이름표(`본가` 같은 사용자 이름표) · 집 · 기타는 기타로.
/// - **한 칸 글**(빌드 4 · 5 의 연락 수단 칸, 명함의 연락 줄) — `·` · 줄바꿈 · `,` · `;` · `|` 로 조각을 낸다.
///   조각 안의 번호 · 메일마다 바로 앞 글자를 이름표로 본다(`M.` · `T.` · `F.` · `E.` · `Fax` · `휴대폰` …).
///   **알아보지 못한 글자가 하나라도 있으면 그 조각을 통째로 기타에 둔다** — 나누다가 잃는 글이 없게.
public enum ContactSorter {

    /// 연락처의 번호 하나 — 이름표(시스템 이름표는 `_$!<Mobile>!$_` 꼴)와 번호.
    public struct LabeledValue: Sendable, Equatable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public static func fromContact(phones: [LabeledValue], emails: [String]) -> ContactFields {
        var fields = ContactFields()
        for phone in phones {
            let kind: ContactFields.Kind
            switch labelKind(labelKey(phone.label)) {
            case .none, .phone: kind = isMobile(phone.value) ? .mobile : .office
            case .kind(.email), .unknown: kind = .other
            case .kind(let other): kind = other
            }
            fields.place(phone.value, as: kind)
        }
        for email in emails {
            fields.place(email, as: .email)
        }
        return fields
    }

    public static func split(_ text: String) -> ContactFields {
        var fields = ContactFields()
        for token in tokens(text) {
            sort(token, into: &fields)
        }
        return fields
    }

    // MARK: - 조각

    /// 줄바꿈은 따로 본다 — Swift 는 `\r\n` 을 글자 하나로 세서 `"\n"` 과 같지 않다 (느린 여백 183).
    static let separators: Set<Character> = ["·", ",", ";", "|"]

    static func tokens(_ text: String) -> [String] {
        let normalized = TextNormalization.normalized(text)
        return normalized.split(whereSeparator: { separators.contains($0) || $0.isNewline })
            .map { TextNormalization.collapsedSpaces(String($0)) }
            .filter { !$0.isEmpty }
    }

    struct Found {
        let range: Range<String.Index>
        let isEmail: Bool
    }

    static func sort(_ token: String, into fields: inout ContactFields) {
        let found = findings(in: token)
        guard !found.isEmpty else {
            fields.place(token, as: .other)
            return
        }
        var placements: [(String, ContactFields.Kind)] = []
        var cursor = token.startIndex
        for item in found {
            let label = labelKey(String(token[cursor..<item.range.lowerBound]))
            let value = String(token[item.range])
            guard let kind = resolve(label: label, value: value, isEmail: item.isEmail) else {
                fields.place(token, as: .other)
                return
            }
            placements.append((value, kind))
            cursor = item.range.upperBound
        }
        guard labelKey(String(token[cursor...])).isEmpty else {
            fields.place(token, as: .other)
            return
        }
        for (value, kind) in placements {
            fields.place(value, as: kind)
        }
    }

    /// 메일과, 메일과 겹치지 않는 전화를 앞에서부터.
    static func findings(in token: String) -> [Found] {
        let emails = ranges(of: BusinessCardParser.emailPattern, in: token)
        let phones = ranges(of: BusinessCardParser.phonePattern, in: token)
            .filter { phone in !emails.contains { $0.overlaps(phone) } }
        return (emails.map { Found(range: $0, isEmail: true) } + phones.map { Found(range: $0, isEmail: false) })
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    static func resolve(label: String, value: String, isEmail: Bool) -> ContactFields.Kind? {
        let kind = labelKind(label)
        if isEmail {
            switch kind {
            case .none, .kind(.email): return .email
            default: return nil
            }
        }
        switch kind {
        case .none, .phone: return isMobile(value) ? .mobile : .office
        case .kind(.email), .unknown: return nil
        case .kind(let other): return other
        }
    }

    // MARK: - 이름표

    enum LabelKind: Equatable {
        /// 이름표가 없다.
        case none
        /// `전화` · `Tel` 처럼 종류를 말하지 않는 이름표 — 번호 모양으로 가른다.
        case phone
        case kind(ContactFields.Kind)
        /// 알 수 없는 이름표.
        case unknown
    }

    /// 글자(문자)만 남겨 소문자로 — `_$!<WorkFAX>!$_` → `workfax`, `H.P` → `hp`, `E-mail` → `email`.
    static func labelKey(_ label: String) -> String {
        String(label.lowercased().filter(\.isLetter))
    }

    static func labelKind(_ key: String) -> LabelKind {
        if key.isEmpty { return .none }
        func has(_ parts: [String]) -> Bool { parts.contains { key.contains($0) } }
        if key == "f" || has(["fax", "팩스"]) { return .kind(.fax) }
        if ["e", "email", "mail"].contains(key) || has(["메일"]) { return .kind(.email) }
        if ["m", "hp", "handphone"].contains(key) || has(["mobile", "iphone", "cell", "휴대", "핸드폰", "모바일"]) {
            return .kind(.mobile)
        }
        if ["o", "main", "dir"].contains(key) || has(["office", "work", "company", "direct", "회사", "사무실", "직장", "대표", "직통"]) {
            return .kind(.office)
        }
        if ["t", "tel", "phone", "telephone", "전화", "전화번호", "연락처"].contains(key) { return .phone }
        if has(["home", "other", "pager", "school", "집", "자택", "기타"]) { return .kind(.other) }
        return .unknown
    }

    /// 휴대전화 번호 모양 — `010` · `011` · `016~019` 로 시작하는 10~11자리 (`+82 10…` 도).
    static func isMobile(_ number: String) -> Bool {
        var digits = String(number.filter { $0.isASCII && $0.isNumber })
        if number.contains("+"), digits.hasPrefix("82") {
            digits = "0" + digits.dropFirst(2)
        }
        guard (10...11).contains(digits.count), digits.hasPrefix("01") else { return false }
        let third = digits[digits.index(digits.startIndex, offsetBy: 2)]
        return "016789".contains(third)
    }

    static func ranges(of pattern: String, in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text) }
    }
}
