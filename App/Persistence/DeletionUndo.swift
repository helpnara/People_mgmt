import Core
import Foundation
import SwiftData
import SwiftUI

/// **삭제 실행취소** (FR-031 · D-53) — 사람 · 기록을 지운 직후 5초 동안 `되돌리기`.
///
/// 지우기 **전에** 지울 것을 값으로 떠 둔다(백업과 같은 값 · `Backup.item`) — 사람이면 그 사람, 함께 지워질 단독 기록,
/// 빠지기만 할 공동 기록, 아는 사이 연결, 이 사람을 소개자로 둔 사람들. 누르면 같은 `uuid` 로 다시 넣고 잇고 저장한다.
/// - 처음에는 저장소 문맥의 `UndoManager` 로 되돌렸다 — 아는 사이 연결을 되돌리는 순간 SwiftData 가 앱을 멈췄다
///   (`Unexpected backing data for snapshot creation` · 빌드 29 첫 CI). 값으로 떠 두면 SwiftData 의 되돌리기에 기대지 않는다.
/// - 5초가 지나거나 다른 삭제가 오면 떠 둔 값을 버린다. 되돌리기는 늘 가장 최근 삭제 하나다.
/// - 확인 창(모든 삭제에 확인 · CLAUDE.md)은 그대로 둔다. 실행취소는 확인 뒤의 실수를 위한 것이다.
@MainActor
@Observable
final class DeletionUndo {
    static let shared = DeletionUndo()
    static let window: Duration = .seconds(5)

    struct Pending: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    /// 지운 것의 값.
    private enum Snapshot {
        case person(person: BackupFile.PersonItem, soleRecords: [BackupFile.RecordItem], sharedRecords: [UUID],
                    ties: [BackupFile.TieItem], introduced: [UUID])
        case record(BackupFile.RecordItem)
    }

    /// 지금 띄울 알림. 없으면 nil.
    private(set) var pending: Pending?
    @ObservationIgnored private var snapshot: Snapshot?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var timer: Task<Void, Never>?

    /// 사람을 지운다(`PersonStore.delete` — 단독 기록은 함께, 공동 기록에서는 빠지기만). 실패하면 던지고 알림을 띄우지 않는다.
    func delete(_ person: Person, in context: ModelContext) throws {
        let name = person.name
        let records = person.records ?? []
        let sole = records.filter { ($0.participants ?? []).count <= 1 }.map { Backup.item(of: $0) }
        let shared = records.filter { ($0.participants ?? []).count > 1 }.map(\.uuid)
        let ties = ((person.tiesAsFirst ?? []) + (person.tiesAsSecond ?? [])).compactMap { Backup.item(of: $0) }
        let introduced = (person.introduced ?? []).filter { !$0.isGone }.map(\.uuid)
        let value = Snapshot.person(person: Backup.item(of: person), soleRecords: sole, sharedRecords: shared,
                                    ties: ties, introduced: introduced)
        try PersonStore(context: context).delete(person)
        show("'\(name)'\(Josa.eulReul(name)) 삭제했습니다", value, context)
    }

    /// 기록을 지운다(`RecordStore.delete` — 참여자는 남는다).
    func delete(_ record: Record, in context: ModelContext) throws {
        let title = record.displayTitle
        let value = Snapshot.record(Backup.item(of: record))
        try RecordStore(context: context).delete(record)
        show("'\(title)' 기록을 삭제했습니다", value, context)
    }

    /// 떠 둔 값으로 다시 넣고 저장한다. 되돌렸으면 true.
    @discardableResult
    func undo() -> Bool {
        defer { finish() }
        guard let snapshot, let context else { return false }
        do {
            switch snapshot {
            case let .person(item, soleRecords, sharedRecords, ties, introduced):
                let person = Person(name: item.name)
                context.insert(person)
                Backup.fill(person, from: item)
                person.isMe = item.isMe
                var known: [UUID: Person] = [item.uuid: person]
                func find(_ id: UUID) -> Person? {
                    if let hit = known[id] { return hit }
                    let found = try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.uuid == id })).first
                    known[id] = found
                    return found
                }
                if let introducer = item.introducedBy, introducer != item.uuid { person.introducedBy = find(introducer) }
                for record in soleRecords { insert(record, find: find, in: context) }
                for id in sharedRecords {
                    let found = try context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.uuid == id })).first
                    if let found, !(found.participants ?? []).contains(where: { $0 === person }) {
                        found.participants = (found.participants ?? []) + [person]
                    }
                }
                for tieItem in ties {
                    guard tieItem.first != tieItem.second, let a = find(tieItem.first), let b = find(tieItem.second) else { continue }
                    let tie = Tie(since: tieItem.since)
                    context.insert(tie)   // 넣고 나서 잇는다 (4판의 규칙).
                    tie.uuid = tieItem.uuid
                    tie.createdAt = tieItem.createdAt
                    tie.first = a
                    tie.second = b
                }
                for id in introduced {
                    if let other = find(id), other.introducedBy == nil { other.introducedBy = person }
                }
            case let .record(item):
                insert(item, find: { id in
                    try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.uuid == id })).first
                }, in: context)
            }
            try SaveFailure.check()
            try context.save()
            return true
        } catch {
            context.rollback()
            return false
        }
    }

    /// 떠 둔 값을 버리고 알림을 내린다.
    func finish() {
        timer?.cancel()
        timer = nil
        snapshot = nil
        context = nil
        pending = nil
    }

    private func insert(_ item: BackupFile.RecordItem, find: (UUID) -> Person?, in context: ModelContext) {
        let participants = item.participants.compactMap(find)
        guard !participants.isEmpty else { return }   // 참여자 없는 기록은 보이지 않는다 — 넣지 않는다.
        let record = Record(recordType: item.recordType, occurredAt: item.occurredAt, title: item.title, note: item.note)
        context.insert(record)
        Backup.fill(record, from: item)
        record.participants = participants
    }

    private func show(_ message: String, _ value: Snapshot, _ context: ModelContext) {
        finish()
        snapshot = value
        self.context = context
        pending = Pending(message: message)
        timer = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }
}

/// 화면 아래의 `되돌리기` 알림 — 뿌리 화면이 하나만 둔다.
struct DeletionUndoBanner: View {
    let undo: DeletionUndo

    var body: some View {
        if let pending = undo.pending {
            HStack(spacing: 12) {
                Text(pending.message)
                    .font(.scaled(15))
                    .foregroundStyle(Color.ink)
                    .readableLineLimit(2)
                Spacer(minLength: 8)
                Button {
                    withAnimation { _ = undo.undo() }
                } label: {
                    Text("되돌리기")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .tapTarget()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Color.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.rule, lineWidth: 1))
            .shadow(color: Color.ink.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(pending.id)
        }
    }
}
