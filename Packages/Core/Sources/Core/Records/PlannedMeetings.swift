import Foundation

/// **예정된 만남** (빌드 38 · 1.1 · D-62) — 앞날짜 기록을 다가오는 만남으로 보이고, 그날이 온 뒤 결과를 적게 이끈다.
///
/// 스키마는 그대로다(2026-11-01 사용자). 기록에 이미 있는 만든 때 · 고친 때로 가른다:
/// - **다가오는 만남** — 기록 날이 오늘보다 뒤. 가까운 날부터, 같은 날은 이른 시각부터(시각 없음은 그날의 끝 · D-63).
/// - **결과를 적을 만남** — 날짜까지 정한 기록(월까지 · 연도만은 빼고)이 그날보다 **앞서 만들어졌고**(미리 적은 예정),
///   그날이 온 뒤로 **한 번도 고치지 않았고**, 그날이 지난 `window` 일 안이다. 최근 날부터.
///   결과를 적거나 `그대로 만났어요` 로 고친 때가 그날 이후가 되면 빠진다. 같은 날은 늦은 시각부터(타임라인과 같은 차례).
///   **시각을 넣은 예정은 날 대신 그 시각으로 가른다**(이슈 109 · 1.1.10) — 약속 날 시각 전에 만들거나 고친 것도 미리 적은 예정이다
///   (`isPlannedAhead`). 약속 당일 · 결과 적기 알림도 같은 금을 쓴다.
///
/// 날은 모두 같은 달력의 **날 번호**(부르는 쪽이 `DayIndex` 로 센다)라 시간대는 셈에 들지 않는다.
/// 오늘 날짜의 예정은 다가오는 만남이 아니라 결과를 적을 만남이다 — 목록의 마지막 기록일 · 최근 기록이
/// 오늘까지를 지난 기록으로 보는 것과 같은 금(이슈 20). **다만 시각을 넣은 오늘 예정은 그 시각이 오기 전까지
/// 다가오는 만남(`오늘`)** 이다(이슈 108 · 1.1.10) — 부르는 쪽이 지금 분(`nowMinute` · 자정부터)을 주면 그렇게 가른다.
/// 그 시각이 되면(같은 분 포함) 결과를 적을 만남으로 옮긴다. `nowMinute` 가 없으면 예전처럼 날만 본다.
/// 파이썬 정답표(`Tools/golden` 의 `plannedMeetings`)와 같은 셈이다.
public enum PlannedMeetings {
    /// 결과를 적을 만남으로 남겨 두는 날 수. 그보다 오래된 예정은 더 묻지 않는다.
    public static let window = 60

    public struct Entry: Sendable, Equatable {
        public let id: UUID
        public let day: Int
        public let createdDay: Int
        public let updatedDay: Int
        public let isDayPrecise: Bool
        /// 그날의 시각 (8판 · D-63). 같은 날 안의 차례 — 없으면 그날의 끝.
        public let minute: Int?
        /// 만든 때 · 고친 때의 시각(자정부터 분 · 이슈 109) — 약속과 **같은 날** 만들거나 고쳤을 때 약속 시각 앞인지 가른다.
        /// 없으면 예전처럼 날만 본다(같은 날이면 약속 뒤로 본다).
        public let createdMinute: Int?
        public let updatedMinute: Int?
        public init(id: UUID, day: Int, createdDay: Int, updatedDay: Int, isDayPrecise: Bool, minute: Int? = nil,
                    createdMinute: Int? = nil, updatedMinute: Int? = nil) {
            self.id = id
            self.day = day
            self.createdDay = createdDay
            self.updatedDay = updatedDay
            self.isDayPrecise = isDayPrecise
            self.minute = minute
            self.createdMinute = createdMinute
            self.updatedMinute = updatedMinute
        }
    }

    /// 약속보다 **앞선** 때인가 (이슈 109 · 1.1.10) — 앞선 날이면 앞이다. 같은 날이면 약속에 시각이 있고 그 때의 시각이
    /// 약속 시각보다 이를 때만 앞이다(같은 분은 뒤). 약속에 시각이 없거나 그 때의 시각을 모르면 같은 날은 뒤로 본다.
    static func isBefore(day: Int, minute: Int?, atDay: Int, atMinute: Int?) -> Bool {
        if atDay != day { return atDay < day }
        guard let minute, let atMinute else { return false }
        return atMinute < minute
    }

    /// **미리 적은 예정**인가 — 약속(시각을 넣었으면 그 시각)보다 앞서 만들었고, 그 뒤로 고치지 않았다.
    /// 약속 날에 약속 시각 전에 고친 것(사람을 더하거나 장소를 바꾼 것)은 결과를 적은 것이 아니다 (이슈 109 · 2026-11-11 사용자).
    public static func isPlannedAhead(_ entry: Entry) -> Bool {
        let minute = entry.isDayPrecise ? entry.minute : nil
        return isBefore(day: entry.day, minute: minute, atDay: entry.createdDay, atMinute: entry.createdMinute)
            && isBefore(day: entry.day, minute: minute, atDay: entry.updatedDay, atMinute: entry.updatedMinute)
    }

    public struct Plan: Sendable, Equatable {
        public let upcoming: [UUID]
        public let awaiting: [UUID]
    }

