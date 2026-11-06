import Core
import SwiftUI
import WidgetKit

/// **느린 인연 위젯** (1.1.9 · 빌드 63 · 이슈 100 · FR-075 · D-79) — 다가오는 약속 · 생일 · 기념일.
///
/// 저장소를 열지 않는다. 앱이 App Group 에 남긴 요약(`widget-summary.json` · `Core.WidgetSummary`)만 읽어 그린다.
/// 이름을 숨기게 했으면 요약에 이름이 들어 있지 않고, 앱 잠금이면 건수만 들어 있다 — 위젯은 받은 만큼만 보인다.
@main
struct SlowConnectionWidgets: WidgetBundle {
    var body: some Widget {
        UpcomingWidget()
    }
}

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "upcoming", provider: UpcomingProvider()) { entry in
            UpcomingWidgetView(entry: entry)
                .containerBackground(Color.raised, for: .widget)
        }
        .configurationDisplayName("다가오는 인연")
        .description("다가오는 약속과 생일 · 기념일을 보입니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(date: Date(), summary: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        completion(UpcomingEntry(date: Date(), summary: Self.read()))
    }

    /// 지금 한 장 + 다음 자정마다 사흘 — `내일` 이 `오늘` 로 바뀌게. 그 뒤는 앱이 새 요약을 쓰며 다시 그리게 한다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let summary = Self.read()
        let calendar = Calendar.current
        let now = Date()
        var entries = [UpcomingEntry(date: now, summary: summary)]
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<3 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            entries.append(UpcomingEntry(date: next, summary: summary))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func read() -> WidgetSummary? {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedFiles.appGroup),
              let data = try? Data(contentsOf: folder.appendingPathComponent(SharedFiles.widgetSummary)) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }
}

struct UpcomingWidgetView: View {
    let entry: UpcomingEntry
    @Environment(\.widgetFamily) private var family

    private var today: Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: entry.date)
        return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1).dayNumber
    }

    /// 지난 날은 빼고 — 요약을 쓴 뒤 날이 지났을 수 있다.
    private var lines: [WidgetSummary.Item] {
        guard let summary = entry.summary else { return [] }
        let all = (summary.meetings + summary.days).filter { $0.day >= today }
        return all.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return TimeOfDay.sortKey($0.minute) < TimeOfDay.sortKey($1.minute)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("느린 인연")
                .font(.scaled(12, weight: .semibold))
                .foregroundStyle(Color.accent)
            if let summary = entry.summary {
                if summary.mode == .countsOnly {
                    counts(summary)
                } else if lines.isEmpty {
                    Text("다가오는 약속 · 생일이 없습니다")
                        .font(.scaled(14))
                        .foregroundStyle(Color.muted)
                } else {
                    ForEach(Array(lines.prefix(family == .systemSmall ? 2 : 3).enumerated()), id: \.offset) { _, item in
                        row(item, hidden: summary.mode == .hidden)
                    }
                }
            } else {
                Text("앱을 한 번 열면 다가오는 약속이 보입니다")
                    .font(.scaled(14))
                    .foregroundStyle(Color.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func counts(_ summary: WidgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("약속 \(summary.meetingCount)건")
                .font(.scaled(17, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("생일 · 기념일 \(summary.dayCount)건")
                .font(.scaled(14))
                .foregroundStyle(Color.bodyText)
            Text("앱 잠금이 켜져 있어 건수만 보입니다")
                .font(.scaled(11))
                .foregroundStyle(Color.muted)
        }
    }

    private func row(_ item: WidgetSummary.Item, hidden: Bool) -> some View {
        let phrase = RelativeDay.phrase(days: today - item.day)
        let time = item.minute.map { " · " + TimeOfDay.text($0) } ?? ""
        let kind: String
        switch item.kind {
        case .meeting: kind = "약속"
        case .birthday: kind = "생일"
        case .special: kind = "기념일"
        }
        let main = hidden ? kind : ([item.names, item.title].compactMap { $0 }.joined(separator: " · "))
        return VStack(alignment: .leading, spacing: 1) {
            Text(phrase + time)
                .font(.scaled(12, weight: item.day == today ? .semibold : .regular))
                .foregroundStyle(item.day == today ? Color.accent : Color.muted)
            Text(main.isEmpty ? kind : main)
                .font(.scaled(14, weight: .medium))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
    }
}
