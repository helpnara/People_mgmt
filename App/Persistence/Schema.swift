import Core
import Foundation
import SwiftData

/// 스키마 **3판** — 지금 쓰는 판 (요구사항 6절 · FR-032 · 이슈 11 · 12).
///
/// 2판에서 **연락 수단 네 칸**(휴대전화 · 사무실 전화 · 팩스 · 이메일)과 **나 표시(`isMe`)** 를 더했다.
/// 나머지는 2판과 글자 하나 다르지 않아야 한다. 칸을 또 바꾸면 `SchemaV4` 를 더하고 이 판은 얼린다.
///
/// **CloudKit 제약을 지킨다** (ADR-0001): 유니크 제약 없음 · 모든 속성 기본값 또는 옵셔널 · 모든 관계 옵셔널.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
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
        /// 연락 수단 **기타** (FR-032) — 네 칸에 들지 않는 번호 · 메일 · 메모를 자유 글자로.
        /// 2판까지는 전화 · 메일을 전부 이 한 칸에 담았다 — 3판으로 옮길 때 네 칸으로 나눈다 (이슈 11).
        var contactNote: String?
        /// 휴대전화 (3판 · 이슈 11).
        var mobilePhone: String?
        /// 사무실 전화 (3판).
        var officePhone: String?
        /// 팩스 (3판).
        var faxNumber: String?
        /// 이메일 (3판).
        var email: String?
        /// **나** (3판 · 이슈 12). 목록 맨 위에 따로 서고, 사람 수 · 검색 · 정렬 · 고르기에서 빠진다.
        /// 기록의 참여자가 되지 않는다 — 모든 기록에 나는 늘 있다 (2026-10-18 사용자 결정).
        var isMe: Bool = false
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

    /// 관계 기록 (요구사항 6.2). 참여자 1명 이상에 속한다. 1 · 2판과 같다.
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

typealias Person = SchemaV3.Person
typealias Record = SchemaV3.Record

/// 판 사이의 이사 계획.
/// - 1판 → 2판: 칸 하나를 더하는 **가벼운 옮기기**
/// - 2판 → 3판: 칸을 더하고(가벼운 옮기기와 같다), 옮긴 뒤 **한 칸에 들어 있던 연락 수단을 네 칸으로 나눈다** (이슈 11).
///   나누지 못한 글은 기타(`contactNote`)에 그대로 남는다 — 잃는 글이 없다. 이미 네 칸 중 하나라도 찬 사람은 건드리지 않는다.
///
/// 실제 옮겨지는지는 `AppTests/MigrationTests.swift` 가 1판 · 2판 저장소를 디스크에 만들어 연다.
enum SlowConnectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .custom(fromVersion: SchemaV2.self, toVersion: SchemaV3.self, willMigrate: nil, didMigrate: { context in
                ContactMigration.splitContactNotes(in: context)
            }),
        ]
    }
}

/// 2판 → 3판에서 연락 수단 한 칸을 네 칸으로 (이슈 11). 규칙은 `Core.ContactSorter.split` 하나다.
enum ContactMigration {
    /// 저장에 실패해도 던지지 않는다 — 저장소가 열리지 않는 것보다 나누지 못한 채 여는 편이 낫다.
    /// 이때 글은 기타 칸에 그대로 있다.
    static func splitContactNotes(in context: ModelContext) {
        guard let people = try? context.fetch(FetchDescriptor<SchemaV3.Person>()) else { return }
        var changed = false
        for person in people {
            guard let note = person.contactNote, !note.isEmpty,
                  person.mobilePhone == nil, person.officePhone == nil, person.faxNumber == nil, person.email == nil
            else { continue }
            let fields = ContactSorter.split(note)
            person.mobilePhone = fields.mobile.isEmpty ? nil : fields.mobile
            person.officePhone = fields.office.isEmpty ? nil : fields.office
            person.faxNumber = fields.fax.isEmpty ? nil : fields.fax
            person.email = fields.email.isEmpty ? nil : fields.email
            person.contactNote = fields.other.isEmpty ? nil : fields.other
            changed = true
        }
        if changed { try? context.save() }
    }
}

extension PersistentModel {
    /// 지워졌거나 저장소에서 떨어진 객체인가. **스스로 지우는 화면은 본문 맨 위에서 이것을 본다** —
    /// 시트가 내려가는 순간 SwiftUI 가 한 번 더 그리는데, 그때 값을 읽으면 죽는다
    /// (느린 부자 189번 · CLAUDE.md).
    var isGone: Bool { isDeleted || modelContext == nil }
}

extension SchemaV3.Person {
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
