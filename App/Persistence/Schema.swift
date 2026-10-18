import Foundation
import SwiftData

/// 스키마 1판 (요구사항 6절). 칸을 바꾸는 판부터는 `SchemaV2` 를 더하고 **이 판은 지우지 않는다** —
/// 마이그레이션의 원본이다 (느린 부자 docs/18).
///
/// **CloudKit 제약을 첫 판부터 지킨다** (ADR-0001): 유니크 제약 없음 · 모든 속성에 기본값 또는
/// 옵셔널 · 모든 관계 옵셔널. 지금은 동기화를 켜지 않지만, 나중에 켤 때 스키마를 다시 만들지
/// 않으려면 처음부터 이렇게 둬야 한다.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Person.self, Record.self] }

    /// 사람 (요구사항 6.1). 앱의 중심 객체.
    ///
    /// 고유 식별자는 `uuid` 다. `id` 라고 짓지 않는 이유는 `PersistentModel` 이 이미
    /// `id`(저장소 식별자)를 갖고 있어서 — 설계서의 `id` 가 코드에서는 `uuid` 다.
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
        /// 날짜만 뜻이 있다. 저장할 때 그날 정오로 맞춘다 (요구사항 7.3).
        var firstMetDate: Date?
        var firstNote: String?
        var contactNote: String?
        var tags: [String] = []
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        /// 이 사람을 나에게 소개한 사람 (FR-043). 소개자를 지우면 비워진다(nullify).
        var introducedBy: Person?
        /// 이 사람이 소개한 사람들 — `introducedBy` 의 역방향.
        @Relationship(inverse: \Person.introducedBy)
        var introduced: [Person]? = []
        /// 참여한 기록 — `Record.participants` 의 역방향 (N:M, FR-042).
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

    /// 관계 기록 (요구사항 6.2). 참여자 1명 이상에 속한다.
    @Model
    final class Record {
        var uuid: UUID = UUID()
        var title: String?
        var recordType: String = "conversation"
        /// 날짜만 뜻이 있다. 그날 정오. 미래 허용 (D-11).
        var occurredAt: Date = Date()
        var location: String?
        var note: String?
        var tags: [String] = []
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        /// 함께한 사람들. 저장 규칙상 1명 이상이지만 CloudKit 제약 때문에 옵셔널이다.
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

typealias Person = SchemaV1.Person
typealias Record = SchemaV1.Record

/// 판 사이의 이사 계획. 1판뿐이라 단계가 없다 — 2판이 생기면 여기에 `MigrationStage` 를 더한다.
enum SlowConnectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension PersistentModel {
    /// 지워졌거나 저장소에서 떨어진 객체인가. **스스로 지우는 화면은 본문 맨 위에서 이것을 본다** —
    /// 시트가 내려가는 순간 SwiftUI 가 한 번 더 그리는데, 그때 값을 읽으면 죽는다
    /// (느린 부자 189번 · CLAUDE.md).
    var isGone: Bool { isDeleted || modelContext == nil }
}

extension SchemaV1.Person {
    /// 목록 보조 정보 (요구사항 6.1 `subtitle`): 소속 · 직무, 둘 다 없으면 관계 유형.
    var subtitle: String? {
        let parts = [organization, role].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " · ") }
        if let relationshipType, !relationshipType.isEmpty { return relationshipType }
        return nil
    }

    var hasFirstEncounter: Bool {
        firstMetDate != nil || !(firstNote ?? "").isEmpty
    }

    /// 마지막 기록일 (FR-040). 저장하지 않고 기록에서 센다.
    var lastRecordAt: Date? {
        (records ?? []).map(\.occurredAt).max()
    }
}
