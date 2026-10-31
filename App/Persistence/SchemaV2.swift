import Foundation
import SwiftData

/// 스키마 **2판 — 얼려 둔다. 고치지 않는다** (빌드 4 ~ 6 의 저장소가 이 모양이다).
///
/// 1판에서 명함 사진 칸(`businessCard`) 하나를 더한 판이다. 3판으로 옮기는 원본이다 —
/// 여기를 고치면 이미 깔린 기기의 저장소가 어느 판인지 알아보지 못해 열리지 않을 수 있다
/// (느린 부자 docs/18 — 옛 판은 지우지 않는다). 지금 쓰는 판은 `Schema.swift` 의 `SchemaV3`.
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
