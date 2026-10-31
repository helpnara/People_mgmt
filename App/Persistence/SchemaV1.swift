import Foundation
import SwiftData

/// 스키마 **1판 — 얼려 둔다. 고치지 않는다** (빌드 2 · 3 의 저장소가 이 모양이다).
///
/// 2판으로 옮기는 원본이다. 여기를 고치면 이미 깔린 기기의 저장소가 어느 판인지 알아보지 못해
/// 열리지 않을 수 있다 (느린 부자 docs/18 — 옛 판은 지우지 않는다). 지금 쓰는 판은 `Schema.swift` 의 `SchemaV2`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Person.self, Record.self] }

    @Model
    final class Person {
        var uuid: UUID = UUID()
        var name: String = ""
        var nickname: String?
        var photoReference: String?
        var organization: String?
        var role: String?
        var relationshipType: String?
        var metThrough: String?
        var firstMetDate: Date?
        var firstNote: String?
        var contactNote: String?
        var tags: [String] = []
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var introducedBy: Person?
        @Relationship(inverse: \Person.introducedBy)
        var introduced: [Person]? = []
        @Relationship(inverse: \Record.participants)
        var records: [Record]? = []

        init(name: String) {
            self.uuid = UUID()
            self.name = name
            let now = Date()
            self.createdAt = now
            self.updatedAt = now
            self.tags = []
        }
    }

    @Model
    final class Record {
        var uuid: UUID = UUID()
        var title: String?
        var recordType: String = "conversation"
        var occurredAt: Date = Date()
        var location: String?
        var note: String?
        var tags: [String] = []
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var participants: [Person]? = []

        init(recordType: String = "conversation", occurredAt: Date = Date(), title: String? = nil, note: String? = nil) {
            self.uuid = UUID()
            self.recordType = recordType
            self.occurredAt = occurredAt
            self.title = title
            self.note = note
            let now = Date()
            self.createdAt = now
            self.updatedAt = now
            self.tags = []
        }
    }
}
