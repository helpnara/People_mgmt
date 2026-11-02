import Foundation

/// **예정된 만남** (빌드 38 · 1.1 · D-62) — 앞날짜 기록을 다가오는 만남으로 보이고, 그날이 온 뒤 결과를 적게 이끈다.
///
/// 스키마는 그대로다(2026-11-01 사용자). 기록에 이미 있는 만든 때 · 고친 때로 가른다:
/// - **다가오는 만남** — 기록 날이 오늘보다 뒤. 가까운 날부터, 같은 날은 이른 시각부터(시각 없음은 그날의 끝 · D-63).
/// - **결과를 적을 만남** — 날짜까지 정한 기록(월까지 · 연도만은 빼고)이 그날보다 **앞서 만들어졌고**(미리 적은 예정),
///   그날이 온 뒤로 **한 번도 고치지 않았고**, 그날이 지난 `window` 일 안이다. 최근 날부터.
///   결과를 적거나 `그대로 만났어요` 로 고친 때가 그날 이후가 되면 빠진다. 같은 날은 늦은 시각부터(타임라인과 같은 차례).
///
/// 날은 모두 같은 달력의 **날 번호**(부르는 쪽이 `DayIndex` 로 센다)라 시각 · 시간대는 셈에 들지 않는다.
/// 오늘 날짜의 예정은 다가오는 만남이 아니라 결과를 적을 만남이다 — 목록의 마지막 기록일 · 최근 기록이
/// 오늘까지를 지난 기록으로 보는 것과 같은 금(이슈 20).
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
        public init(id: UUID, day: Int, createdDay: Int, updatedDay: Int, isDayPrecise: Bool, minute: Int? = nil) {
            self.id = id
            self.day = day
            self.createdDay = createdDay
            self.updatedDay = updatedDay
            self.isDayPrecise = isDayPrecise
            self.minute = minute
        }
    }

    public struct Plan: Sendable, Equatable {
        public let upcoming: [UUID]
        public let awaiting: [UUID]
    }

    public static func isAwaiting(_ entry: Entry, today: Int, window: Int = window) -> Bool {
        entry.isDayPrecise
            && entry.day <= today
            && entry.day >= today - window
            && entry.createdDay < entry.day
            && entry.updatedDay < entry.day
    }

    public static func plan(_ entries: [Entry], today: Int, window: Int = window) -> Plan {
        let upcoming = entries
            .filter { $0.day > today }
            .sorted {
                ($0.day, TimeOfDay.sortKey($0.minute), $0.createdDay, $0.id.uuidString)
                    < ($1.day, TimeOfDay.sortKey($1.minute), $1.createdDay, $1.id.uuidString)
            }
        let awaiting = entries
            .filter { isAwaiting($0, today: today, window: window) }
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
            .filter { $0.isDayPrecise && $0.day >= today - 1 && $0.createdDay < $0.day && $0.updatedDay < $0.day }
            .sorted {
                ($0.day, TimeOfDay.sortKey($0.minute), $0.id.uuidString) < ($1.day, TimeOfDay.sortKey($1.minute), $1.id.uuidString)
            }
            .prefix(limit)
            .map(\.id)
    }

    /// 다가오는 만남 줄의 앞말 — `내일` · `3일 후` · `2주 후`.
    public static func upcomingPhrase(day: Int, today: Int) -> String {
        RelativeDay.phrase(days: today - day)
    }
}
