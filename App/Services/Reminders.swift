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
    static let hourKey = "reminders.hour"
    static let minuteKey = "reminders.minute"
    static let defaultHour = 9

    static var options: ReminderPlanner.Options {
        let defaults = UserDefaults.standard
        return ReminderPlanner.Options(birthdays: defaults.bool(forKey: birthdaysKey),
                                       anniversaries: defaults.bool(forKey: anniversariesKey),
                                       cadence: defaults.bool(forKey: cadenceKey))
    }

    static var hour: Int {
        (UserDefaults.standard.object(forKey: hourKey) as? Int).map { min(max($0, 0), 23) } ?? defaultHour
    }

    static var minute: Int {
        (UserDefaults.standard.object(forKey: minuteKey) as? Int).map { min(max($0, 0), 59) } ?? 0
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
        guard options.any else {
            center.removeAllPendingNotificationRequests()
            UserDefaults.standard.removeObject(forKey: scheduledKey)
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let today = CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
        let plan = await Task.detached(priority: .utility) {
            makePlan(container: container, options: options, today: today)
        }.value

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
        defaults.set(next, forKey: scheduledKey)
        defaults.set(Array(fired), forKey: firedKey)
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
                                             today: CivilDate) -> [ReminderPlanner.Reminder] {
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
            let needed = (options.birthdays && person.birthMonth != nil)
                || (options.anniversaries && knowsFirstMetDay(person))
                || wantsCadence
            guard needed else { return nil }
            return ReminderPlanner.Person(
                id: person.uuid, name: person.name, birthMonth: person.birthMonth, birthDay: person.birthDay,
                // 월까지 · 연도만인 처음 만난 날은 n주년을 알리지 않는다 — 1일 · 1월 1일에 틀리게 울린다 (FR-033).
                firstMet: knowsFirstMetDay(person) ? person.firstMetDate.map(civil) : nil,
                // 마지막 기록은 연락 주기를 고른 사람만 센다 — 기록 관계를 읽는 비용이 크다.
                lastRecord: wantsCadence ? person.lastRecordAt.map(civil) : nil,
                registered: civil(person.createdAt), cadenceMonths: person.contactCadenceMonths)
        }
        return ReminderPlanner.plan(inputs, today: today, options: options)
    }
}
