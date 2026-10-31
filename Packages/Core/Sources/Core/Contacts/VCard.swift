import Foundation

/// vCard(.vcf) 한 사람 (빌드 18 · D-41) — 내보내기 · 가져오기가 주고받는 칸.
public struct VCardPerson: Sendable, Equatable {
    public var name: String
    public var nickname: String
    public var organization: String
    public var role: String
    public var fields: ContactFields
    public var birthMonth: Int?
    public var birthDay: Int?
    public var birthYear: Int?

    public init(name: String, nickname: String = "", organization: String = "", role: String = "",
                fields: ContactFields = ContactFields(), birthMonth: Int? = nil, birthDay: Int? = nil, birthYear: Int? = nil) {
        self.name = name
        self.nickname = nickname
        self.organization = organization
        self.role = role
        self.fields = fields
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.birthYear = birthYear
    }
}

/// **vCard 만들기 · 읽기** (빌드 18 · D-41) — 기기 안에서만. 파이썬 정답표(`vcardEncode` · `vcardParse`)와 같은 셈이다.
///
/// - 만들기: vCard 3.0. 이름 · 별명 · 소속 · 직무 · 연락 다섯 칸(휴대 `CELL` · 사무실 `WORK,VOICE` · 팩스 `WORK,FAX` ·
///   이메일 · 기타는 `NOTE`) · 생일(연도를 모르면 `--MMDD`). 기록 · 첫 인연 · 태그 · 명함 사진은 넣지 않는다 —
///   연락처 앱이 받을 칸이 없고, 인연의 기록은 백업 파일이 맡는다.
/// - 읽기: 2.1 · 3.0 · 4.0 을 너그럽게. 접힌 줄 · 이름표 앞 묶음(`item1.`) · 쿼티드 프린터블(2.1) · 연도를 뺀 생일
///   (`--0314`, 기기 연락처의 `X-APPLE-OMIT-YEAR`)을 푼다. 전화의 종류(`TYPE`)는 연락처 가져오기와 같은 규칙
///   (`ContactSorter.fromContact`)으로 다섯 칸에 가른다. 이름이 없는 카드는 건너뛴다.
public enum VCard {

    // MARK: - 만들기

    public static func encode(_ people: [VCardPerson]) -> String {
        var out = ""
        for person in people {
            var lines = ["BEGIN:VCARD", "VERSION:3.0", "N:;\(escape(person.name));;;", "FN:\(escape(person.name))"]
            if !person.nickname.isEmpty { lines.append("NICKNAME:\(escape(person.nickname))") }
            if !person.organization.isEmpty { lines.append("ORG:\(escape(person.organization))") }
            if !person.role.isEmpty { lines.append("TITLE:\(escape(person.role))") }
            let f = person.fields
            if !f.mobile.isEmpty { lines.append("TEL;TYPE=CELL:\(escape(f.mobile))") }
            if !f.office.isEmpty { lines.append("TEL;TYPE=WORK,VOICE:\(escape(f.office))") }
            if !f.fax.isEmpty { lines.append("TEL;TYPE=WORK,FAX:\(escape(f.fax))") }
            if !f.email.isEmpty { lines.append("EMAIL;TYPE=INTERNET:\(escape(f.email))") }
            if let month = person.birthMonth, let day = person.birthDay {
                if let year = person.birthYear {
                    lines.append(String(format: "BDAY:%04d-%02d-%02d", year, month, day))
                } else {
                    lines.append(String(format: "BDAY:--%02d%02d", month, day))
                }
            }
            if !f.other.isEmpty { lines.append("NOTE:\(escape(f.other))") }
            lines.append("END:VCARD")
            out += lines.joined(separator: "\r\n") + "\r\n"
        }
        return out
    }

