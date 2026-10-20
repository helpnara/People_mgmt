import Foundation
import SwiftData

/// 스키마 **4판 — 얼려 둔다. 고치지 않는다** (빌드 10 ~ 17 의 저장소가 이 모양이다).
///
/// 3판에서 **아는 사이 연결(`Tie`)** 과 사람 쪽 관계 둘(`tiesAsFirst` · `tiesAsSecond`)을 더한 판이다. 5판으로 옮기는 원본이다 —
/// 여기를 고치면 이미 깔린 기기의 저장소가 어느 판인지 알아보지 못해 열리지 않을 수 있다. 지금 쓰는 판은 `Schema.swift` 의 `SchemaV6`.
///
/// **CloudKit 제약을 지킨다** (ADR-0001): 유니크 제약 없음 · 모든 속성 기본값 또는 옵셔널 · 모든 관계 옵셔널.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] { [Person.self, Record.self, Tie.self] }

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
        /// **아는 사이** (4판 · D-30) — 기록 없이 서로 아는 사람. 이 사람이 `first` 인 연결과 `second` 인 연결.
        /// 사람을 지우면 그 사람의 연결도 지운다(cascade) — 상대 사람은 남는다.
        @Relationship(deleteRule: .cascade, inverse: \Tie.first)
        var tiesAsFirst: [Tie]? = []
        @Relationship(deleteRule: .cascade, inverse: \Tie.second)
        var tiesAsSecond: [Tie]? = []

        init(name: String) {
            self.uuid = UUID()
            self.name = name
            let now = Date()
            self.createdAt = now
            self.updatedAt = now
            self.tags = []
        }
    }

    /// 관계 기록 (요구사항 6.2). 참여자 1명 이상에 속한다. 1 ~ 3판과 같다.
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

    /// **아는 사이 한 줄** (4판 · D-30) — 두 사람이 서로 안다. 방향이 없다(`first` · `second` 는 저장 자리일 뿐).
    /// 사람 ↔ 사람을 바로 잇지 않고 이 객체를 두는 까닭: 다음 묶음(시점에 따른 변화)이 `언제부터 알았나` 를
    /// 연결마다 적는다 — 바로 이으면 그 칸을 둘 곳이 없어 저장 형식을 또 바꿔야 한다.
    @Model
    final class Tie {
        var uuid: UUID = UUID()
        /// 언제부터 알았나 (선택 · 다음 묶음에서 화면에 연다). 비우면 두 사람 중 늦게 만난 날을 쓴다.
        var since: Date?
        var createdAt: Date = Date()
        var first: Person?
        var second: Person?

        /// 관계는 저장소에 넣은 **뒤에** 잇는다 — 넣기 전에 이으면 SwiftData 가 다른 문맥의 객체로 볼 수 있다.
        init(since: Date? = nil) {
            self.uuid = UUID()
            self.createdAt = Date()
            self.since = since
        }
    }
}
