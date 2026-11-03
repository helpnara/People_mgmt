import Core
import Foundation
import SwiftData

/// **한 해 돌아보기의 재료** (FR-059 · D-67) — 기록 · 사람을 따로 연 문맥에서 한 번 읽어 날 번호 · 해 · 달로 바꿔 둔다.
/// 해를 바꿀 때는 이 값으로 다시 센다(`YearInReview.make`) — 저장소를 다시 읽지 않는다. 화면 본문에서 읽지 않는다(CLAUDE.md).
struct YearReviewData: Sendable {
    let records: [YearInReview.Record]
    let people: [YearInReview.Person]
    let today: Int
    let currentYear: Int

    /// 고를 수 있는 해 — 이른 해부터.
    var years: [Int] {
        YearInReview.years(records: records, people: people, today: today, currentYear: currentYear)
    }

    func summary(of year: Int) -> YearInReview.Summary {
        YearInReview.make(year: year, records: records, people: people, today: today)
    }

    static func build(container: ModelContainer, now: Date = Date()) async -> YearReviewData {
        await Task.detached(priority: .userInitiated) {
            make(context: ModelContext(container), now: now)
        }.value
    }

    static func make(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> YearReviewData {
        // 함께한 사람을 미리 읽는다 — 기록마다 따로 읽으면 기록 수만큼이다 (이슈 15).
        var recordDescriptor = FetchDescriptor<Record>()
        recordDescriptor.relationshipKeyPathsForPrefetching = [\.participants]
        let records = (try? context.fetch(recordDescriptor)) ?? []
        let people = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? []

        let items = records.map { record -> YearInReview.Record in
            let parts = calendar.dateComponents([.year, .month], from: record.occurredAt)
            let precision = DatePrecision.of(record.occurredPrecision)
            return YearInReview.Record(
                id: record.uuid,
                day: DayIndex.of(record.occurredAt, calendar: calendar),
                year: parts.year ?? 0,
                month: precision == .year ? nil : parts.month,
                type: RecordType.named(record.recordType).key,
                participants: (record.participants ?? []).filter { !$0.isMe }.map(\.uuid))
        }
        let persons = people.map { person in
            YearInReview.Person(
                id: person.uuid,
                firstMetDay: person.firstMetDate.map { DayIndex.of($0, calendar: calendar) },
                firstMetYear: person.firstMetDate.map { calendar.component(.year, from: $0) },
                sortKey: NameSort.key(person.name))
        }
        return YearReviewData(records: items, people: persons,
                              today: DayIndex.of(now, calendar: calendar),
                              currentYear: calendar.component(.year, from: now))
    }
}