    /// 오늘이지만 넣은 시각이 아직 오지 않은 예정 (이슈 108) — 다가오는 만남 쪽에 둔다.
    public static func isLaterToday(_ entry: Entry, today: Int, nowMinute: Int?) -> Bool {
        guard entry.isDayPrecise, entry.day == today, let now = nowMinute, let minute = entry.minute else { return false }
        return minute > now
    }

    /// 다가오는 만남인가 — 오늘보다 뒤이거나, 오늘이지만 넣은 시각이 아직 오지 않았다.
    public static func isUpcoming(_ entry: Entry, today: Int, nowMinute: Int? = nil) -> Bool {
        entry.day > today || isLaterToday(entry, today: today, nowMinute: nowMinute)
    }

    public static func isAwaiting(_ entry: Entry, today: Int, nowMinute: Int? = nil, window: Int = window) -> Bool {
        entry.isDayPrecise
            && !isLaterToday(entry, today: today, nowMinute: nowMinute)
            && entry.day <= today
            && entry.day >= today - window
            && isPlannedAhead(entry)
    }

    public static func plan(_ entries: [Entry], today: Int, nowMinute: Int? = nil, window: Int = window) -> Plan {
        let upcoming = entries
            .filter { isUpcoming($0, today: today, nowMinute: nowMinute) }
            .sorted {
                ($0.day, TimeOfDay.sortKey($0.minute), $0.createdDay, $0.id.uuidString)
                    < ($1.day, TimeOfDay.sortKey($1.minute), $1.createdDay, $1.id.uuidString)
            }
        let awaiting = entries
            .filter { isAwaiting($0, today: today, nowMinute: nowMinute, window: window) }
            .sorted {
                if $0.day != $1.day { return $0.day > $1.day }
                let l = TimeOfDay.sortKey($0.minute), r = TimeOfDay.sortKey($1.minute)
                return l != r ? l > r : $0.id.uuidString < $1.id.uuidString
            }
        return Plan(upcoming: upcoming.map(\.id), awaiting: awaiting.map(\.id))
    }

    /// 결과 적기 알림을 한 번에 걸어 두는 수 — 기기는 앱 하나에 알림을 64개까지만 둔다(`ReminderPlanner.limit` 60 + 4).
    public static let followUpLimit = 4

    /// **결과 적기 알림** (설정 → 알림 · 기본 꺼짐) — 그날 **다음 날** 아침에 울릴 예정들. 날짜까지 정한 기록을 그날보다
    /// 앞서 만들었고 그날 이후 고친 적이 없고, 그날이 어제이거나 그 뒤. 가까운 날부터 `limit` 개.
    /// 울릴 시각이 이미 지났는지는 부르는 쪽이 본다(시각은 날 번호에 없다).
    public static func followUps(_ entries: [Entry], today: Int, limit: Int = followUpLimit) -> [UUID] {
        entries
            .filter { $0.isDayPrecise && $0.day >= today - 1 && isPlannedAhead($0) }
            .sorted {
                ($0.day, TimeOfDay.sortKey($0.minute), $0.id.uuidString) < ($1.day, TimeOfDay.sortKey($1.minute), $1.id.uuidString)
            }
            .prefix(limit)
            .map(\.id)
    }

    /// 약속 당일 알림을 한 번에 걸어 두는 수 (1.1.8 · FR-064) — 부르는 쪽이 생일 · 기념일 계획의 한도를 이만큼 줄여
    /// 앱 하나에 64개인 기기 한도를 넘지 않게 한다.
    public static let dayReminderLimit = 4
    /// 약속 시각이 있으면 이만큼(분) 앞에 알린다 — 고른 알림 시각이 그보다 늦을 때.
    public static let dayReminderLead = 60

    /// **약속 당일 알림** (1.1.8 · 이슈 89 · FR-064 · 설정 → 알림 · 기본 꺼짐) — 그날 울릴 예정들. 날짜까지 정한 기록을
    /// 그날보다 앞서 만들었고(미리 적은 약속) 그날 이후 고친 적이 없고, 그날이 오늘이거나 그 뒤. 가까운 날 → 이른 시각부터 `limit` 개.
    /// 울릴 시각이 이미 지났는지는 부르는 쪽이 본다.
    public static func dayReminders(_ entries: [Entry], today: Int, limit: Int = dayReminderLimit) -> [UUID] {
        entries
            .filter { $0.isDayPrecise && $0.day >= today && isPlannedAhead($0) }
            .sorted {
                ($0.day, TimeOfDay.sortKey($0.minute), $0.id.uuidString) < ($1.day, TimeOfDay.sortKey($1.minute), $1.id.uuidString)
            }
            .prefix(limit)
            .map(\.id)
    }

    /// 약속 당일 알림의 시각(자정부터 분) — 고른 알림 시각(`preferred`). 약속 시각(`meeting`)이 있고 그 `lead` 분 앞이
    /// 알림 시각보다 이르면 그때(그날 0시 아래면 0시) — 오전 8시 약속을 9시에 알리지 않게.
    public static func dayReminderMinute(meeting: Int?, preferred: Int, lead: Int = dayReminderLead) -> Int {
        guard let meeting, meeting - lead < preferred else { return preferred }
        return max(0, meeting - lead)
    }

    /// 다가오는 만남 줄의 앞말 — `내일` · `3일 후` · `2주 후`.
    public static func upcomingPhrase(day: Int, today: Int) -> String {
        RelativeDay.phrase(days: today - day)
    }
}
