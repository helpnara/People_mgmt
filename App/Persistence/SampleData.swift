import Core
import Foundation
import SwiftData
import UIKit

/// CI 스크린샷용 **견본 자료**. 전부 지어낸 사람 · 회사 · 메모다.
///
/// 이 저장소는 public 이다. **실제 사람의 이름 · 소속 · 메모를 여기 적지 않는다** (CLAUDE.md).
/// 실행 인자 `-seedSampleData` 일 때 인메모리 저장소에만 채운다 — 진짜 저장소에는 절대 넣지 않는다.
enum SampleData {

    @MainActor
    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            let components = DateComponents(year: year, month: month, day: day)
            return DayNormalizer.noon(of: calendar.date(from: components) ?? Date(), calendar: calendar)
        }

        // 나 (이슈 12) — 지어낸 사람이다. 목록 맨 위에 선다.
        let me = Person(name: "윤다온")
        me.isMe = true
        me.organization = "청림소프트"
        me.role = "서비스 기획"
        me.mobilePhone = "010-5555-0000"
        me.email = "daon@example.com"
        context.insert(me)

        let haneul = Person(name: "김하늘")
        haneul.organization = "청림소프트"
        haneul.role = "팀장"
        haneul.relationshipType = "동료"
        haneul.metThrough = "직장"
        haneul.firstMetDate = day(2019, 3, 4)
        haneul.firstNote = "입사 첫날 옆자리에 앉았다. 점심을 같이 먹으며 팀 분위기를 알려 주었다."
        haneul.tags = ["멘토", "독서모임"]
        haneul.mobilePhone = "010-1234-5678"
        haneul.officePhone = "02-555-0101"
        haneul.email = "haneul@example.com"
        haneul.businessCard = renderCard(organization: "청림소프트 주식회사", name: "김하늘", role: "개발팀 팀장",
                                         phone: "010-1234-5678", email: "haneul@example.com")

        let doyun = Person(name: "이도윤")
        doyun.nickname = "도윤 형"
        doyun.organization = "한빛대학교"
        doyun.role = "연구원"
        doyun.relationshipType = "친구"
        doyun.metThrough = "학교"
        doyun.firstMetDate = day(2011, 9, 1)
        doyun.firstNote = "대학 동아리 신입 환영회. 등산을 같이 다니기 시작했다."
        doyun.tags = ["대학", "등산"]

        let seoyeon = Person(name: "박서연")
        seoyeon.organization = "마루디자인"
        seoyeon.role = "대표"
        seoyeon.relationshipType = "협력사"
        seoyeon.metThrough = "소개"
        seoyeon.firstMetDate = day(2023, 5, 16)
        seoyeon.firstNote = "브랜드 리뉴얼 때 김하늘 팀장이 소개해 주었다."
        seoyeon.tags = ["디자인"]

        let minjun = Person(name: "최민준")
        minjun.relationshipType = "지인"
        minjun.metThrough = "행사·교육"
        minjun.firstNote = "데이터 시각화 세미나 뒤풀이에서 옆자리. 날짜는 기억나지 않는다."

        let yujin = Person(name: "정유진")
        yujin.organization = "청림소프트"
        yujin.role = "주니어 개발자"
        yujin.relationshipType = "후배"
        yujin.metThrough = "직장"
        yujin.firstMetDate = day(2024, 1, 8)
        yujin.firstNote = "온보딩 멘토로 배정되었다."
        yujin.tags = ["멘티"]

        let jiwoo = Person(name: "한지우")
        jiwoo.organization = "나비랩스"
        jiwoo.role = "PM"
        jiwoo.relationshipType = "고객"
        jiwoo.metThrough = "프로젝트"
        jiwoo.firstMetDate = day(2022, 11, 2)
        jiwoo.tags = ["프로젝트A"]

        let alice = Person(name: "Alice Park")
        alice.organization = "Nabi Labs"
        alice.role = "Engineer"
        alice.relationshipType = "고객"
        alice.metThrough = "온라인"
        alice.tags = ["Mentor"]

        let seoa = Person(name: "윤서아")
        seoa.relationshipType = "가족"
        seoa.metThrough = "가족·친척"
        seoa.firstNote = "사촌 동생. 명절마다 본다."

        let people = [haneul, doyun, seoyeon, minjun, yujin, jiwoo, alice, seoa]
        for person in people { context.insert(person) }
        seoyeon.introducedBy = haneul
        yujin.introducedBy = haneul

        func record(_ type: String, _ date: Date, title: String?, note: String?, location: String? = nil,
                    tags: [String] = [], with participants: [Person]) {
            let item = Record(recordType: type, occurredAt: date, title: title, note: note)
            item.location = location
            item.tags = tags
            context.insert(item)
            item.participants = participants
        }

        record("meeting", day(2026, 9, 29), title: "분기 회의", note: "로드맵 우선순위 논의. 예산은 보류.",
               location: "본사 3층", tags: ["업무"], with: [haneul, yujin])
        record("meal", day(2026, 8, 14), title: "점심", note: "이직 고민을 들었다. 당분간은 지켜보기로.",
               location: "국숫집", with: [haneul])
        record("collaboration", day(2023, 6, 1), title: "킥오프", note: "브랜드 리뉴얼 범위 합의.",
               tags: ["프로젝트"], with: [seoyeon, haneul])
        record("trip", day(2025, 4, 10), title: nil, note: "봄 산행. 지리산 둘레길 2코스.\n다음엔 가족과 함께 가기로.",
               tags: ["등산"], with: [doyun])
        record("event", day(2024, 10, 18), title: nil, note: "세미나 뒤풀이\n데이터 시각화 이야기를 길게 했다.",
               location: "강남", with: [minjun])
        record("help", day(2026, 2, 3), title: "이력서 봐 주기", note: "포트폴리오 구성 조언.", with: [yujin])
        record("contact", day(2026, 10, 1), title: "안부 전화", note: nil, with: [jiwoo])

        // 아는 사이 (D-30) — 기록 없이 서로 아는 두 쌍.
        for (a, b) in [(doyun, minjun), (jiwoo, alice)] {
            let tie = Tie()
            context.insert(tie)
            tie.first = a
            tie.second = b
        }

        try? context.save()
        if LaunchArguments.current.communitySample { seedCommunities(into: context, doyun: doyun, jiwoo: jiwoo, alice: alice) }
        if LaunchArguments.current.largeSample { seedLarge(into: context) }
    }

    /// **모임 견본** (D-30) — 지어낸 15명을 다섯씩 세 모임으로, 모임 안은 아는 사이로 촘촘히, 모임 사이는 한 줄씩.
    /// 진한 선 20개 · 이어진 사람 10명을 넘겨 관계도에 모임 테두리가 그려지는지 찍는다.
    @MainActor
    static func seedCommunities(into context: ModelContext, doyun: Person, jiwoo: Person, alice: Person) {
        func make(_ names: [String], configure: (Person) -> Void) -> [Person] {
            names.map { name in
                let person = Person(name: name)
                configure(person)
                context.insert(person)
                return person
            }
        }
        let reading = make(["서지호", "문채원", "오하린", "신태오", "장윤슬"]) {
            $0.relationshipType = "지인"
            $0.metThrough = "동호회·모임"
            $0.tags = ["독서모임"]
        }
        let hiking = make(["배준서", "노은채", "류시온", "임도하", "홍지안"]) {
            $0.relationshipType = "친구"
            $0.metThrough = "동호회·모임"
            $0.tags = ["등산"]
        }
        let project = make(["송예준", "권나윤", "황서진", "안지후", "조이안"]) {
            $0.relationshipType = "고객"
            $0.metThrough = "프로젝트"
            $0.organization = "나비랩스"
        }
        // 다섯 명마다 고리 + 대각선 둘 = 7줄. 모임 사이는 한 줄씩.
        var pairs: [(Person, Person)] = []
        for group in [reading, hiking, project] {
            for i in 0..<5 { pairs.append((group[i], group[(i + 1) % 5])) }
            pairs.append((group[0], group[2]))
            pairs.append((group[1], group[3]))
        }
        pairs += [(hiking[0], doyun), (project[0], jiwoo), (project[1], alice), (reading[0], hiking[1])]
        for (a, b) in pairs {
            let tie = Tie()
            context.insert(tie)
            tie.first = a
            tie.second = b
        }
        try? context.save()
    }

    /// **큰 견본** — 사람 5,000명 · 기록 50,000건 (요구사항 8.5 를 하루 10명 입력 기준으로 올린 규모).
    /// 이름은 음절을 조합해 만든다 — 실제 사람이 아니다. 시드를 고정해 매번 같은 자료가 나온다.
    @MainActor
    static func seedLarge(into context: ModelContext) {
        let started = Date()
        var generator = SeededGenerator(seed: 20_261_017)
        let surnames = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "서", "신", "권"]
        let given = ["하늘", "도윤", "서연", "민준", "유진", "지우", "서아", "예준", "수빈", "지호", "다은", "현우", "시우", "채원", "준서", "하린"]
        let organizations = ["청림소프트", "한빛대학교", "마루디자인", "나비랩스", "푸른물류", "온새미로", "다온전자", "해솔병원", "별무리출판", "들꽃식품"]
        let types = RelationshipPresets.relationshipTypes
        let paths = RelationshipPresets.metThroughOptions
        let tagPool = ["멘토", "독서모임", "등산", "프로젝트A", "대학", "동네", "운동", "스터디"]
        let recordTypes = RecordType.all.map(\.key)
        let calendar = Calendar.current
        let today = DayNormalizer.noon(of: Date(), calendar: calendar)

        var people: [Person] = []
        people.reserveCapacity(5_000)
        for index in 0..<5_000 {
            let person = Person(name: surnames[Int(generator.next() % 15)] + given[Int(generator.next() % 16)] + (index < 100 ? "" : String(index)))
            person.organization = organizations[Int(generator.next() % 10)]
            person.relationshipType = types[Int(generator.next() % UInt64(types.count))]
            person.metThrough = paths[Int(generator.next() % UInt64(paths.count))]
            if generator.next() % 3 == 0 { person.tags = [tagPool[Int(generator.next() % 8)]] }
            if generator.next() % 2 == 0 {
                person.firstMetDate = calendar.date(byAdding: .day, value: -Int(generator.next() % 3_000), to: today)
                person.firstNote = "견본 첫 인연 메모 \(index)"
            }
            context.insert(person)
            people.append(person)
        }
        for index in 0..<50_000 {
            let anchor = people[Int(generator.next() % 5_000)]
            let record = Record(recordType: recordTypes[Int(generator.next() % UInt64(recordTypes.count))],
                                occurredAt: calendar.date(byAdding: .day, value: -Int(generator.next() % 1_500), to: today) ?? today,
                                title: index % 4 == 0 ? nil : "견본 기록 \(index)",
                                note: "견본 메모 \(index). 성능 측정용 자료다.")
            context.insert(record)
            if generator.next() % 5 == 0 {
                record.participants = [anchor, people[Int(generator.next() % 5_000)]]
            } else {
                record.participants = [anchor]
            }
        }
        try? context.save()
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        print("⏱ 큰 견본 채우기 \(elapsed)ms (사람 5,000 · 기록 50,000)")
    }

    /// 견본 명함 그림 — 지어낸 회사 · 사람 · 번호 · `example.com` 메일. CI 스크린샷과 글자 읽기 시험에 쓴다.
    /// 그림을 그리는 자리라 색은 `UIColor` 로 직접 적는다 (화면의 색 토큰 규칙은 SwiftUI 화면에 대한 것이다).
    static func renderCard(organization: String, name: String, role: String, phone: String, email: String) -> Data? {
        let size = CGSize(width: 1_050, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hex: 0xFBFAF6).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hex: 0x2F6B5E).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: size.height))
            func draw(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UInt32, y: CGFloat) {
                (text as NSString).draw(at: CGPoint(x: 90, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: size, weight: weight),
                    .foregroundColor: UIColor(hex: color),
                ])
            }
            draw(organization, size: 40, weight: .semibold, color: 0x2F6B5E, y: 70)
            draw(name, size: 88, weight: .bold, color: 0x14181D, y: 190)
            draw(role, size: 40, weight: .regular, color: 0x33414F, y: 310)
            draw("M. \(phone)", size: 36, weight: .regular, color: 0x33414F, y: 430)
            draw("E. \(email)", size: 36, weight: .regular, color: 0x33414F, y: 490)
        }
        return image.jpegData(compressionQuality: 0.85)
    }

    /// 시드 고정 난수 (SplitMix64). 같은 입력에 같은 견본 — CI 에서 수치를 비교할 수 있게.
    struct SeededGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}
