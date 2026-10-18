import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// **백업 · 복원** (FR-018 · D-34) — 사람 · 기록 · 아는 사이 · 명함 사진을 **파일 하나(.json)** 로.
///
/// - 고유 식별자(`uuid`)와 만든 날을 그대로 담아, 복원하면 소개 관계 · 함께한 사람 · 아는 사이가 그대로 이어진다.
/// - 명함 사진은 JSON 안에 base64 로 들어간다 — 사람이 많으면 파일이 커진다(명함 1장에 수백 KB).
/// - **복원은 앱이 비어 있을 때만** (D-34) — 지금 자료와 섞이지 않게. 새 기기 · 다시 설치한 뒤에 쓴다.
/// - 만들기 · 복원 모두 **따로 연 문맥**에서 한다 — 사람 5,000명 · 기록 50,000건이어도 주 스레드를 막지 않는다 (이슈 8 · 10).
/// - 사람을 고치는 문은 `PersonStore` 하나지만(CLAUDE.md), 복원은 식별자와 만든 날을 그대로 살려야 해서
///   스키마 이사 · 견본 채우기처럼 모델에 직접 쓴다 — 예외는 이 파일 하나.
struct BackupFile: Codable, Sendable {
    static let format = "slow-connection-backup"
    static let currentVersion = 1

    struct PersonItem: Codable, Sendable {
        var uuid: UUID
        var name: String
        var nickname: String?
        var organization: String?
        var role: String?
        var relationshipType: String?
        var metThrough: String?
        var introducedBy: UUID?
        var firstMetDate: Date?
        var firstNote: String?
        var contactNote: String?
        var mobilePhone: String?
        var officePhone: String?
        var faxNumber: String?
        var email: String?
        var isMe: Bool
        var tags: [String]
        var createdAt: Date
        var updatedAt: Date
        var businessCard: Data?
    }

    struct RecordItem: Codable, Sendable {
        var uuid: UUID
        var title: String?
        var recordType: String
        var occurredAt: Date
        var location: String?
        var note: String?
        var tags: [String]
        var participants: [UUID]
        var createdAt: Date
        var updatedAt: Date
    }

    struct TieItem: Codable, Sendable {
        var uuid: UUID
        var first: UUID
        var second: UUID
        var since: Date?
        var createdAt: Date
    }

    var format: String
    var version: Int
    var exportedAt: Date
    var people: [PersonItem]
    var records: [RecordItem]
    var ties: [TieItem]
}

enum Backup {
    enum Failure: LocalizedError, Equatable {
        case notBackup
        case newerVersion(Int)
        case notEmpty

        var errorDescription: String? {
            switch self {
            case .notBackup:
                return "느린 인연의 백업 파일이 아닙니다. 설정의 백업 파일 만들기로 만든 .json 파일을 골라 주세요."
            case .newerVersion(let version):
                return "더 새로운 앱에서 만든 백업입니다 (형식 \(version)). 앱을 최신으로 올린 뒤 다시 시도해 주세요."
            case .notEmpty:
                return "앱에 사람이나 기록이 있으면 복원할 수 없습니다 — 지금 자료와 섞이지 않게 하려는 것입니다. 새 기기나 다시 설치한 뒤에 복원해 주세요."
            }
        }
    }

    struct Summary: Sendable, Equatable {
        let people: Int
        let records: Int
        let ties: Int
        let cards: Int
    }

    /// 파일 이름 — `느린인연-백업-2026-10-18.json`.
    static func fileName(now: Date = Date()) -> String {
        let day = now.formatted(.iso8601.year().month().day())
        return "느린인연-백업-\(day)"
    }

    // MARK: - 만들기

    /// 저장소 전체를 백업 파일 내용으로 — 주 스레드 밖에서.
    static func export(container: ModelContainer, now: Date = Date()) async throws -> (data: Data, summary: Summary) {
        try await Task.detached(priority: .userInitiated) {
            let file = makeFile(context: ModelContext(container), now: now)
            let data = try encode(file)
            return (data, summary(of: file))
        }.value
    }

    static func makeFile(context: ModelContext, now: Date = Date()) -> BackupFile {
        var peopleDescriptor = FetchDescriptor<Person>()
        peopleDescriptor.relationshipKeyPathsForPrefetching = [\.introducedBy]
        let people = (try? context.fetch(peopleDescriptor)) ?? []
        var recordDescriptor = FetchDescriptor<Record>()
        recordDescriptor.relationshipKeyPathsForPrefetching = [\.participants]
        let records = (try? context.fetch(recordDescriptor)) ?? []
        var tieDescriptor = FetchDescriptor<Tie>()
        tieDescriptor.relationshipKeyPathsForPrefetching = [\.first, \.second]
        let ties = (try? context.fetch(tieDescriptor)) ?? []

        return BackupFile(
            format: BackupFile.format,
            version: BackupFile.currentVersion,
            exportedAt: now,
            people: people.map { p in
                BackupFile.PersonItem(
                    uuid: p.uuid, name: p.name, nickname: p.nickname, organization: p.organization, role: p.role,
                    relationshipType: p.relationshipType, metThrough: p.metThrough, introducedBy: p.introducedBy?.uuid,
                    firstMetDate: p.firstMetDate, firstNote: p.firstNote, contactNote: p.contactNote,
                    mobilePhone: p.mobilePhone, officePhone: p.officePhone, faxNumber: p.faxNumber, email: p.email,
                    isMe: p.isMe, tags: p.tags, createdAt: p.createdAt, updatedAt: p.updatedAt, businessCard: p.businessCard)
            },
            records: records.map { r in
                BackupFile.RecordItem(
                    uuid: r.uuid, title: r.title, recordType: r.recordType, occurredAt: r.occurredAt,
                    location: r.location, note: r.note, tags: r.tags, participants: (r.participants ?? []).map(\.uuid),
                    createdAt: r.createdAt, updatedAt: r.updatedAt)
            },
            ties: ties.compactMap { t in
                guard let a = t.first?.uuid, let b = t.second?.uuid else { return nil }
                return BackupFile.TieItem(uuid: t.uuid, first: a, second: b, since: t.since, createdAt: t.createdAt)
            })
    }

