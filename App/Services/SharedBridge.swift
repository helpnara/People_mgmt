import Core
import Foundation
import SwiftData
import WidgetKit

/// App Group 그릇 (1.1.9 · 빌드 63 · D-79) — 위젯 요약 · 공유 초안이 사는 곳. 저장소는 여기로 옮기지 않는다.
enum SharedContainer {
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedFiles.appGroup)
    }
}

/// **홈 화면 위젯의 요약** (이슈 100 · FR-075) — 자료가 바뀔 때 · 앱이 앞으로 나올 때 · 설정을 바꿀 때 새로 쓰고 위젯을 다시 그리게 한다.
///
/// - 오늘부터 14일 안의 약속, 7일 안의 생일 · 기념일. 셈은 앱(`UpcomingDays` · `TimelineSort`)이 하고 위젯은 그리기만.
/// - 설정 `위젯에 이름 숨기기` 면 제목 · 이름을 파일에 **쓰지 않는다**. 앱 잠금이 켜져 있으면 건수만 쓴다 (D-79).
/// - 견본 둘러보기 중에는 쓰지 않는다 — 견본 사람이 내 홈 화면에 나오지 않게 (D-55).
enum WidgetBridge {
    static let hideNamesKey = "widget.hideNames"

    @MainActor
    static func refresh(container: ModelContainer, now: Date = Date()) async {
        if DemoMode.shared.isActive { return }
        guard let folder = SharedContainer.url else { return }
        let defaults = UserDefaults.standard
        let mode: WidgetSummary.Mode = defaults.bool(forKey: AppLock.enabledKey) ? .countsOnly
            : (defaults.bool(forKey: hideNamesKey) ? .hidden : .names)
        let summary = await Task.detached(priority: .utility) {
            make(container: container, mode: mode, now: now)
        }.value
        guard let data = try? JSONEncoder().encode(summary) else { return }
        try? data.write(to: folder.appendingPathComponent(SharedFiles.widgetSummary), options: [.atomic])
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 따로 연 문맥에서 — 주 스레드를 막지 않는다 (이슈 8).
    nonisolated static func make(container: ModelContainer, mode: WidgetSummary.Mode, now: Date) -> WidgetSummary {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: WidgetSummary.meetingWindow, to: start) ?? start
        let records = ((try? context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> {
            $0.occurredAt >= start && $0.occurredAt < end
        }))) ?? [])
            .filter { !$0.isGone && DatePrecision.of($0.occurredPrecision) == .day }
            .sorted {
                // 가까운 날 · 이른 시각부터 (다가오는 만남과 같은 차례 — 시각 없는 것은 그날 끝).
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                let l = TimeOfDay.sortKey($0.occurredMinute), r = TimeOfDay.sortKey($1.occurredMinute)
                if l != r { return l < r }
                return $0.createdAt < $1.createdAt
            }
        func civilDay(_ date: Date) -> Int {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1).dayNumber
        }
        let showsNames = mode == .names
        let meetings = mode == .countsOnly ? [] : records.prefix(WidgetSummary.itemLimit).map { record -> WidgetSummary.Item in
            let others = NameSort.sorted((record.participants ?? []).filter { !$0.isGone && !$0.isMe },
                                         name: \.name, createdAt: \.createdAt).map(\.name)
            let names = others.count > 2 ? "\(others.prefix(2).joined(separator: ", ")) 외 \(others.count - 2)명"
                                          : others.joined(separator: ", ")
            return WidgetSummary.Item(kind: .meeting, day: civilDay(record.occurredAt), minute: record.occurredMinute,
                                      title: showsNames ? record.displayTitle : nil,
                                      names: showsNames && !names.isEmpty ? names : nil)
        }
        let today = UpcomingDays.today(calendar: calendar, now: now)
        let upcoming = UpcomingDays.all(in: context, today: today, within: WidgetSummary.dayWindow - 1)
        let days = mode == .countsOnly ? [] : upcoming.prefix(WidgetSummary.itemLimit).map { day -> WidgetSummary.Item in
            WidgetSummary.Item(kind: day.kind == .birthday ? .birthday : .special, day: day.date.dayNumber, minute: nil,
                               title: showsNames ? day.title : nil,
                               names: showsNames ? day.person.name : nil)
        }
        return WidgetSummary(mode: mode, madeAt: now, meetings: Array(meetings), meetingCount: records.count,
                             days: Array(days), dayCount: upcoming.count)
    }
}

/// **공유 시트로 받은 초안** (이슈 101 · FR-076) — 공유 시트가 App Group 에 남긴 폴더를 읽고 지운다.
enum SharedDraftStore {
    private static var folder: URL? {
        SharedContainer.url?.appendingPathComponent(SharedFiles.shareDrafts, isDirectory: true)
    }

    /// 받은 차례대로(오래된 것부터). 읽지 못하는 폴더는 건너뛴다.
    static func drafts() -> [SharedDraft] {
        guard let folder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        let decoder = JSONDecoder()
        return names.compactMap { name -> SharedDraft? in
            let file = folder.appendingPathComponent(name, isDirectory: true).appendingPathComponent(SharedFiles.draftFile)
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? decoder.decode(SharedDraft.self, from: data)
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    /// 초안의 사진 원본(공유 시트가 긴 변 2,048px 로 줄여 둔 JPEG).
    static func photos(of draft: SharedDraft) -> [Data] {
        guard let folder else { return [] }
        let base = folder.appendingPathComponent(draft.id.uuidString, isDirectory: true)
        return draft.photoFiles.compactMap { try? Data(contentsOf: base.appendingPathComponent($0)) }
    }

    /// 기록으로 옮겼거나 버리기를 확인한 뒤에 부른다 (모든 삭제에 확인 · CLAUDE.md).
    static func remove(_ draft: SharedDraft) {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(draft.id.uuidString, isDirectory: true))
    }
}
