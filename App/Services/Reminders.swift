import Core
import Foundation
import SwiftData
import UserNotifications

/// **알림 설정** (빌드 18 · D-40) — 생일 당일 · 알게 된 지 n주년 · 연락 주기. 모두 기본은 꺼짐. 시각은 기본 오전 9시.
/// 기기 편의라 UserDefaults — 백업 파일에는 넣지 않는다(사람 · 기록이 아니라 이 기기의 설정).
enum ReminderSettings {
    static let birthdaysKey = "reminders.birthdays"
    static let anniversariesKey = "reminders.anniversaries"
    static let cadenceKey = "reminders.cadence"
    /// 기념일 당일 (10판 · D-77) — 사람마다 여러 기념일, 줄마다 켜고 끈다. 기본은 꺼짐.
    static let specialDaysKey = "reminders.specialDays"
    /// 결과 적기 (빌드 38 · D-62) — 예정이던 만남의 다음 날 같은 시각에 결과를 적으라고 알린다. 기본은 꺼짐.
    static let followUpKey = "reminders.followUp"
    /// 약속 당일 (1.1.8 · 이슈 89 · FR-064) — 미리 적은 약속의 그날 알림 시각에(약속 시각이 이르면 한 시간 전). 기본은 꺼짐.
    static let plannedDayKey = "reminders.plannedDay"
    /// 달마다 돌아보기 (1.1.9 · 이슈 99 · FR-074) — 매달 1일 알림 시각에 지난달 기록 수 · 함께한 사람 수. 기본은 꺼짐.
    static let monthlyKey = "reminders.monthly"
    static let hourKey = "reminders.hour"
    static let minuteKey = "reminders.minute"
    static let defaultHour = 9

    static var options: ReminderPlanner.Options {
        let defaults = UserDefaults.standard
        return ReminderPlanner.Options(birthdays: defaults.bool(forKey: birthdaysKey),
                                       anniversaries: defaults.bool(forKey: anniversariesKey),
                                       cadence: defaults.bool(forKey: cadenceKey),
                                       specialDays: defaults.bool(forKey: specialDaysKey))
    }

    static var followUp: Bool { UserDefaults.standard.bool(forKey: followUpKey) }
    static var plannedDay: Bool { UserDefaults.standard.bool(forKey: plannedDayKey) }
    static var monthly: Bool { UserDefaults.standard.bool(forKey: monthlyKey) }

    static var hour: Int {
        (UserDefaults.standard.object(forKey: hourKey) as? Int).map { min(max($0, 0), 23) } ?? defaultHour
    }

    static var minute: Int {
        (UserDefaults.standard.object(forKey: minuteKey) as? Int).map { min(max($0, 0), 59) } ?? 0
    }
}

/// 결과 적기 알림 하나 (빌드 38 · D-62).
struct ReminderFollowUp: Sendable {
    /// `followUp|UUID|날 번호` — 날짜를 옮기면 이름도 바뀐다.
    let id: String
    /// 울릴 날 (그날 다음 날).
    let date: CivilDate
    let body: String
    /// 누르면 열 기록 (이슈 107 · `Core.AppLink`).
    let link: String?
}

/// 약속 당일 알림 하나 (1.1.8 · FR-064).
struct ReminderDayItem: Sendable {
    /// `plannedDay|UUID|날 번호`.
    let id: String
    let date: CivilDate
    /// 그 기록의 시각(자정부터 분) — 없으면 nil.
    let meetingMinute: Int?
    let body: String
    /// 누르면 열 기록 (이슈 107 · `Core.AppLink`).
    let link: String?
}

/// 달마다 돌아보기 알림 하나 (1.1.9 · FR-074).
struct ReminderMonthly: Sendable {
    /// `monthly|해달` — 돌아볼 달.
    let id: String
    let fireAt: Date
    let body: String
}

