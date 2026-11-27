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
    /// 연락 줄을 다섯 칸(휴대전화 · 사무실 · 팩스 · 이메일 · 기타)으로 가른 것 (이슈 11). `M.` · `T.` · `F.` · `E.` 를 읽는다.
    public var contact: ContactFields = ContactFields()
    /// 정리한 모든 줄 (위에서 아래 순서). 제안이 틀렸을 때 사용자가 직접 고르는 재료다.
    public var lines: [String]

    public var hasSuggestion: Bool {
        name != nil || organization != nil || role != nil || !phones.isEmpty || !emails.isEmpty || !contact.isEmpty
    }
}

/// 명함 글자를 이름 · 소속 · 직무 · 전화 · 메일로 가른다. **기기 안에서만** 돈다 — 네트워크가 없다.
///
/// 규칙은 단순하고 결정적이다 (파이썬 정답표 `Tools/golden/generate.py` 의 `parse_card` 가 같은 규칙으로 대조한다).
/// **이슈 130 (2026-11-26 · 실제 명함 13장)** 에서 다시 짰다. 줄마다 차례로 본다:
/// 1. 연락 줄 — 메일 이름표 · `@` 둘레 잡음 · `(+82 10)` 꼴을 손질하고, 메일 도메인 오독은 같은 명함 누리집 · 흔한 메일로 바로잡는다
/// 2. 직무가 있는 줄 — 앞의 한글 조각(뒤가 직무나 영문)은 이름. 기관 낱말이 모든 직무 낱말보다 앞이면 소속 · 직무로 나눈다.
///    줄 끝이 직무면 기관 낱말이 있어도 직무
/// 3. 첫째 순위 기관(주식회사 · ㈜ · 대학교 …) — 같은 줄에 주소가 이어지면 앞에서 자른다
/// 4. 둘째 순위 기관(대학원 · 조합 · 긴 `…연구원` · 지역 이름 하나)
/// 5. 한글 이름 + 영문 이름 · 6. 한글 이름 · 7. 부서만 있는 줄 · 8. 영문 이름(모두 대문자는 기관 후보)
/// 그 뒤: 이름은 (직무 · 영문과 같은 줄 > 성으로 시작하는 한글 > 그 밖의 한글 > 영문) → 글자 크기 → 먼저 나온 줄.
/// 직무는 (부서가 있는 줄 > 직무 낱말 줄 > 학위만 있는 줄) → 먼저 나온 줄. 소속은 (첫째 > 둘째 > 주소 바로 위 한글 낱말 > 대문자 영문)
/// → 먼저 나온 줄, 그리고 부서만 있는 첫 줄의 마지막 부서를 붙인다(사용자 · 기관 + 마지막 부서).
public enum BusinessCardParser {