    static func summary(of file: BackupFile) -> Summary {
        Summary(people: file.people.count, records: file.records.count, ties: file.ties.count,
                cards: file.people.filter { $0.businessCard != nil }.count)
    }

    // MARK: - 글로 · 글에서

    /// 날짜는 ISO 8601 (천분의 1초까지) — 사람이 열어 봐도 읽힌다.
    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            return try Date(text, strategy: Date.ISO8601FormatStyle())
        }
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw Failure.notBackup
        }
        guard file.format == BackupFile.format else { throw Failure.notBackup }
        guard file.version <= BackupFile.currentVersion else { throw Failure.newerVersion(file.version) }
        return file
    }

    // MARK: - 복원

    /// 비어 있는 저장소에만 복원한다 (D-34). 주 스레드 밖 · 한 번에 저장 · 실패하면 아무것도 남기지 않는다.
    static func restore(_ file: BackupFile, container: ModelContainer) async throws -> Summary {
        try await Task.detached(priority: .userInitiated) {
            try restore(file, into: ModelContext(container))
        }.value
    }

    static func restore(_ file: BackupFile, into context: ModelContext) throws -> Summary {
        let existingPeople = (try? context.fetchCount(FetchDescriptor<Person>())) ?? 0
        let existingRecords = (try? context.fetchCount(FetchDescriptor<Record>())) ?? 0
        guard existingPeople == 0 && existingRecords == 0 else { throw Failure.notEmpty }

        var byID: [UUID: Person] = [:]
        var hasMe = false
        for item in file.people where byID[item.uuid] == nil {
            let person = Person(name: item.name)
            context.insert(person)
            person.uuid = item.uuid
            person.nickname = item.nickname
            person.organization = item.organization
            person.role = item.role
            person.relationshipType = item.relationshipType
            person.metThrough = item.metThrough
            person.firstMetDate = item.firstMetDate
            person.firstNote = item.firstNote
            person.contactNote = item.contactNote
            person.mobilePhone = item.mobilePhone
            person.officePhone = item.officePhone
            person.faxNumber = item.faxNumber
            person.email = item.email
            // 나는 하나뿐이다 (이슈 12) — 백업에 둘이 있으면 앞의 하나만.
            person.isMe = item.isMe && !hasMe
            if person.isMe { hasMe = true }
            person.tags = item.tags
            person.createdAt = item.createdAt
            person.updatedAt = item.updatedAt
            person.businessCard = item.businessCard
            byID[item.uuid] = person
        }
        // 소개 관계는 사람을 다 넣은 뒤에 잇는다. 자기 자신 · 없는 사람은 잇지 않는다.
        for item in file.people {
            guard let introducer = item.introducedBy, introducer != item.uuid,
                  let person = byID[item.uuid], let other = byID[introducer] else { continue }
            person.introducedBy = other
        }
        var restoredRecords = 0
        var seenRecords = Set<UUID>()
        for item in file.records where seenRecords.insert(item.uuid).inserted {
            let participants = item.participants.compactMap { byID[$0] }
            guard !participants.isEmpty else { continue }   // 참여자 없는 기록은 보이지 않는다 — 넣지 않는다.
            let record = Record(recordType: item.recordType, occurredAt: item.occurredAt, title: item.title, note: item.note)
            context.insert(record)
            record.uuid = item.uuid
            record.location = item.location
            record.tags = item.tags
            record.createdAt = item.createdAt
            record.updatedAt = item.updatedAt
            record.participants = participants
            restoredRecords += 1
        }
        var restoredTies = 0
        var seenPairs = Set<[UUID]>()
        for item in file.ties {
            guard item.first != item.second, let a = byID[item.first], let b = byID[item.second] else { continue }
            guard seenPairs.insert([item.first, item.second].sorted { $0.uuidString < $1.uuidString }).inserted else { continue }
            let tie = Tie(since: item.since)
            context.insert(tie)   // 넣고 나서 잇는다 (스키마 4판의 규칙).
            tie.uuid = item.uuid
            tie.createdAt = item.createdAt
            tie.first = a
            tie.second = b
            restoredTies += 1
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return Summary(people: byID.count, records: restoredRecords, ties: restoredTies,
                       cards: byID.values.filter { $0.businessCard != nil }.count)
    }
}

/// 파일 앱에 저장할 때 넘기는 문서 — 내용은 이미 만든 JSON 바이트.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
