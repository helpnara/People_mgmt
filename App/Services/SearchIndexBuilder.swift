import Core
import Foundation
import SwiftData

/// **검색 색인을 주 스레드 밖에서** 만든다 (이슈 8).
///
/// 빌드 4~10 은 첫 검색 때 주 스레드에서 사람 · 기록 관계를 처음 읽으며 색인을 만들었다 — 5,000명 · 50,000건에서
/// 9.7~18초 동안 화면이 멈췄다. 인맥 자료(`NetworkSnapshotBuilder`)처럼 **따로 연 문맥**에서 관계를 미리 읽어
/// 값(`SearchIndex`)으로 만든다. 목록은 앱이 뜬 뒤 · 저장한 뒤 잠깐 쉬었다가 미리 만들어 둔다.
enum SearchIndexBuilder {
    static func build(container: ModelContainer) async -> SearchIndex {
        await Task.detached(priority: .utility) {
            LaunchTiming.measure("검색 색인 만들기 (주 스레드 밖)") { make(container: container) }
        }.value
    }

    private static func make(container: ModelContainer) -> SearchIndex {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false })
        // 기록을 미리 읽는다 — 사람마다 따로 읽으면 5,000번이다.
        descriptor.relationshipKeyPathsForPrefetching = [\.records]
        let people = (try? context.fetch(descriptor)) ?? []
        return SearchIndex(people.map { SearchablePerson(person: $0) })
    }
}