/// 달마다 돌아보기 (FR-074) — 다음 1일의 알림 시각과 돌아볼 달(그 전달).
/// 자료가 바뀌거나 앱이 앞으로 나올 때마다 다시 걸어 수가 새로워진다 — 이 기기에서 남긴 기록은 1일 전에 늘 반영된다.
enum MonthlyRecap {
    struct Plan: Equatable {
        let fireAt: Date
        /// 돌아볼 달의 첫날 0시 ~ 다음 달 첫날 0시.
        let start: Date
        let end: Date
        let month: Int
        let year: Int
    }

    /// `now` 보다 뒤인 가장 가까운 1일 `hour:minute`. 오늘이 1일이고 시각 전이면 오늘.
    static func plan(now: Date, hour: Int, minute: Int, calendar: Calendar = .current) -> Plan? {
        let parts = calendar.dateComponents([.year, .month], from: now)
        guard let thisFirst = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)) else { return nil }
        for offset in 0...1 {
            guard let first = calendar.date(byAdding: .month, value: offset, to: thisFirst),
                  let fireAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: first),
                  fireAt > now,
                  let start = calendar.date(byAdding: .month, value: -1, to: first) else { continue }
            let recap = calendar.dateComponents([.year, .month], from: start)
            return Plan(fireAt: fireAt, start: start, end: first, month: recap.month ?? 1, year: recap.year ?? 2000)
        }
        return nil
    }

    /// `10월에 남긴 기록 12건 · 함께한 사람 8명. 지난 한 달의 인연을 돌아보세요.`
    static func body(month: Int, records: Int, people: Int) -> String {
        guard records > 0 else {
            return "\(month)월에는 남긴 기록이 없습니다. 이번 달에 만나고 싶은 사람을 떠올려 보세요."
        }
        let who = people > 0 ? " · 함께한 사람 \(people)명" : ""
        return "\(month)월에 남긴 기록 \(records)건\(who). 지난 한 달의 인연을 돌아보세요."
    }
}

/// 알림을 **이 기기 안에서** 건다 — 서버도 네트워크도 없다. 계획은 `Core.ReminderPlanner` 한 곳에서 세고(정답표),
/// 여기서는 그 날의 고른 시각에 걸기만 한다.
///
/// - 자료가 바뀔 때 · 앱이 앞으로 나올 때 · 설정을 바꿀 때 다시 건다(걸려 있던 것은 모두 지우고 새로).
/// - 사람은 **따로 연 문맥**에서 읽는다 — 5,000명이어도 주 스레드를 막지 않는다 (이슈 8 · 10).
/// - 오늘 걸 시각이 이미 지났으면: 생일 · n주년은 넘긴다(올해는 지나감). 연락 주기는 내일 같은 시각으로 —
///   그리고 한 번 울린 연락 주기 알림은 기록을 새로 남겨 기한이 바뀌기 전까지 다시 걸지 않는다(밀린 알림을 쌓지 않는다).
/// - 앱 아이콘에 숫자를 달지 않는다.
@MainActor
enum ReminderScheduler {
    /// 걸어 둔 알림의 이름 → 울릴 시각. 다음에 다시 걸 때, 시각이 지난 것은 울린 것으로 본다.
    private static let scheduledKey = "reminders.scheduled"
    /// 울린 연락 주기 알림의 이름.
    private static let firedKey = "reminders.fired"

