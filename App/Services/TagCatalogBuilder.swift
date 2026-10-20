import Core
import Foundation
import SwiftData

/// **태그 모음을 주 스레드 밖에서** 만든다 (FR-026) — 검색 색인(`SearchIndexBuilder`)과 같은 까닭.
/// 사람 · 기록의 태그만 읽어 값(`TagCatalog`)으로 넘긴다. 입력 화면이 열릴 때 · 태그 화면이 열릴 때 만든다.
enum TagCatalogBuilder {
    static func build(container: ModelContainer) async -> TagCatalog {
        await Task.detached(priority: .utility) {
            LaunchTiming.measure("태그 모음 만들기 (주 스레드 밖)") { make(container: container) }
        }.value
    }

    private static func make(container: ModelContainer) -> TagCatalog {
        let context = ModelContext(container)
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let records = (try? context.fetch(FetchDescriptor<Record>())) ?? []
        return TagCatalog(personTags: people.map(\.tags), recordTags: records.map(\.tags))
    }
}
