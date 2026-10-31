import Core
import Foundation
import SwiftData

/// 태그 이름 바꾸기 · 합치기의 **유일한 문** (FR-026). 사람과 기록의 태그를 한 번에 바꾸고 한 번에 저장한다.
/// 규칙은 `Core.TagCatalog.renamed` 하나 — 이미 있는 태그로 바꾸면 합쳐진다.
@MainActor
struct TagStore {
    let context: ModelContext

    /// 바꾼 사람 수 · 기록 수.
    struct Result: Equatable {
        let people: Int
        let records: Int
    }

    /// 실패하면 옛 값을 되돌려 쓴다 — `PersonStore.apply` 와 같은 까닭 (`rollback()` 은 바뀐 칸을 되돌리지 않았다).
    @discardableResult
    func rename(_ from: String, to: String) throws -> Result {
        guard let key = TagNormalizer.key(from), TagNormalizer.normalize(to) != nil else { return Result(people: 0, records: 0) }
        let now = Date()
        var undoPeople: [(Person, [String], Date)] = []
        var undoRecords: [(Record, [String], Date)] = []
        for person in try context.fetch(FetchDescriptor<Person>()) where person.tags.contains(where: { TagNormalizer.key($0) == key }) {
            undoPeople.append((person, person.tags, person.updatedAt))
            person.tags = TagCatalog.renamed(person.tags, from: from, to: to)
            person.updatedAt = now
        }
        for record in try context.fetch(FetchDescriptor<Record>()) where record.tags.contains(where: { TagNormalizer.key($0) == key }) {
            undoRecords.append((record, record.tags, record.updatedAt))
            record.tags = TagCatalog.renamed(record.tags, from: from, to: to)
            record.updatedAt = now
        }
        guard !undoPeople.isEmpty || !undoRecords.isEmpty else { return Result(people: 0, records: 0) }
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            for (person, tags, updatedAt) in undoPeople {
                person.tags = tags
                person.updatedAt = updatedAt
            }
            for (record, tags, updatedAt) in undoRecords {
                record.tags = tags
                record.updatedAt = updatedAt
            }
            context.rollback()
            throw error
        }
        return Result(people: undoPeople.count, records: undoRecords.count)
    }
}