    static func refresh(container: ModelContainer, now: Date = Date()) async {
        // 견본 둘러보기 중에는 걸지 않는다 — 견본 사람의 생일로 내 알림을 덮지 않게 (D-55).
        if DemoMode.shared.isActive { return }
        let center = UNUserNotificationCenter.current()
        let options = ReminderSettings.options
        let followUp = ReminderSettings.followUp
        let plannedDay = ReminderSettings.plannedDay
        let monthly = ReminderSettings.monthly
        guard options.any || followUp || plannedDay || monthly else {
            center.removeAllPendingNotificationRequests()
            UserDefaults.standard.removeObject(forKey: scheduledKey)
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let today = CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
        // 약속 당일 · 달마다 알림 몫만큼 생일 · 기념일 계획을 줄인다 — 앱 하나에 64개인 기기 한도
        // (60 + 결과 적기 4 + 약속 당일 4 + 달마다 1 → 60 − 4 − 1).
        let planLimit = ReminderPlanner.limit - (plannedDay ? PlannedMeetings.dayReminderLimit : 0) - (monthly ? 1 : 0)
        let plan = await Task.detached(priority: .utility) {
            makePlan(container: container, options: options, today: today, limit: planLimit)
        }.value
        var dayItems: [ReminderDayItem] = []
        if plannedDay {
            dayItems = await Task.detached(priority: .utility) {
                makeDayReminders(container: container, now: now)
            }.value
        }
        var monthlyItem: ReminderMonthly?
        if monthly {
            let hour = ReminderSettings.hour, minute = ReminderSettings.minute
            monthlyItem = await Task.detached(priority: .utility) {
                makeMonthly(container: container, now: now, hour: hour, minute: minute)
            }.value
        }
        var followUps: [ReminderFollowUp] = []
        if followUp {
            followUps = await Task.detached(priority: .utility) {
                makeFollowUps(container: container, now: now)
            }.value
        }

        let defaults = UserDefaults.standard
        var fired = Set(defaults.stringArray(forKey: firedKey) ?? [])
        let scheduled = defaults.dictionary(forKey: scheduledKey) as? [String: Double] ?? [:]
        for (id, time) in scheduled where time <= now.timeIntervalSince1970 && id.hasPrefix(ReminderPlanner.Kind.cadence.rawValue) {
            fired.insert(id)
        }
        // 계획에 없는 이름은 잊는다 — 기록을 남겨 기한이 바뀌면 이름도 바뀐다.
        let planned = Set(plan.map(\.id))
        fired = fired.intersection(planned)

        center.removeAllPendingNotificationRequests()
        var next: [String: Double] = [:]
        for reminder in plan where !fired.contains(reminder.id) {
            guard var when = fireDate(reminder.date, calendar: calendar) else { continue }
            if when <= now {
                guard reminder.kind == .cadence, let tomorrow = calendar.date(byAdding: .day, value: 1, to: when) else { continue }
                when = tomorrow
            }
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = reminder.kind.rawValue
            // 누르면 그 사람 (이슈 107).
            if let link = AppLink.person(reminder.personID) {
                content.userInfo = [NotificationRouter.linkKey: link.absoluteString]
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let request = UNNotificationRequest(identifier: reminder.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                next[reminder.id] = when.timeIntervalSince1970
            } catch {
                continue
            }
        }
        // 약속 당일 — 그날의 고른 시각, 약속 시각이 이르면 한 시간 전(규칙은 `Core.PlannedMeetings`). 지났으면 걸지 않는다.
        let preferred = ReminderSettings.hour * 60 + ReminderSettings.minute
        for item in dayItems {
            let minute = PlannedMeetings.dayReminderMinute(meeting: item.meetingMinute, preferred: preferred)
            guard let when = fireDate(item.date, minuteOfDay: minute, calendar: calendar), when > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "오늘의 약속"
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "plannedDay"
            if let link = item.link { content.userInfo = [NotificationRouter.linkKey: link] }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let request = UNNotificationRequest(identifier: item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                next[item.id] = when.timeIntervalSince1970
            } catch {
                continue
            }
        }
        // 결과 적기 — 그날 다음 날의 고른 시각. 시각이 지났으면 걸지 않는다(밀린 알림을 쌓지 않는다).
        for item in followUps {
            guard let when = fireDate(item.date, calendar: calendar), when > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "만난 결과를 적어 둘까요?"
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "followUp"
            if let link = item.link { content.userInfo = [NotificationRouter.linkKey: link] }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let request = UNNotificationRequest(identifier: item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                next[item.id] = when.timeIntervalSince1970
            } catch {
                continue
            }
        }
        // 달마다 돌아보기 — 다음 1일의 고른 시각 하나.
        if let item = monthlyItem {
            let content = UNMutableNotificationContent()
            content.title = "한 달 돌아보기"
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "monthly"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireAt)
            let request = UNNotificationRequest(identifier: item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            if (try? await center.add(request)) != nil {
                next[item.id] = item.fireAt.timeIntervalSince1970
            }
        }
        defaults.set(next, forKey: scheduledKey)
        defaults.set(Array(fired), forKey: firedKey)
    }

    /// 달마다 돌아보기에 넣을 수 — 돌아볼 달의 기록만 읽는다(따로 연 문맥 · 주 스레드 밖). 나는 함께한 사람에서 뺀다.
    nonisolated static func makeMonthly(container: ModelContainer, now: Date, hour: Int, minute: Int) -> ReminderMonthly? {
        let calendar = Calendar.current
        guard let plan = MonthlyRecap.plan(now: now, hour: hour, minute: minute, calendar: calendar) else { return nil }
        let context = ModelContext(container)
        let start = plan.start, end = plan.end
        let records = ((try? context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> {
            $0.occurredAt >= start && $0.occurredAt < end
        }))) ?? []).filter { !$0.isGone }
        var people = Set<UUID>()
        for record in records {
            for person in record.participants ?? [] where !person.isGone && !person.isMe {
                people.insert(person.uuid)
            }
        }
        return ReminderMonthly(id: "monthly|\(plan.year * 100 + plan.month)",
                               fireAt: plan.fireAt,
                               body: MonthlyRecap.body(month: plan.month, records: records.count, people: people.count))
    }

