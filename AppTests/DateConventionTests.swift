import SwiftData
import XCTest
@testable import SlowConnection

/// 날짜 칸을 기기 정오에서 **UTC 정오**로 옮기는 한 번의 변환 (전수조사 이슈 20 · `DateConvention`).
/// 기댓값은 달력 셈으로 만든다 — 숫자를 지어내지 않는다.
@MainActor
final class DateConventionTests: XCTestCase {
    private var container: ModelContainer?
    private let suite = "DateConventionTests"

    private func makeContext() throws -> ModelContext {
        let made = try Persistence.makeContainer(inMemory: true)
        container = made
        return made.mainContext
    }

    private func freshDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 서울에서 빌드 12 방식(그날 서울 정오)으로 저장된 값은, 서울 달력으로 읽은 같은 날의 12:00 UTC 가 된다.
    func testOldLocalNoonBecomesUTCNoonOfTheSameDay() throws {
        let context = try makeContext()
        let defaults = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let oldNoon = try XCTUnwrap(seoul.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))

        let person = Person(name: "옮김")
        context.insert(person)
        person.firstMetDate = oldNoon
        let record = Record(recordType: "meal", occurredAt: oldNoon, title: "점심")
        context.insert(record)
        record.participants = [person]
        try context.save()

        XCTAssertTrue(DateConvention.migrateIfNeeded(context, defaults: defaults, calendar: seoul))
        let want = try XCTUnwrap(utc.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        XCTAssertEqual(record.occurredAt, want, "기록 날짜는 3월 8일 12:00 UTC")
        XCTAssertEqual(person.firstMetDate, want, "처음 만난 날도")
        XCTAssertTrue(defaults.bool(forKey: DateConvention.flagKey), "옮긴 뒤 깃발을 세운다")
    }

    /// 깃발이 있으면 다시 하지 않고, 깃발이 없어도 이미 UTC 정오인 값은 그대로다 (두 번 돌아도 같다).
    func testRunningTwiceChangesNothing() throws {
        let context = try makeContext()
        let defaults = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let noonUTC = try XCTUnwrap(utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12)))
        let record = Record(recordType: "meal", occurredAt: noonUTC, title: "이미 옮긴 값")
        context.insert(record)
        try context.save()

        XCTAssertTrue(DateConvention.migrateIfNeeded(context, defaults: defaults, calendar: losAngeles))
        XCTAssertEqual(record.occurredAt, noonUTC, "이미 12:00 UTC 면 LA(−7)에서 읽어도 같은 날 — 그대로")
        XCTAssertFalse(DateConvention.migrateIfNeeded(context, defaults: defaults, calendar: losAngeles), "깃발이 있으면 다시 하지 않는다")

        defaults.removePersistentDomain(forName: suite)
        XCTAssertTrue(DateConvention.migrateIfNeeded(context, defaults: defaults, calendar: losAngeles))
        XCTAssertEqual(record.occurredAt, noonUTC, "깃발 없이 한 번 더 돌아도 그대로")
    }
}