    static let roleKeywords = [
        "대표이사", "대표", "회장", "사장", "부사장", "전무", "상무", "이사", "본부장", "실장", "센터장",
        "부장", "차장", "과장", "팀장", "대리", "주임", "사원", "책임", "선임", "수석", "연구원", "교수",
        "원장", "매니저", "디자이너", "개발자", "엔지니어", "컨설턴트",
        // 이슈 130: 단장 · 소장 · 국장 · 처장 · 학위 · 영문 직함 · 흔한 오독 `팀당`
        "단장", "소장", "국장", "처장", "박사", "팀당",
        "편집장", "점장", "공장장", "위원장", "의장", "관장", "학장", "총장",
        // 이슈 141 — 강사 · 의료 · 전문직
        "강사", "전임의", "전공의", "간호사", "약사", "의사", "변호사", "변리사", "회계사", "세무사", "노무사",
        // 이슈 142 — 외래어 직함
        "어드바이저", "코디네이터", "스페셜리스트", "디렉터", "애널리스트", "큐레이터", "트레이너", "에디터",
        // 이슈 133 — 공무원 직급
        "사무관", "서기관", "주무관", "이사관", "행정관", "연구관", "연구사", "지도관", "지도사", "심사관", "조사관", "감독관",
        "ceo", "cto", "cfo", "coo", "director", "manager", "engineer", "designer", "developer",
        "consultant", "president", "founder", "professor", "lead",
        "executive", "officer", "head", "vp", "architect", "specialist", "phd",
        "advisor", "adviser", "coordinator", "analyst", "bd",
    ]
    static let koreanOrgKeywords = ["주식회사", "(주)", "㈜", "유한회사", "재단", "협회", "대학교", "병원", "연구소", "은행", "그룹"]
    static let latinOrgKeywords: Set<String> = ["inc", "corp", "co", "ltd", "llc", "company", "university", "labs", "lab"]
    /// 부서 이름 끝 — `개발팀` 을 사람 이름으로 보지 않으려고.
    static let departmentSuffixes = ["팀", "부", "실", "과", "처", "국", "센터", "본부", "그룹"]
    /// 이슈 130 — 둘째 순위 기관 낱말 끝 · 지역 이름 끝 · 부서 끝 · 주소 낱말 끝.
    static let org2Suffixes = ["대학원", "대학", "진흥원", "기술원", "조합", "공단"]
    static let regionSuffixes = ["특별자치도", "특별시", "광역시", "남도", "북도", "도청", "시청", "구청", "군청"]
    static let deptSuffixes = ["팀", "부", "실", "과", "국", "센터", "본부", "단", "처"]
    static let addressSuffixes = ["특별자치도", "특별시", "광역시", "도", "시", "군", "구", "읍", "면", "동", "로", "길"]
    /// 흔한 성 (두 글자 성 먼저) — 글자만 큰 표어보다 성으로 시작하는 이름을 먼저 (ⓧ).
    static let surnames2 = ["남궁", "황보", "제갈", "선우", "독고", "사공", "서문"]
    static let surnames = Set("김이박최정강조윤장임한오서신권황안송전홍유고문양손배백허남심노하곽성차주우구민류나진지엄채원천방공현함변염여추도소석선설마길연위표명기반라왕금옥육인맹제모탁국어은편용예경봉사부가복태목형피두감".unicodeScalars)
    /// 이슈 133 — 영문 이름 후보에서 뺄 기관 낱말 · 영문 부서 끝 · 이름 앞 칭호.
    static let latinOrgWords: Set<String> = ["centre", "center", "institute", "technology", "technologies", "university", "college",
                                             "school", "division", "department", "agency", "foundation", "association",
                                             "laboratory", "corporation"]
    static let latinDeptWords: Set<String> = ["division", "department"]
    static let honorificPattern = #"^(?:[Dd][Rr]|[Pp][Rr][Oo][Ff]|[Mm][Rr][Ss]?|[Mm][Ss])\.?$"#
    static let latinWordPattern = #"^[A-Za-z][A-Za-z'-]*$"#
    static let knownMailDomains = ["gmail.com", "naver.com", "daum.net", "hanmail.net", "kakao.com", "nate.com",
                                   "hotmail.com", "outlook.com", "icloud.com"]

    static let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    /// 이슈 133 — `+국가번호` 꼴 · 앞뒤에 숫자 · 붙임표가 이어지는 긴 숫자열(계좌번호)의 가운데는 번호로 보지 않는다.
    static let phonePattern = #"(?<![\d-])(?:\+\d{1,3}[\s.-]?)?\(?0?\d{1,2}\)?[\s.-]?\d{3,4}[\s.-]?\d{4}(?!\d)"#
    static let capWordPattern = #"^[A-Z][a-z][A-Za-z'-]*$"#
    static let logoWordPattern = #"^[A-Za-z]{2,8}$"#
    static let latinNamePattern = #"^[A-Z][A-Za-z'-]+(?: [A-Z][A-Za-z'-]+){1,2}$"#
    /// 메일 앞에 붙은 이름표 — `E.haneul@…` (이슈 118 · iOS 27 글자 인식이 `E. ` 의 빈칸을 먹었다).
    /// 대문자 E 하나 · Email · E-mail · Mail 만 이름표로 본다 — 소문자 `e.kim@…` 은 메일 주소 그대로 둔다.
    static let emailLabelPattern = #"(?<![A-Za-z0-9._%+-])(E|EMAIL|Email|E-mail|E-Mail|MAIL|Mail)([.:])(?=[A-Za-z0-9._%+-]+@)"#
    /// 이슈 130 ⓚ — 인식이 `@` 앞뒤에 끼운 `(` · `)` · 빈칸. ⓡ — `(+82 10)` · `+82 (0)41` 꼴 번호.
    static let atNoisePattern = #"(?<=[A-Za-z0-9._%+-])[ (]{1,2}@[ )]{0,2}(?=[A-Za-z0-9])|(?<=[A-Za-z0-9._%+-])@[ )]{1,2}(?=[A-Za-z0-9])"#
    static let parenCountryPattern = #"\(\+82[ .-]*0?(\d{1,2})\)"#
    static let parenZeroPattern = #"\(\+82[ .-]*0\)[ .-]*"#
    static let zeroCountryPattern = #"\+82[ .-]*\(0\)[ .-]*"#
    /// 점 + 빈칸으로 끊은 번호(`+82. 2. 555. 0100`) — 빈칸 하나로 (이슈 138).
    /// 메일 도메인의 점을 쌍점으로 읽은 것(`…@shop.hanbit:com`) — 점으로 (이슈 142).
    static let emailColonPattern = #"(@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*):(?=[A-Za-z]{2,})"#
    static let dotGapPattern = #"(?<=\d)\. (?=\d)"#
    static let urlPattern = #"(?:https?://|www\.)[^ ]+"#
    static let zipPattern = #"^\(?\d{5}\)?$"#
    static let siteSchemePattern = #"^(?:https?://)?(?:www\.)?"#
    static let roleSeparators: Set<Character> = [" ", "/", "|", ",", "·"]

