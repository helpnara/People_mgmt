import Core
import Foundation
import SwiftData

/// **날짜 칸을 UTC 정오로 한 번 옮긴다** (전수조사 이슈 20 · 빌드 13).
///
/// 빌드 12 까지 기록 날짜 · 처음 만난 날은 **기기 시간대의 정오**로 저장했다. 이제는 그 날의 **12:00 UTC** 다
/// (`Core.DayNormalizer.noon`). 이미 저장된 값은 앱을 처음 켤 때 한 번 옮긴다 — 저장된 순간을 지금 기기 시간대의
/// 달력으로 읽어 연 · 월 · 일을 얻고, 그 날의 12:00 UTC 로 바꾼다.
///
/// **두 번 돌아도 그대로다.** 이미 12:00 UTC 인 값은 UTC−11 ~ UTC+11 어디서 읽어도 같은 날(12:00 ± 11시간 =
/// 01:00 ~ 23:00)이라 같은 12:00 UTC 로 돌아온다. 옛 값(적은 곳의 정오)도 그 기기 시간대에서는 같은 날 정오라 날이
/// 바뀌지 않는다 — 여행 중에 처음 켜면 그곳 기준이지만, 그 경우도 ±12시간 안이면 같은 날이다.
/// 깃발(`UserDefaults`)은 진짜 저장소를 옮긴 뒤에만 세운다 — 실패하면 되돌리고 다음에 켤 때 다시 한다.
@MainActor
enum DateConvention {
    static let flagKey = "dates.utcNoon.v1"

    /// 옮겼으면 true. 이미 옮겼거나(깃발) 실패하면 false.
    @discardableResult
    static func migrateIfNeeded(_ context: ModelContext, defaults: UserDefaults = .standard,
                                calendar: Calendar = .current) -> Bool {
        guard !defaults.bool(forKey: flagKey) else { return false }
        do {
            for record in try context.fetch(FetchDescriptor<Record>()) {
                let moved = DayNormalizer.noon(of: record.occurredAt, calendar: calendar)
                if moved != record.occurredAt { record.occurredAt = moved }
            }
            for person in try context.fetch(FetchDescriptor<Person>()) {
                guard let met = person.firstMetDate else { continue }
                let moved = DayNormalizer.noon(of: met, calendar: calendar)
                if moved != met { person.firstMetDate = moved }
            }
            if context.hasChanges { try context.save() }
            defaults.set(true, forKey: flagKey)
            return true
        } catch {
            context.rollback()
            print("⚠️ 날짜 칸을 UTC 정오로 옮기지 못했습니다 — 다음에 켤 때 다시 합니다: \(error)")
            return false
        }
    }
}