    static func escape(_ text: String) -> String {
        var out = ""
        for ch in text {
            switch ch {
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case ",": out += "\\,"
            case ";": out += "\\;"
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: - 읽기

    public static func parse(_ text: String) -> [VCardPerson] {
        let raw = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var lines: [String] = []
        for line in raw {
            if let last = lines.last {
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    lines[lines.count - 1] = last + line.dropFirst()
                    continue
                }
                if isQuotedPrintable(last), last.hasSuffix("=") {
                    lines[lines.count - 1] = String(last.dropLast()) + line
                    continue
                }
            }
            lines.append(line)
        }

        var people: [VCardPerson] = []
        var card: Card?
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let head = String(line[..<colon])
            var value = String(line[line.index(after: colon)...])
            var headParts = head.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            var name = headParts.removeFirst().uppercased()
            if let dot = name.lastIndex(of: ".") { name = String(name[name.index(after: dot)...]) }
            if name == "BEGIN", value.uppercased() == "VCARD" {
                card = Card()
                continue
            }
            if name == "END", value.uppercased() == "VCARD" {
                if let finished = card?.finish() { people.append(finished) }
                card = nil
                continue
            }
            guard card != nil else { continue }
            var types: [String] = []
            var params: [String: String] = [:]
            for part in headParts {
                if let eq = part.firstIndex(of: "=") {
                    let key = part[..<eq].uppercased()
                    // 4.0 은 TYPE="work,voice" 처럼 따옴표를 친다.
                    let val = String(part[part.index(after: eq)...]).replacingOccurrences(of: "\"", with: "")
                    params[key] = val
                    if key == "TYPE" { types += val.split(separator: ",").map { $0.uppercased() } }
                } else {
                    types.append(part.uppercased())
                }
            }
            if params["ENCODING"]?.uppercased() == "QUOTED-PRINTABLE" || types.contains("QUOTED-PRINTABLE") {
                value = decodeQuotedPrintable(value)
            }
            switch name {
            case "FN": card?.formatted = unescape(value)
            case "N":
                let parts = splitStructured(value)
                card?.family = parts.first ?? ""
                card?.given = parts.count > 1 ? parts[1] : ""
            case "NICKNAME": card?.nickname = unescape(value)
            case "ORG": card?.organization = splitStructured(value).first ?? ""
            case "TITLE": card?.role = unescape(value)
            case "TEL":
                let label = types.filter { !["VOICE", "PREF", "INTERNET", "QUOTED-PRINTABLE"].contains($0) && !$0.hasPrefix("CHARSET") }
                    .joined(separator: ",")
                var number = unescape(value)
                if number.lowercased().hasPrefix("tel:") { number = String(number.dropFirst(4)) }   // 4.0 의 VALUE=uri
                card?.phones.append(ContactSorter.LabeledValue(label: label, value: number))
            case "EMAIL": card?.emails.append(unescape(value))
            case "NOTE": card?.note = unescape(value)
            case "BDAY": card?.birthday = birthday(value, omitYear: params["X-APPLE-OMIT-YEAR"])
            default: break
            }
        }
        return people
    }

    private struct Card {
        var formatted = ""
        var family = ""
        var given = ""
        var nickname = ""
        var organization = ""
        var role = ""
        var phones: [ContactSorter.LabeledValue] = []
        var emails: [String] = []
        var note = ""
        var birthday: (month: Int, day: Int, year: Int?)?

        func finish() -> VCardPerson? {
            let clean = { (text: String) in TextNormalization.collapsedSpaces(TextNormalization.normalized(text)) }
            let name = clean(formatted).isEmpty ? ContactName.compose(given: given, family: family) : clean(formatted)
            guard !name.isEmpty else { return nil }
            var fields = ContactSorter.fromContact(phones: phones, emails: emails)
            if !note.isEmpty { fields.place(note, as: .other) }
            return VCardPerson(name: name, nickname: clean(nickname), organization: clean(organization), role: clean(role),
                               fields: fields, birthMonth: birthday?.month, birthDay: birthday?.day, birthYear: birthday?.year)
        }
    }

    static func isQuotedPrintable(_ line: String) -> Bool {
        guard let colon = line.firstIndex(of: ":") else { return false }
        return line[..<colon].uppercased().contains("QUOTED-PRINTABLE")
    }

    static func decodeQuotedPrintable(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var out: [UInt8] = []
        var i = 0
        func hex(_ b: UInt8) -> UInt8? {
            switch b {
            case 48...57: return b - 48
            case 65...70: return b - 55
            case 97...102: return b - 87
            default: return nil
            }
        }
        while i < bytes.count {
            if bytes[i] == 61, i + 2 < bytes.count, let hi = hex(bytes[i + 1]), let lo = hex(bytes[i + 2]) {
                out.append(hi << 4 | lo)
                i += 3
            } else {
                out.append(bytes[i])
                i += 1
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    static func unescape(_ text: String) -> String {
        var out = ""
        var escaped = false
        for ch in text {
            if escaped {
                switch ch {
                case "n", "N": out.append("\n")
                default: out.append(ch)
                }
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else {
                out.append(ch)
            }
        }
        if escaped { out.append("\\") }
        return out
    }

    /// `;` 로 나뉜 칸들 — 앞에 `\` 가 붙은 `;` 는 글자다.
    static func splitStructured(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false
        for ch in text {
            if escaped {
                current.append("\\")
                current.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == ";" {
                parts.append(unescape(current))
                current = ""
            } else {
                current.append(ch)
            }
        }
        if escaped { current.append("\\") }
        parts.append(unescape(current))
        return parts
    }

    /// `1990-03-14` · `19900314` · `--0314` · `--03-14` (시각이 붙어 있으면 뗀다). 기기 연락처는 연도를 모를 때
    /// `X-APPLE-OMIT-YEAR=1604` 와 `1604-03-14` 를 함께 쓴다 — 그 해는 연도 없음으로 본다. 없는 날이면 버린다.
    static func birthday(_ raw: String, omitYear: String?) -> (month: Int, day: Int, year: Int?)? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if let t = text.firstIndex(of: "T") { text = String(text[..<t]) }
        var year: Int?
        var rest: String
        if text.hasPrefix("--") {
            rest = String(text.dropFirst(2))
        } else {
            let digits = text.filter { $0 != "-" }
            guard digits.count == 8, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let y = Int(digits.prefix(4)) else { return nil }
            year = y
            rest = String(digits.dropFirst(4))
        }
        rest = rest.filter { $0 != "-" }
        guard rest.count == 4, rest.allSatisfy({ $0.isASCII && $0.isNumber }), let month = Int(rest.prefix(2)), let day = Int(rest.suffix(2)) else { return nil }
        if let year, let omit = omitYear.flatMap({ Int($0) }), omit == year { return valid(month, day, nil) }
        return valid(month, day, year)
    }

    private static func valid(_ month: Int, _ day: Int, _ year: Int?) -> (month: Int, day: Int, year: Int?)? {
        BirthdayRule.isValid(month: month, day: day, year: year) ? (month, day, year) : nil
    }
}

/// **가져올 때 같은 사람 판정** (빌드 18 · D-41) — 섞이지 않게 미리 보여 준다. 파이썬 정답표(`importMatch`)와 같은 셈이다.
///
/// - **이미 있음**(`duplicate`): 이름이 같고(공백 · 대소문자 · 발음 기호 무시) 가져올 번호 · 메일이 모두 그 사람에게 이미 있다.
/// - **같은 사람 후보**(`possibleSame`): 이름이 같지만 새 번호 · 메일이 있다, 또는 이름은 달라도 번호 · 메일이 겹친다.
/// - **새 사람**(`new`): 그 밖.
/// 번호는 숫자만 견준다(`+82 10` 은 `010`). 기존 사람은 부르는 쪽이 이름 순으로 넘긴다 — 여럿이면 앞사람.
public enum ImportMatcher {
    public enum Verdict: String, Sendable {
        case new, possibleSame, duplicate
    }

    public struct Existing: Sendable {
        public let id: UUID
        public let name: String
        public let fields: ContactFields
        public init(id: UUID, name: String, fields: ContactFields) {
            self.id = id
            self.name = name
            self.fields = fields
        }
    }

    public struct Match: Sendable, Equatable {
        public let verdict: Verdict
        public let existingID: UUID?
    }

    public static func nameKey(_ name: String) -> String {
        NameSort.key(String(name.filter { !$0.isWhitespace }))
    }

    static func phoneKey(_ number: String) -> String? {
        var digits = number.filter { $0.isASCII && $0.isNumber }
        if number.contains("+"), digits.hasPrefix("82") { digits = "0" + digits.dropFirst(2) }
        return digits.count >= 7 ? digits : nil
    }

    static func keys(_ fields: ContactFields) -> Set<String> {
        var out = Set([fields.mobile, fields.office, fields.fax].compactMap(phoneKey).map { "t:" + $0 })
        let email = fields.email.trimmingCharacters(in: .whitespaces).lowercased()
        if !email.isEmpty { out.insert("e:" + email) }
        return out
    }

    public static func classify(_ incoming: [VCardPerson], existing: [Existing]) -> [Match] {
        let prepared = existing.map { (person: $0, name: nameKey($0.name), keys: keys($0.fields)) }
        return incoming.map { person in
            let name = nameKey(person.name)
            let wanted = keys(person.fields)
            let sameName = prepared.filter { $0.name == name }
            if let hit = sameName.first(where: { wanted.isSubset(of: $0.keys) }) {
                return Match(verdict: .duplicate, existingID: hit.person.id)
            }
            if let hit = sameName.first {
                return Match(verdict: .possibleSame, existingID: hit.person.id)
            }
            if !wanted.isEmpty, let hit = prepared.first(where: { !$0.keys.isDisjoint(with: wanted) }) {
                return Match(verdict: .possibleSame, existingID: hit.person.id)
            }
            return Match(verdict: .new, existingID: nil)
        }
    }
}
