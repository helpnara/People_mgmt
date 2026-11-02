import Core
import Foundation

/// **앱의 검색 칸은 모두 같은 규칙이다** (빌드 43 · 1.1 · 이슈 64 · 2026-11-03 사용자) — 홈 · 함께한 사람 고르기 · 소개한 사람 고르기.
///
/// - 색인: `SearchIndexBuilder`(따로 연 문맥 · 주 스레드 밖)가 만든 `Core.SearchIndex` 하나 — 이름 · 별명 · 소속 · 직무 · 관계 유형 ·
///   알게 된 경로 · 첫 인연 메모 · **태그** · 기록의 제목 · 메모 · 장소 · 태그.
/// - 찾기: `Core.SearchMatcher` — 초성(`ㄱㅎㄴ` → 김하늘 · `ㄷㅅ` → #독서모임), 빈칸으로 나눈 낱말은 모두 맞아야(AND),
///   `#멘토` 는 태그만. 차례는 이름 → 태그 → 사람의 다른 칸 → 기록. 이름이 아닌 곳에서 맞으면 줄 아래에 근거를 쓴다.
/// - 때: 검색어가 멈춘 뒤 300ms 에 한 번, 견주기는 주 스레드 밖에서 (요구사항 5.3).
enum PeopleSearch {
    /// 모든 검색 칸의 안내 글.
    static let prompt = "이름 · 소속 · 메모 · 태그 · 초성"
    /// 검색어가 멈춘 뒤 기다리는 시간.
    static let debounce: Duration = .milliseconds(300)

    /// 고르기 창의 결과 — 색인에서 맞은 사람 가운데 이 창이 보여 줄 사람만(`people`), 같은 차례로. 근거는 이름 일치면 비운다.
    static func pick(_ hits: [SearchHit], from people: [Person]) -> (people: [Person], evidence: [UUID: String]) {
        let byID = Dictionary(people.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        var found: [Person] = []
        var evidence: [UUID: String] = [:]
        for hit in hits {
            guard let person = byID[hit.personID] else { continue }
            found.append(person)
            if hit.kind != .name { evidence[person.uuid] = hit.evidence }
        }
        return (found, evidence)
    }
}
