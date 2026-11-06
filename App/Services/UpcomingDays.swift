import Core
import Foundation
import SwiftData

/// **다가오는 날** (1.1.8 · 이슈 93 · FR-068 · 이슈 86 · FR-061) — 생일 · 기념일 가운데 오늘부터 며칠 안에 오는 것.
///
/// 홈의 다가오는 날 칸 · 모두 보기, 만나기 전에 칸이 같이 쓴다. 날 셈은 Core 의 `CivilDate.nextOccurrence` · `dayNumber`
/// (알림 계획과 같은 규칙 · 2월 29일은 평년에 2월 28일) — 여기서 새로 세지 않는다.
/// 알림을 끈 생일 · 기념일도 **보이기는 한다** — 끈 것은 알림이지 날이 아니다.
struct UpcomingDay: Identifiable {
    enum Kind { case birthday, special }

    /// `birthday|사람` · `special|기념일` — 같은 날이 두 번 서지 않게.
    let id: String
    let kind: Kind
    let person: Person
    let date: CivilDate
    /// 오늘부터 며칠 뒤 (0 = 오늘).
    let daysAway: Int
    /// `생일` · `결혼기념일`(비면 `기념일`).
    let label: String
    /// 기념일의 해를 알면 그해로 몇 주년.
    let years: Int?

    /// `결혼기념일 8주년` · `생일`.
    var title: String {
        if let years, years >= 1 { return "\(label) \(years)주년" }
        return label
    }

    /// `오늘` · `내일` · `3일 후`.
    var phrase: String {
        switch daysAway {
        case 0: return "오늘"
        case 1: return "내일"
        default: return "\(daysAway)일 후"
        }
    }

    /// `11월 9일`.
    var dateText: String { "\(date.month)월 \(date.day)일" }
}

enum UpcomingDays {
    /// 홈 칸 · 만나기 전에 칸이 보는 날 수.
    static let soon = 30
    /// 모두 보기가 보는 날 수 — 한 해.
    static let year = 365

    static func today(calendar: Calendar = .current, now: Date = Date()) -> CivilDate {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// 한 사람의 다가오는 날 — 날짜 차례(같은 날이면 생일 먼저 · 기념일 차례).
    static func of(_ person: Person, today: CivilDate, within days: Int) -> [UpcomingDay] {
        guard !person.isGone, !person.isMe else { return [] }
        var items: [UpcomingDay] = []
        if let month = person.birthMonth, let day = person.birthDay, let item = birthday(person, month, day, today, days) {
            items.append(item)
        }
        for special in person.sortedSpecialDays {
            if let item = upcoming(special, of: person, today: today, within: days) { items.append(item) }
        }
        return items.sorted { $0.daysAway < $1.daysAway }
    }

    /// 여러 사람 — 생일이 있는 사람과 기념일만 읽는다(사람마다 관계를 풀지 않게). 날짜 차례 · 같은 날이면 이름순.
    /// 주 스레드에서 부르되 화면 본문이 아니라 자료가 바뀔 때(`task`) 부른다 (CLAUDE.md · 이슈 10).
    @MainActor
    static func all(in context: ModelContext, today: CivilDate, within days: Int) -> [UpcomingDay] {
        let born = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> {
            $0.isMe == false && $0.birthMonth != nil
        }))) ?? []
        var items: [UpcomingDay] = []
        for person in born where !person.isGone {
            if let month = person.birthMonth, let day = person.birthDay, let item = birthday(person, month, day, today, days) {
                items.append(item)
            }
        }
        let specials = (try? context.fetch(FetchDescriptor<SpecialDay>())) ?? []
        for special in specials where !special.isGone {
            guard let person = special.person, !person.isGone, !person.isMe else { continue }
            if let item = upcoming(special, of: person, today: today, within: days) { items.append(item) }
        }
        return items.sorted { lhs, rhs in
            if lhs.daysAway != rhs.daysAway { return lhs.daysAway < rhs.daysAway }
            if lhs.person !== rhs.person {
                return NameSort.areInIncreasingOrder((name: lhs.person.name, createdAt: lhs.person.createdAt),
                                                     (name: rhs.person.name, createdAt: rhs.person.createdAt))
            }
            return lhs.kind == .birthday && rhs.kind != .birthday
        }
    }

    private static func birthday(_ person: Person, _ month: Int, _ day: Int, _ today: CivilDate, _ days: Int) -> UpcomingDay? {
        guard BirthdayRule.isValid(month: month, day: day, year: nil) else { return nil }
        let next = today.nextOccurrence(month: month, day: day)
        let away = next.dayNumber - today.dayNumber
        guard away <= days else { return nil }
        return UpcomingDay(id: "birthday|\(person.uuid.uuidString)", kind: .birthday, person: person, date: next,
                           daysAway: away, label: "생일", years: nil)
    }

    private static func upcoming(_ special: SpecialDay, of person: Person, today: CivilDate, within days: Int) -> UpcomingDay? {
        guard BirthdayRule.isValid(month: special.month, day: special.day, year: nil) else { return nil }
        let next = today.nextOccurrence(month: special.month, day: special.day)
        let away = next.dayNumber - today.dayNumber
        guard away <= days else { return nil }
        let label = special.label.isEmpty ? "기념일" : special.label
        return UpcomingDay(id: "special|\(special.uuid.uuidString)", kind: .special, person: person, date: next,
                           daysAway: away, label: label, years: special.year.map { next.year - $0 })
    }
}
