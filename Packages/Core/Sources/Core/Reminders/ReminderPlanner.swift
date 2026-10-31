import Foundation

/// **알림 계획** (빌드 18 · D-40) — 생일 당일 · 알게 된 지 n주년 · 연락 주기. 모두 기본은 꺼짐이고 켠 것만 센다.
///
/// - **생일**: 월 · 일을 적은 사람. 2월 29일은 평년이면 2월 28일.
/// - **n주년**: 처음 만난 날을 적은 사람. 1주년부터.
/// - **연락 주기**: 사람 수정에서 주기(개월)를 고른 사람만. 마지막 기록(없으면 등록한 날)에서 그만큼 지난 날 **한 번**.
///   이미 지났으면 오늘로 — 밀린 개수를 쌓지 않는다(같은 날짜의 알림은 하나). 기록을 남기면 다음 날짜로 밀린다.
/// - 오늘부터 366일 안의 것만, 날짜 순(같은 날이면 생일 · n주년 · 연락 주기, 이름 순)으로 `limit` 개까지 —
///   기기는 앱 하나에 알림을 64개까지만 걸어 둔다.
/// - 나는 넣지 않는다. 점수 · 순위가 없다 (ADR-0004).
///
/// 파이썬 정답표(`Tools/golden` 의 `reminders`)와 같은 셈이다.
public enum ReminderPlanner {
    public static let limit = 60
    public static let horizonDays = 366

    public enum Kind: String, Sendable, CaseIterable {
        case birthday, anniversary, cadence

        var order: Int {
            switch self {
            case .birthday: return 0
            case .anniversary: return 1
            case .cadence: return 2
            }
        }
    }

    public struct Options: Sendable, Equatable {
        public var birthdays: Bool
        public var anniversaries: Bool
        public var cadence: Bool
        public init(birthdays: Bool, anniversaries: Bool, cadence: Bool) {
            self.birthdays = birthdays
            self.anniversaries = anniversaries
            self.cadence = cadence
        }
        public var any: Bool { birthdays || anniversaries || cadence }
    }

    public struct Person: Sendable {
        public let id: UUID
        public let name: String
        public let birthMonth: Int?
        public let birthDay: Int?
        public let firstMet: CivilDate?
        public let lastRecord: CivilDate?
        public let registered: CivilDate
        public let cadenceMonths: Int?
        public init(id: UUID, name: String, birthMonth: Int?, birthDay: Int?, firstMet: CivilDate?,
                    lastRecord: CivilDate?, registered: CivilDate, cadenceMonths: Int?) {
            self.id = id
            self.name = name
            self.birthMonth = birthMonth
            self.birthDay = birthDay
            self.firstMet = firstMet
            self.lastRecord = lastRecord
            self.registered = registered
            self.cadenceMonths = cadenceMonths
        }
    }

    public struct Reminder: Sendable, Equatable {
        /// `kind|UUID|yyyy-mm-dd` — 같은 사람 · 같은 날의 같은 알림은 하나. 연락 주기는 **기한 날**로 붙인다 —
        /// 기한이 지나 오늘로 당겨 와도 이름은 그대로라, 한 번 울린 알림을 부르는 쪽이 다시 걸지 않을 수 있다.
        public let id: String
        public let kind: Kind
        public let personID: UUID
        public let date: CivilDate
        public let title: String
        public let body: String
    }

    public static func plan(_ people: [Person], today: CivilDate, options: Options, limit: Int = limit) -> [Reminder] {
        guard options.any else { return [] }
        let horizon = today.dayNumber + horizonDays
        var out: [(reminder: Reminder, key: String)] = []

        func add(_ kind: Kind, _ person: Person, _ date: CivilDate, _ title: String, _ body: String, named: CivilDate? = nil) {
            guard date.dayNumber <= horizon else { return }
            let named = named ?? date
            let stamp = String(format: "%04d-%02d-%02d", named.year, named.month, named.day)
            let reminder = Reminder(id: "\(kind.rawValue)|\(person.id.uuidString)|\(stamp)", kind: kind, personID: person.id,
                                    date: date, title: title, body: body)
            out.append((reminder, NameSort.key(person.name)))
        }

        for person in people {
            if options.birthdays, let month = person.birthMonth, let day = person.birthDay,
               BirthdayRule.isValid(month: month, day: day, year: nil) {
                add(.birthday, person, today.nextOccurrence(month: month, day: day),
                    "오늘은 \(person.name) 님 생일입니다", "축하 인사를 전해 보세요.")
            }
            if options.anniversaries, let met = person.firstMet {
                var next = today.nextOccurrence(month: met.month, day: met.day)
                if next.year - met.year < 1 {
                    next = CivilDate.clamped(year: met.year + 1, month: met.month, day: met.day)
                }
                let years = next.year - met.year
                add(.anniversary, person, next, "\(person.name) 님과 알게 된 지 \(years)년이 되었습니다",
                    "처음 만난 날 " + BirthdayRule.text(month: met.month, day: met.day, year: met.year))
            }
            if options.cadence, let months = person.cadenceMonths, months > 0 {
                let base = person.lastRecord ?? person.registered
                let due = base.addingMonths(months)
                add(.cadence, person, max(due, today), "\(person.name) 님과 \(months)개월 동안 기록이 없습니다",
                    "안부를 전하고 함께한 일을 남겨 보세요.", named: due)
            }
        }

        out.sort { l, r in
            if l.reminder.date != r.reminder.date { return l.reminder.date < r.reminder.date }
            if l.reminder.kind != r.reminder.kind { return l.reminder.kind.order < r.reminder.kind.order }
            if l.key != r.key { return l.key < r.key }
            return l.reminder.personID.uuidString < r.reminder.personID.uuidString
        }
        return Array(out.prefix(limit).map(\.reminder))
    }
}
