import Core
import Foundation
import SwiftData

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

        let haneul = Person(name: "김하늘")
        haneul.organization = "청림소프트"
        haneul.role = "팀장"
        haneul.relationshipType = "동료"
        haneul.metThrough = "직장"
        haneul.firstMetDate = day(2019, 3, 4)
        haneul.firstNote = "입사 첫날 옆자리에 앉았다. 점심을 같이 먹으며 팀 분위기를 알려 주었다."
        haneul.tags = ["멘토", "독서모임"]

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

        try? context.save()
    }
}
