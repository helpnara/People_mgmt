import Foundation
import SwiftData

/// **전체 데이터 삭제** (할 일 54 · 2026-10-30 사용자 — 출시 판에 넣는다).
///
/// - 사람(나 포함) · 기록 · 아는 사이를 모두 지운다. 명함 · 사람 사진은 사람에 붙어 함께 사라진다.
/// - **설정은 둔다** (사용자 결정) — 앱 잠금 · 알림 켜기 · 상세 화면 칸 · 정렬은 그대로. 걸어 둔 알림만 다시 걸어 비운다
///   (지운 사람의 생일 알림이 오지 않게 — 부르는 쪽이 `ReminderScheduler.refresh`).
/// - 하나씩 지운다 — 한꺼번에 지우기(batch)는 iCloud 로 지움이 건너가지 않을 수 있다. 동기화가 켜져 있으면
///   같은 Apple 계정의 다른 기기와 iCloud 에서도 지워진다(확인 창이 먼저 말한다).
/// - 주 스레드 밖의 저장소 그릇에서 한다 (`Backup.restore` 와 같은 길). 저장에 실패하면 되돌리고 던진다 — 반쯤 지운 채 두지 않는다.
enum DataWipe {
    struct Counts: Equatable, Sendable {
        var people = 0
        var records = 0
        var ties = 0

        var isEmpty: Bool { people == 0 && records == 0 && ties == 0 }
    }

    /// 확인 창에 쓸 수 — 단추를 누를 때 한 번 센다(본문에서 세지 않는다).
    static func counts(in context: ModelContext) -> Counts {
        Counts(people: (try? context.fetchCount(FetchDescriptor<Person>())) ?? 0,
               records: (try? context.fetchCount(FetchDescriptor<Record>())) ?? 0,
               ties: (try? context.fetchCount(FetchDescriptor<Tie>())) ?? 0)
    }

    static func wipe(container: ModelContainer) async throws -> Counts {
        // 저장 실패 시험(`-failSaves`)은 주 스레드의 값이라 여기서 본다 — 실패하면 하나도 지우지 않는다.
        try await SaveFailure.check()
        return try await Task.detached(priority: .userInitiated) {
            try wipe(into: ModelContext(container))
        }.value
    }

    static func wipe(into context: ModelContext) throws -> Counts {
        let ties = try context.fetch(FetchDescriptor<Tie>())
        let records = try context.fetch(FetchDescriptor<Record>())
        let people = try context.fetch(FetchDescriptor<Person>())
        // 아는 사이 · 기록을 먼저 — 사람을 지울 때 이어진 것을 따로 정리하지 않게.
        for tie in ties { context.delete(tie) }
        for record in records { context.delete(record) }
        for person in people {
            person.introducedBy = nil
            context.delete(person)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return Counts(people: people.count, records: records.count, ties: ties.count)
    }
}