    /// 결과 적기 알림에 넣을 예정 — 어제부터의 기록만 읽는다(따로 연 문맥 · 주 스레드 밖). 고르는 규칙은 `Core.PlannedMeetings`.
    nonisolated private static func makeFollowUps(container: ModelContainer, now: Date) -> [ReminderFollowUp] {
        let context = ModelContext(container)
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return [] }
        let records = (try? context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.occurredAt >= yesterday }))) ?? []
        let byID = Dictionary(records.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let picked = PlannedMeetings.followUps(records.map { $0.plannedEntry(calendar: calendar) },
                                               today: DayIndex.of(now, calendar: calendar))
        return picked.compactMap { id -> ReminderFollowUp? in
            guard let record = byID[id],
                  let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: record.occurredAt)) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: next)
            let others = (record.participants ?? []).filter { !$0.isMe }
            let names = NameSort.sorted(others, name: \.name, createdAt: \.createdAt).map(\.name)
            let who = names.isEmpty ? "" : " · " + (names.count > 2 ? "\(names.prefix(2).joined(separator: ", ")) 외 \(names.count - 2)명"
                                                                       : names.joined(separator: ", "))
            return ReminderFollowUp(id: "followUp|\(record.uuid.uuidString)|\(DayIndex.of(record.occurredAt, calendar: calendar))",
                            date: CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1),
                            body: "어제 예정이던 \(record.displayTitle)\(who). 느린 인연에 결과를 남겨 두세요.",
                            link: recordLink(record, others: others))
        }
    }

    /// 약속 당일 알림에 넣을 예정 — 오늘부터의 기록만 읽는다(따로 연 문맥 · 주 스레드 밖). 고르는 규칙은 `Core.PlannedMeetings`.
    nonisolated private static func makeDayReminders(container: ModelContainer, now: Date) -> [ReminderDayItem] {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let records = (try? context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.occurredAt >= start }))) ?? []
        let byID = Dictionary(records.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let picked = PlannedMeetings.dayReminders(records.map { $0.plannedEntry(calendar: calendar) },
                                                  today: DayIndex.of(now, calendar: calendar))
        return picked.compactMap { id -> ReminderDayItem? in
            guard let record = byID[id] else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: record.occurredAt)
            let others = (record.participants ?? []).filter { !$0.isMe }
            let names = NameSort.sorted(others, name: \.name, createdAt: \.createdAt).map(\.name)
            let who = names.isEmpty ? "" : " · " + (names.count > 2 ? "\(names.prefix(2).joined(separator: ", ")) 외 \(names.count - 2)명"
                                                                       : names.joined(separator: ", "))
            let time = record.timeText.map { $0 + " · " } ?? ""
            return ReminderDayItem(id: "plannedDay|\(record.uuid.uuidString)|\(DayIndex.of(record.occurredAt, calendar: calendar))",
                                   date: CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1),
                                   meetingMinute: record.occurredMinute,
                                   body: "\(time)\(record.displayTitle)\(who)",
                                   link: recordLink(record, others: others))
        }
    }

    /// 알림을 누르면 열 기록의 URL (이슈 107) — 기록은 사람 화면 위에 열리니 함께한 사람 가운데 이름 차례로 첫 사람.
    /// 나만 있는 기록이면 URL 이 없다(홈이 열린다).
    nonisolated private static func recordLink(_ record: Record, others: [Person]) -> String? {
        guard let person = NameSort.sorted(others.filter { !$0.isGone }, name: \.name, createdAt: \.createdAt).first else { return nil }
        return AppLink.record(record.uuid, person: person.uuid)?.absoluteString
    }

    /// 그 날의 그 시각(자정부터 분 · 기기 시간대).
    private static func fireDate(_ date: CivilDate, minuteOfDay: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        return calendar.date(from: components)
    }

    /// 그 날의 고른 시각 (기기 시간대).
    private static func fireDate(_ date: CivilDate, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = ReminderSettings.hour
        components.minute = ReminderSettings.minute
        return calendar.date(from: components)
    }

    /// 알림을 켤 때 한 번 묻는다. 거절했으면 거짓 — 설정 앱에서 켜야 한다.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// 사람을 읽어 계획을 센다 — 주 스레드 밖에서 부른다.
    nonisolated private static func makePlan(container: ModelContainer, options: ReminderPlanner.Options,
                                             today: CivilDate, limit: Int) -> [ReminderPlanner.Reminder] {
        let context = ModelContext(container)
        let people = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.isMe == false }))) ?? []
        let calendar = Calendar.current
        func knowsFirstMetDay(_ person: Person) -> Bool {
            person.firstMetDate != nil && DatePrecision.of(person.firstMetPrecision) == .day
        }
        func civil(_ date: Date) -> CivilDate {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
        }
        let inputs = people.compactMap { person -> ReminderPlanner.Person? in
            let wantsCadence = options.cadence && (person.contactCadenceMonths ?? 0) > 0
            let specials = options.specialDays
                ? person.sortedSpecialDays.filter(\.remind).map {
                    ReminderPlanner.SpecialDay(id: $0.uuid, label: $0.label, month: $0.month, day: $0.day, year: $0.year,
                                               remind: $0.remind)
                } : []
            let needed = (options.birthdays && person.birthMonth != nil && !person.muteBirthdayReminder)
                || (options.anniversaries && knowsFirstMetDay(person))
                || wantsCadence
                || !specials.isEmpty
            guard needed else { return nil }
            return ReminderPlanner.Person(
                id: person.uuid, name: person.name, birthMonth: person.birthMonth, birthDay: person.birthDay,
                // 월까지 · 연도만인 처음 만난 날은 n주년을 알리지 않는다 — 1일 · 1월 1일에 틀리게 울린다 (FR-033).
                firstMet: knowsFirstMetDay(person) ? person.firstMetDate.map(civil) : nil,
                // 마지막 기록은 연락 주기를 고른 사람만 센다 — 기록 관계를 읽는 비용이 크다.
                lastRecord: wantsCadence ? person.lastRecordAt.map(civil) : nil,
                registered: civil(person.createdAt), cadenceMonths: person.contactCadenceMonths,
                muteBirthday: person.muteBirthdayReminder, specialDays: specials)
        }
        return ReminderPlanner.plan(inputs, today: today, options: options, limit: limit)
    }
}
