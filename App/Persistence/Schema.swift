import Core
import Foundation
import SwiftData

/// 스키마 **5판** — 지금 쓰는 판 (요구사항 6절 · D-40 · 빌드 18).
///
/// 4판에서 사람에 **생일(월 · 일 · 선택 연도)** 과 **연락 주기(개월)** 칸 넷을 더했다 — 모두 옵셔널이라 가벼운 옮기기.
/// 나머지는 4판과 글자 하나 다르지 않아야 한다. 칸을 또 바꾸면 `SchemaV6` 를 더하고 이 판은 얼린다.
///
/// **CloudKit 제약을 지킨다** (ADR-0001): 유니크 제약 없음 · 모든 속성 기본값 또는 옵셔널 · 모든 관계 옵셔널.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
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
        /// 생일 (5판 · D-40) — 월 · 일. 둘 다 있어야 뜻이 있다. 연도는 모를 때가 많아 따로 둔다.
        var birthMonth: Int?
        var birthDay: Int?
        /// 태어난 해 (선택).
        var birthYear: Int?
        /// 연락 주기 (5판 · D-40) — 고른 사람만. 이 개월 수만큼 기록이 없으면 한 번 알린다. 비우면 알리지 않는다.
        var contactCadenceMonths: Int?

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

typealias Person = SchemaV5.Person
typealias Record = SchemaV5.Record
typealias Tie = SchemaV5.Tie

/// 판 사이의 이사 계획.
/// - 1판 → 2판: 칸 하나를 더하는 **가벼운 옮기기**
/// - 3판 → 4판: 아는 사이 연결을 더하는 가벼운 옮기기 (D-30)
/// - 4판 → 5판: 생일 · 연락 주기 칸을 더하는 가벼운 옮기기 (D-40)
/// - 2판 → 3판: 칸을 더하고(가벼운 옮기기와 같다), 옮긴 뒤 **한 칸에 들어 있던 연락 수단을 네 칸으로 나눈다** (이슈 11).
///   나누지 못한 글은 기타(`contactNote`)에 그대로 남는다 — 잃는 글이 없다. 이미 네 칸 중 하나라도 찬 사람은 건드리지 않는다.
///
/// 실제 옮겨지는지는 `AppTests/MigrationTests.swift` 가 1판 · 2판 저장소를 디스크에 만들어 연다.
enum SlowConnectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .custom(fromVersion: SchemaV2.self, toVersion: SchemaV3.self, willMigrate: nil, didMigrate: { context in
                ContactMigration.splitContactNotes(in: context)
            }),
            // 3판 → 4판: 연결 객체와 관계를 더할 뿐 — 가벼운 옮기기.
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            // 4판 → 5판: 사람에 옵셔널 칸 넷(생일 · 연락 주기)을 더할 뿐 — 가벼운 옮기기 (D-40).
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
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

extension SchemaV5.Person {
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

    /// 아는 사이 (D-30) — 두 방향의 연결을 합친 사람들. 지운 사람 · 겹침은 뺀다.
    var acquaintances: [Person] {
        var seen = Set<PersistentIdentifier>()
        let others = (tiesAsFirst ?? []).compactMap(\.second) + (tiesAsSecond ?? []).compactMap(\.first)
        return others.filter { !$0.isGone && $0 !== self && seen.insert($0.persistentModelID).inserted }
    }

    /// 마지막 기록일 (FR-040). 저장하지 않고 기록에서 센다.
    ///
    /// **오늘까지의 기록만** 본다 (전수조사 이슈 20). 예정된 만남(앞날짜 기록, D-11)을 넣으면 목록은
    /// `마지막 기록 5일 후` 라고 쓰면서 돌아보기 · 관계 돌아보기(오늘까지만 셈)는 `6개월 넘게 기록 없음` 이라 해
    /// 같은 사람을 두고 말이 달랐다. 앞날짜 기록만 있는 사람은 아직 기록이 없는 사람으로 본다.
    var lastRecordAt: Date? {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return (records ?? []).map(\.occurredAt).filter { $0 < endOfToday }.max()
    }
}
