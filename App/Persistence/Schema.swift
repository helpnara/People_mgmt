import Foundation
import SwiftData

/// 스키마 **2판** — 지금 쓰는 판 (요구사항 6절 · FR-050).
///
/// 1판에서 **명함 사진 칸(`businessCard`) 하나만** 더했다. 나머지는 1판과 글자 하나 다르지 않아야 한다 —
/// 가벼운 옮기기(lightweight)가 그것을 전제로 한다. 칸을 또 바꾸면 `SchemaV3` 를 더하고 이 판은 얼린다.
///
/// **CloudKit 제약을 지킨다** (ADR-0001): 유니크 제약 없음 · 모든 속성 기본값 또는 옵셔널 · 모든 관계 옵셔널.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Person.self, Record.self] }

    /// 사람 (요구사항 6.1). 고유 식별자는 `uuid` — `PersistentModel` 이 `id` 를 이미 쓴다.
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
        /// 연락 수단 메모 (FR-032) — 전화 · 메일을 자유 글자로. 명함 · 연락처에서 채울 수 있다.
        var contactNote: String?
        var tags: [String] = []
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        /// 명함 사진 (FR-050 · 2판). JPEG, 긴 변 1,600px 이하. 저장소 밖 파일로 둔다 — 목록을 읽을 때 같이 올라오지 않게.
        @Attribute(.externalStorage)
        var businessCard: Data?

        /// 이 사람을 나에게 소개한 사람 (FR-043). 소개자를 지우면 비워진다(nullify).
        var introducedBy: Person?
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

    /// 관계 기록 (요구사항 6.2). 참여자 1명 이상에 속한다. 1판과 같다.
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

typealias Person = SchemaV2.Person
typealias Record = SchemaV2.Record

/// 판 사이의 이사 계획. 1판 → 2판은 칸 하나를 더하는 **가벼운 옮기기**다.
/// 실제 옮겨지는지는 `AppTests/MigrationTests.swift` 가 1판 저장소를 디스크에 만들어 연다.
enum SlowConnectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

extension PersistentModel {
    /// 지워졌거나 저장소에서 떨어진 객체인가. **스스로 지우는 화면은 본문 맨 위에서 이것을 본다** —
    /// 시트가 내려가는 순간 SwiftUI 가 한 번 더 그리는데, 그때 값을 읽으면 죽는다
    /// (느린 부자 189번 · CLAUDE.md).
    var isGone: Bool { isDeleted || modelContext == nil }
}

extension SchemaV2.Person {
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