    /// 이름 · 직무 · 소속 후보 — 순위가 작을수록, 그다음 차례가 빠를수록 먼저.
    struct Candidate {
        let rank: Int
        let height: Double
        let order: Int
        let text: String
    }

    public static func parse(_ raw: [CardLine]) -> CardSuggestion {
        var suggestion = CardSuggestion(name: nil, organization: nil, role: nil, phones: [], emails: [], lines: [])
        let cleaned: [(text: String, height: Double)] = raw.compactMap { line -> (text: String, height: Double)? in
            let text = TextNormalization.collapsedSpaces(TextNormalization.normalized(line.text))
            if text.isEmpty { return nil }
            return (text: text, height: line.height)
        }
        let texts = mergedLoneLabels(cleaned)
        let sites = texts.flatMap { matches(urlPattern, in: $0.text).map(siteDomain) }
        var contactLines: [String] = []
        var names: [Candidate] = []
        var roles: [Candidate] = []
        var orgs: [Candidate] = []
        var depts: [String] = []
        var kinds: [String] = []

        for (order, entry) in texts.enumerated() {
            let text = entry.text
            let height = entry.height
            suggestion.lines.append(text)
            let lower = text.lowercased()

            // 1. 연락 줄
            var contactText = tidyContact(text)
            for email in matches(emailPattern, in: contactText) {
                contactText = contactText.replacingOccurrences(of: email, with: correctedEmail(email, sites: sites))
            }
            let emails = matches(emailPattern, in: contactText)
            let phones = matches(phonePattern, in: contactText)
            if !emails.isEmpty || !phones.isEmpty || lower.contains("www.") || lower.contains("http") {
                contactLines.append(contactText)
                for email in emails.map({ $0.lowercased() }) where !suggestion.emails.contains(email) {
                    suggestion.emails.append(email)
                }
                if !isFaxLine(lower) {
                    for phone in phones.map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: " ")) })
                    where !suggestion.phones.contains(phone) {
                        suggestion.phones.append(phone)
                    }
                }
                kinds.append("contact")
                continue
            }

            let tokens = text.split(separator: " ").map(String.init)
            let pieces = rolePieces(text)

            // 2. 직무가 있는 줄
            if pieces.contains(where: isRoleToken), let first = tokens.firstIndex(where: hasRole) {
                var roleText = text
                var lead: [String] = []
                for token in tokens[..<first] {
                    guard isSyllables(token) else { break }
                    lead.append(token)
                }
                // 영문 이름 + 직무 한 줄(`Seoyun Han Vice President`) — 맨 앞 두 낱말이 이름 모양이면 이름 후보(영문 순위)로,
                // 나머지는 직무로 (이슈 140)
                if lead.isEmpty, first >= 2,
                   !matches(capWordPattern, in: tokens[0]).isEmpty, !matches(capWordPattern, in: tokens[1]).isEmpty,
                   !isRoleToken(tokens[0]), !isRoleToken(tokens[1]), !hasLatinOrgWord(tokens[0] + " " + tokens[1]) {
                    names.append(Candidate(rank: 3, height: height, order: order, text: tokens[0] + " " + tokens[1]))
                    let rest = tokens[2...].joined(separator: " ")
                    roleText = String(rest.drop { "|/,· ".contains($0) })
                }
                let after = tokens[lead.count]
                if !lead.isEmpty, lead.count == first || startsWithLatinLetter(after), isNameWord(lead.joined()) {
                    names.append(Candidate(rank: 0, height: height, order: order, text: lead.joined()))
                    if lead.count == first { roleText = tokens[first...].joined(separator: " ") }
                }
                // 기관 낱말이 모든 직무 낱말보다 앞이면 그 줄을 나눈다 — `한빛대학교 연구원` → 소속 · 직무
                if let orgAt = tokens.firstIndex(where: isOrganization), orgAt < first,
                   !names.contains(where: { $0.order == order }) {
                    orgs.append(Candidate(rank: 0, height: 0, order: order, text: tokens[...orgAt].joined(separator: " ")))
                    let rest = tokens[(orgAt + 1)...].joined(separator: " ")
                    roles.append(Candidate(rank: roleRank(rest), height: 0, order: order, text: fixedRole(rest)))
                    kinds.append("role")
                    continue
                }
                if let last = pieces.last, isRoleToken(last) || !(isOrganization(text) || isOrganization2(text)) {
                    roles.append(Candidate(rank: roleRank(roleText), height: 0, order: order, text: fixedRole(roleText)))
                    kinds.append("role")
                    continue
                }
            }

            // 3. 첫째 순위 기관 — 같은 줄에 주소가 이어지면 앞에서 자른다 (ⓛ)
            if isOrganization(text) {
                var org = text
                if let cut = tokens.indices.first(where: { $0 > 0 && isAddressToken(tokens[$0]) }) {
                    let head = tokens[..<cut].joined(separator: " ")
                    if isOrganization(head) { org = head }
                }
                orgs.append(Candidate(rank: 0, height: 0, order: order, text: org))
                kinds.append("org")
                continue
            }

            // 4. 둘째 순위 기관
            if isOrganization2(text) {
                orgs.append(Candidate(rank: 1, height: 0, order: order, text: text))
                kinds.append("org")
                continue
            }

            // 5. 칭호로 시작하는 영문 이름 (ⓨ)
            if let honored = honorificName(text) {
                names.append(Candidate(rank: 0, height: height, order: order, text: honored))
                kinds.append("name")
                continue
            }

            // 5. 한글 이름 + 영문 이름 (ⓞ)
            var lead: [String] = []
            for token in tokens {
                guard isSyllables(token) else { break }
                lead.append(token)
            }
            if !lead.isEmpty, lead.count < tokens.count, startsWithLatinLetter(tokens[lead.count]), isNameWord(lead.joined()) {
                names.append(Candidate(rank: 0, height: height, order: order, text: lead.joined()))
                kinds.append("name")
                continue
            }

            // 6. 한글 이름
            let joined = text.replacingOccurrences(of: " ", with: "")
            if isHangulName(text), isNameWord(joined) {
                names.append(Candidate(rank: hasSurname(joined) ? 1 : 2, height: height, order: order, text: joined))
                kinds.append("name")
                continue
            }

            // 7. 영문 부서 — `Division` · `Department` 한 낱말 줄은 윗줄에 잇고, 그 낱말로 끝나는 줄은 그대로 (ⓩ)
            if let lastToken = tokens.last, latinDeptWords.contains(latinLetters(lastToken)) {
                // `직무 / 부서` 한 줄 — 왼쪽은 직무, 오른쪽만 부서 (이슈 138)
                if let bar = text.firstIndex(of: "/") {
                    let space = CharacterSet(charactersIn: " ")
                    let left = text[..<bar].trimmingCharacters(in: space)
                    let right = text[text.index(after: bar)...].trimmingCharacters(in: space)
                    let leftHasDept = left.split(separator: " ").contains { latinDeptWords.contains(latinLetters(String($0))) }
                    if !left.isEmpty, !right.isEmpty, !leftHasDept {
                        roles.append(Candidate(rank: 1, height: 0, order: order, text: fixedRole(left)))
                        depts.append(right)
                        kinds.append("role")
                        continue
                    }
                }
                if tokens.count == 1, order > 0, kinds[order - 1] == "other" {
                    depts.append(texts[order - 1].text + " " + text)
                } else {
                    depts.append(text)
                }
                kinds.append("dept")
                continue
            }

            // 7. 부서만 있는 줄
            if let last = pieces.last, pieces.allSatisfy(isDeptToken) {
                depts.append(last)
                kinds.append("dept")
                continue
            }

            // 8. 영문 — 모두 대문자면 기관 후보, 아니면 영문 이름 후보 (ⓝ)
            if isAllCaps(text) {
                // 한글 이름 바로 다음의 대문자 영문 줄은 그 이름의 로마자 — 기관 후보가 아니다 (ⓔⓔ)
                let afterName = order > 0 && kinds[order - 1] == "name"
                    && isSyllables(texts[order - 1].text.replacingOccurrences(of: " ", with: ""))
                if !afterName, tokens.count <= 3, !text.unicodeScalars.contains(where: { (0x30...0x39).contains($0.value) }) {
                    orgs.append(Candidate(rank: 3, height: 0, order: order, text: text))
                }
                kinds.append("other")
                continue
            }
            if !matches(latinNamePattern, in: text).isEmpty, !hasLatinOrgWord(text) {
                names.append(Candidate(rank: 3, height: height, order: order, text: text))
                kinds.append("name")
                continue
            }
            kinds.append("other")
        }

        /// 한글로만 된 한두 낱말(3~12자) · 이름 모양(성으로 시작하는 2~3자 · 두 글자 성 4자)이 아님.
        func companyLike(_ index: Int) -> Bool {
            let text = texts[index].text
            let joined = text.replacingOccurrences(of: " ", with: "")
            let length = joined.unicodeScalars.count
            let looksName = hasSurname(joined) && (length <= 3 || surnames2.contains(prefix(joined, 2)))
            return (kinds[index] == "other" || (kinds[index] == "name" && !looksName))
                && text.split(separator: " ").count <= 2 && isSyllables(joined) && (3...12).contains(length)
        }
        // 주소 줄 바로 위의 회사 이름 — `주식회사` 없는 회사 이름 (ⓔ · 이슈 133 두 낱말).
        // 이름 모양이면 넘기지 않는다 — 이름이 주소 바로 위에 있는 명함이 흔하다.
        for index in texts.indices.dropLast() where companyLike(index) && isAddressLine(texts[index + 1].text) {
            orgs.append(Candidate(rank: 2, height: 0, order: index, text: texts[index].text))
            names.removeAll { $0.order == index }
        }
        // 고른 이름 바로 위의 한글 낱말 — `청년농부` · `한빛엔지니어링` 꼴 (이슈 133 ⓑⓑ · 사용자: 소속).
        // 부서 모양(`…부`)이어도 기관 후보가 하나도 없으면 소속으로 — `청년농부` 가 `영업부` 처럼 잡혔다.
        if let best = names.min(by: { ($0.rank, -$0.height, $0.order) < ($1.rank, -$1.height, $1.order) }), best.order > 0 {
            let above = best.order - 1
            let aboveText = texts[above].text
            let deptAbove = kinds[above] == "dept" && orgs.isEmpty && !aboveText.contains(" ") && isSyllables(aboveText)
            if companyLike(above) || deptAbove, !orgs.contains(where: { $0.order == above }) {
                orgs.append(Candidate(rank: 2, height: 0, order: above, text: aboveText))
                names.removeAll { $0.order == above }
            }
        }

        // 로고 한 낱말 — 기관 후보가 하나도 없고 명함에서 가장 큰 줄이 영문 한 낱말(2~8자)이면 소속으로.
        // 인식이 대소문자를 섞어 읽으면(`aWS` 꼴) 대문자로 (이슈 137 · ⓠ · 2026-11-26 사용자).
        if orgs.isEmpty, !texts.isEmpty {
            var top = 0
            for index in texts.indices where texts[index].height > texts[top].height { top = index }
            let word = texts[top].text
            if kinds[top] == "other", !matches(logoWordPattern, in: word).isEmpty {
                let hasUpper = word.unicodeScalars.contains { (0x41...0x5A).contains($0.value) }
                orgs.append(Candidate(rank: 3, height: 0, order: top, text: hasUpper ? word.uppercased() : word))
            }
        }

        // 이름: 순위 → 글자 큰 것 → 먼저 나온 줄. 직무 · 소속: 순위 → 먼저 나온 줄.
        suggestion.name = names.min { ($0.rank, -$0.height, $0.order) < ($1.rank, -$1.height, $1.order) }?.text
        suggestion.role = roles.min { ($0.rank, $0.order) < ($1.rank, $1.order) }?.text
        if var org = orgs.min(by: { ($0.rank, $0.order) < ($1.rank, $1.order) })?.text {
            if let dept = depts.first, !org.contains(dept) { org += " " + dept }
            suggestion.organization = org
        }
        suggestion.contact = ContactSorter.split(contactLines.joined(separator: "\n"))
        return suggestion
    }

    // MARK: - 떨어진 이름표 (이슈 141)

    /// 번호 없이 이름표만 있는 줄(`FAX` · `팩스` · `Mobile`).
    static func isLonePhoneLabel(_ text: String) -> Bool {
        if text.contains(" ") || text.count > 12 || text.contains("@") { return false }
        if text.unicodeScalars.contains(where: { (0x30...0x39).contains($0.value) }) { return false }
        switch ContactSorter.labelKind(ContactSorter.labelKey(text)) {
        case .kind(.fax), .kind(.mobile), .kind(.office), .phone: return true
        default: return false
        }
    }

    static func isBarePhone(_ text: String) -> Bool {
        matches(phonePattern, in: text) == [text]
    }

    /// 인식이 이름표와 번호를 다른 줄로 떼어 읽은 것(`02-555-0199` / `FAX`)을 한 줄로 — 이름표 줄 바로 앞이 이름표 없는
    /// 번호 줄이면 그 줄에, 아니면 바로 뒤의 번호 줄에 붙인다. 파이썬 `merged_lone_labels` 와 같다.
    static func mergedLoneLabels(_ texts: [(text: String, height: Double)]) -> [(text: String, height: Double)] {
        var out = texts
        var index = 0
        while index < out.count {
            let text = out[index].text
            if isLonePhoneLabel(text) {
                if index > 0, isBarePhone(out[index - 1].text) {
                    out[index - 1] = (text: text + " " + out[index - 1].text, height: out[index - 1].height)
                    out.remove(at: index)
                    continue
                }
                if index + 1 < out.count, isBarePhone(out[index + 1].text) {
                    out[index + 1] = (text: text + " " + out[index + 1].text, height: out[index + 1].height)
                    out.remove(at: index)
                    continue
                }
            }
            index += 1
        }
        return out
    }

    // MARK: - 판정

    static func isFaxLine(_ lower: String) -> Bool {
        lower.hasPrefix("fax") || lower.hasPrefix("팩스") || lower.hasPrefix("f.") || lower.hasPrefix("f ")
    }

    static func latinLetters(_ token: String) -> String {
        String(String.UnicodeScalarView(token.unicodeScalars.filter {
            (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value)
        })).lowercased()
    }

    static func isSyllables(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) }
    }

    static func startsWithLatinLetter(_ token: String) -> Bool {
        guard let first = token.unicodeScalars.first else { return false }
        return (0x41...0x5A).contains(first.value) || (0x61...0x7A).contains(first.value)
    }

    static func prefix(_ text: String, _ count: Int) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.prefix(count)))
    }

    static func isOrganization(_ text: String) -> Bool {
        if koreanOrgKeywords.contains(where: { text.contains($0) }) { return true }
        return text.split(separator: " ").contains { latinOrgKeywords.contains(latinLetters(String($0))) }
    }

    static func isRegion(_ token: String) -> Bool {
        token.unicodeScalars.count >= 3 && isSyllables(token) && regionSuffixes.contains { token.hasSuffix($0) }
    }

    /// 둘째 순위 기관 — `…대학원` · `…연구조합` · 긴 `…연구원` · 지역 이름 하나 (ⓒ ⓗ ⓣ).
    static func isOrganization2(_ text: String) -> Bool {
        let tokens = text.split(separator: " ").map(String.init)
        for token in tokens {
            if token.unicodeScalars.count > 2, org2Suffixes.contains(where: { token.hasSuffix($0) }) { return true }
            if token.hasSuffix("연구원"), token.unicodeScalars.count > 5 { return true }
        }
        if tokens.count == 1 {
            let token = tokens[0]
            let length = token.unicodeScalars.count
            // 정부 부처 끝 — `…청`(3자 이상) · `…처`(5자 이상) · `…위원회` (이슈 133 ⓒⓒ)
            if isSyllables(token),
               (length >= 3 && token.hasSuffix("청")) || (length >= 5 && token.hasSuffix("처")) || token.hasSuffix("위원회") {
                return true
            }
        }
        return tokens.count == 1 && isRegion(tokens[0])
    }

    static func isRoleToken(_ token: String) -> Bool {
        let latin = latinLetters(token)
        for keyword in roleKeywords {
            if keyword.unicodeScalars.first.map({ $0.isASCII }) == true {
                if latin == keyword { return true }
                // 인식이 한 글자 틀리거나 빠뜨린 긴 영문 직무 낱말(`Presiden`) — 일곱 자 넘는 낱말만 (이슈 140)
                if keyword.count >= 7, latin.count >= 6, levenshtein(latin, keyword) <= 1 { return true }
            } else if token.hasSuffix(keyword) {
                // `…연구원` 은 그 낱말 하나이거나 `수석` · `책임` 따위 두 글자 뒤일 때만 직무 — 더 길면 기관 (ⓗ)
                if keyword == "연구원", token.unicodeScalars.count > 5 { continue }
                return true
            }
        }
        return false
    }

    static func rolePieces(_ text: String) -> [String] {
        text.split(whereSeparator: { roleSeparators.contains($0) }).map(String.init)
    }

    static func hasRole(_ token: String) -> Bool {
        rolePieces(token).contains(where: isRoleToken)
    }

    static func isDegree(_ piece: String) -> Bool {
        piece.hasSuffix("박사") || latinLetters(piece) == "phd"
    }

    static func isDeptToken(_ token: String) -> Bool {
        token.unicodeScalars.count >= 3 && !isRoleToken(token) && deptSuffixes.contains { token.hasSuffix($0) }
    }

    static func isAddressToken(_ token: String) -> Bool {
        token.unicodeScalars.count >= 2 && isSyllables(token) && addressSuffixes.contains { token.hasSuffix($0) }
    }

    static func isAddressLine(_ text: String) -> Bool {
        let tokens = text.split(separator: " ").map(String.init)
        guard let first = tokens.first else { return false }
        if !matches(zipPattern, in: first).isEmpty { return true }
        return tokens.filter(isAddressToken).count >= 2
    }

    /// 직무 줄의 순위 — 부서가 있는 줄 0 · 직무 낱말 줄 1 · 학위만 있는 줄 2 (ⓥ · 사용자: 직책 줄 먼저).
    static func roleRank(_ roleText: String) -> Int {
        let pieces = rolePieces(roleText)
        if pieces.contains(where: isDeptToken) { return 0 }
        if pieces.filter(isRoleToken).allSatisfy(isDegree) { return 2 }
        return 1
    }

    /// 직무 줄 다듬기 — 맨 앞 `|` 조각이 영문 이름 모양이면 뗀다(`Seoyun Han | CEO | Ph.D.` → `CEO | Ph.D.` · 이슈 136),
    /// 흔한 오독 `팀당` → `팀장`(ⓜ). 파이썬 `fixed_role` 과 같다.
    static func fixedRole(_ text: String) -> String {
        var result = text
        if let bar = text.firstIndex(of: "|") {
            let head = text[..<bar].trimmingCharacters(in: CharacterSet(charactersIn: " "))
            let rest = text[text.index(after: bar)...].trimmingCharacters(in: CharacterSet(charactersIn: " "))
            if !rest.isEmpty, !matches(latinNamePattern, in: head).isEmpty, !rolePieces(head).contains(where: isRoleToken) {
                result = rest
            }
        }
        return result.replacingOccurrences(of: "팀당", with: "팀장")
    }

    /// 한글 2~4음절 — 한 낱말이거나, 한 글자씩 띄어 쓴 것(`김 하 늘`). 부서 이름 끝(`팀` · `부` …)은 뺀다.
    static func isHangulName(_ text: String) -> Bool {
        let tokens = text.split(separator: " ")
        guard tokens.count == 1 || tokens.allSatisfy({ $0.unicodeScalars.count == 1 }) else { return false }
        let joined = tokens.joined()
        guard (2...4).contains(joined.unicodeScalars.count) else { return false }
        guard isSyllables(joined) else { return false }
        return !departmentSuffixes.contains { joined.hasSuffix($0) }
    }

    /// 이름으로 볼 수 있는 한글 낱말 — 직무 · 지역 · `…대학` 은 아니다 (ⓘ ⓒ ⓧ).
    static func isNameWord(_ joined: String) -> Bool {
        isHangulName(joined) && !isRoleToken(joined) && !isRegion(joined) && !org2Suffixes.contains { joined.hasSuffix($0) }
    }

    static func hasSurname(_ name: String) -> Bool {
        if surnames2.contains(prefix(name, 2)) { return true }
        guard let first = name.unicodeScalars.first else { return false }
        return surnames.contains(first)
    }

    /// `Dr lee Minjun` → `Lee Minjun` — 칭호 뒤 영문 낱말 1~3 개(인식이 소문자로 읽어도). 아니면 nil (이슈 133 ⓨ).
    static func honorificName(_ text: String) -> String? {
        let tokens = text.split(separator: " ").map(String.init)
        guard tokens.count >= 2, !matches(honorificPattern, in: tokens[0]).isEmpty else { return nil }
        let rest = tokens.dropFirst()
        guard rest.count <= 3, rest.allSatisfy({ !matches(latinWordPattern, in: $0).isEmpty }) else { return nil }
        return rest.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    static func hasLatinOrgWord(_ text: String) -> Bool {
        text.split(separator: " ").contains { latinOrgWords.contains(latinLetters(String($0))) }
    }

    static func isAllCaps(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value) }
        return letters.count >= 2 && letters.allSatisfy { (0x41...0x5A).contains($0.value) }
    }

    // MARK: - 연락 줄 손질

    /// `E.haneul@example.com` → `E. haneul@example.com` (이슈 118).
    static func separatingEmailLabel(_ text: String) -> String {
        replacing(emailLabelPattern, in: text, with: "$1$2 ")
    }

    /// 메일 이름표 떼기 · `@` 둘레 잡음 · 국가번호 꼴 (이슈 118 · 130).
    static func tidyContact(_ text: String) -> String {
        var result = separatingEmailLabel(text)
        result = replacing(atNoisePattern, in: result, with: "@")
        // `(+82 0) 10-…` — 괄호 안이 국가번호와 앞자리 0 뿐 (이슈 143)
        result = replacing(parenZeroPattern, in: result, with: "0")
        result = replacing(parenCountryPattern, in: result, with: "0$1")
        result = replacing(zeroCountryPattern, in: result, with: "0")
        result = replacing(dotGapPattern, in: result, with: " ")
        return replacing(emailColonPattern, in: result, with: "$1.")
    }

    static func siteDomain(_ url: String) -> String {
        let bare = replacing(siteSchemePattern, in: url.lowercased(), with: "")
        let host = bare.split(separator: "/", omittingEmptySubsequences: false).first.map(String.init) ?? bare
        var trimmed = host
        while trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    /// 메일 도메인 오독 바로잡기 (ⓤ) — 같은 명함 누리집과 두 글자 안, 흔한 메일과 한 글자 안.
    static func correctedEmail(_ email: String, sites: [String]) -> String {
        guard let at = email.lastIndex(of: "@") else { return email }
        let local = email[..<at]
        let domain = email[email.index(after: at)...].lowercased()
        if sites.contains(domain) || knownMailDomains.contains(domain) { return email }
        var best: (distance: Int, domain: String)?
        for (limit, pool) in [(2, sites), (1, knownMailDomains)] {
            for candidate in pool {
                let distance = levenshtein(domain, candidate)
                if distance > 0, distance <= limit, best == nil || distance < best!.distance {
                    best = (distance, candidate)
                }
            }
        }
        guard let best else { return email }
        return String(local) + "@" + best.domain
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a.unicodeScalars)
        let b = Array(b.unicodeScalars)
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1]
            for (j, cb) in b.enumerated() {
                current.append(Swift.min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }

    static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
