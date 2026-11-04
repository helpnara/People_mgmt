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
    /// 기록마다 날짜 · 정밀도 — 명단 줄에 그 사람의 날을 적을 때 (이슈 78).
    var recordDates: [UUID: RecordDate] = [:]

    struct RecordDate: Sendable {
        let date: Date
        let precision: Int
    }

    /// 사람의 흐름 명단 넷 — 셈과 함께 주 스레드 밖에서 만든다(본문에서 사람 전원을 훑지 않는다 · CLAUDE.md).
    struct Lists: Sendable {
        let together: PeopleListRoute
        let fresh: PeopleListRoute
        let returning: PeopleListRoute
        let resting: PeopleListRoute
    }

    /// 고를 수 있는 해 — 이른 해부터.
    var years: [Int] {
        YearInReview.years(records: records, people: people, today: today, currentYear: currentYear)
    }

    func summary(of year: Int) -> YearInReview.Summary {
        YearInReview.make(year: year, records: records, people: people, today: today)
    }

    /// 명단 넷 (이슈 78 · D-72) — 차례는 `Core.YearInReview` 그대로, 줄 끝에는 그 사람의 날(처음 · 마지막)을 정밀도대로.
    func lists(for summary: YearInReview.Summary) -> Lists {
        let year = String(summary.year) + "년 "
        func route(_ title: String, _ entries: [YearInReview.Entry], lead: String, footer: String) -> PeopleListRoute {
            var notes: [UUID: String] = [:]
            for entry in entries {
                guard let when = recordDates[entry.record] else { continue }
                notes[entry.id] = lead + " " + when.date.shown(precision: when.precision, style: .long)
            }
            return PeopleListRoute(title: year + title, ids: entries.map(\.id), notes: notes, footer: footer)
        }
        let previous = String(summary.year - 1) + "년"
        return Lists(
            together: route("함께한 사람", summary.together, lead: "마지막",
                            footer: "이름 순입니다. 날짜는 이 해에 마지막으로 함께한 기록의 날입니다."),
            fresh: route("새로 함께한 사람", summary.freshPeople, lead: "처음",
                         footer: "이 해에 처음 기록한 사람입니다. 처음 함께한 날이 이른 사람부터 놓습니다."),
            returning: route("다시 함께한 사람", summary.returningPeople, lead: "마지막",
                             footer: "그 앞 해에도 기록이 있던 사람입니다. 이 해에 마지막으로 함께한 날이 최근인 사람부터 놓습니다."),
            resting: route("쉬어 간 사람", summary.restingPeople, lead: "마지막",
                           footer: previous + "엔 함께했는데 이 해엔 기록이 없는 사람입니다. " + previous
                               + "에 마지막으로 함께한 날이 오래된 사람부터 놓습니다."))
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
        var dates: [UUID: RecordDate] = [:]
        for record in records { dates[record.uuid] = RecordDate(date: record.occurredAt, precision: record.occurredPrecision) }
        return YearReviewData(records: items, people: persons,
                              today: DayIndex.of(now, calendar: calendar),
                              currentYear: calendar.component(.year, from: now),
                              recordDates: dates)
    }
}
