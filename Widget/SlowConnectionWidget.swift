import Core
import SwiftUI
import WidgetKit

/// **느린 인연 위젯** (1.1.9 · 빌드 63 · 이슈 100 · FR-075 · D-79) — 다가오는 약속 · 생일 · 기념일.
///
/// 저장소를 열지 않는다. 앱이 App Group 에 남긴 요약(`widget-summary.json` · `Core.WidgetSummary`)만 읽어 그린다.
/// 이름을 숨기게 했으면 요약에 이름 · 얼굴이 들어 있지 않고, 앱 잠금이면 건수만 들어 있다 — 위젯은 받은 만큼만 보인다.
///
/// **빌드 65 다듬기** (2026-11-06 사용자 — 다른 위젯보다 디자인 수준이 떨어진다 · 와 소리가 나게): 가장 가까운 만남 하나를
/// **D-day 큰 글씨 · 함께할 사람의 얼굴 · 종류 색**으로 크게, 나머지는 작은 줄로. 잠금 화면 위젯(동그란 것 · 네모난 것 · 글 한 줄).
/// 누르면 그 기록 · 그 사람이 열린다(`Core.AppLink`).
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
        }
        .configurationDisplayName("다가오는 인연")
        .description("다음 약속을 D-day 와 함께할 사람의 얼굴로, 생일 · 기념일까지 보입니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(date: Date(), summary: Self.sample(now: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        // 위젯 갤러리(미리보기)에는 지어낸 견본을, 실제 홈 화면에는 요약을.
        completion(UpcomingEntry(date: Date(), summary: context.isPreview ? Self.sample(now: Date()) : Self.read()))
    }

    /// 지금 한 장 + 다음 자정마다 사흘 — `D-1` 이 `D-DAY` 로 바뀌게. 그 뒤는 앱이 새 요약을 쓰며 다시 그리게 한다.
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

    /// 위젯 갤러리 미리보기 — 지어낸 사람 (CLAUDE.md 2절).
    static func sample(now: Date) -> WidgetSummary {
        let today = WidgetDay.number(of: now)
        return WidgetSummary(mode: .names, madeAt: now,
                             meetings: [
                                 .init(kind: .meeting, day: today, minute: 18 * 60, title: "가족 저녁식사", names: "김하늘, 정유진 외 1명",
                                       avatars: [.init(initial: "김", photo: nil), .init(initial: "정", photo: nil), .init(initial: "이", photo: nil)]),
                                 .init(kind: .meeting, day: today + 5, minute: 17 * 60 + 30, title: "저녁식사", names: "이도윤 외 1명",
                                       avatars: [.init(initial: "이", photo: nil)], moreCount: 1),
                             ],
                             meetingCount: 2,
                             days: [.init(kind: .special, day: today + 6, minute: nil, title: "결혼기념일 8주년", names: "박서준",
                                          avatars: [.init(initial: "박", photo: nil)])],
                             dayCount: 1)
    }
}

/// 날짜 셈 — 위젯이 `오늘` 을 알아야 `D-day` 를 센다.
enum WidgetDay {
    static func number(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1).dayNumber
    }

    /// `11월 6일 (목)`.
    static func header(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

/// 종류마다 색 · 그림 — 약속은 앱 강조색, 생일은 주황, 기념일은 자주 (Palette 토큰).
enum KindStyle {
    static func symbol(_ kind: WidgetSummary.Item.Kind) -> String {
        switch kind {
        case .meeting: return "person.2.fill"
        case .birthday: return "gift.fill"
        case .special: return "heart.fill"
        }
    }

    static func label(_ kind: WidgetSummary.Item.Kind) -> String {
        switch kind {
        case .meeting: return "약속"
        case .birthday: return "생일"
        case .special: return "기념일"
        }
    }

    static func ink(_ kind: WidgetSummary.Item.Kind) -> Color {
        switch kind {
        case .meeting: return Color.accent
        case .birthday: return Color.clusterOrangeInk
        case .special: return Color.clusterMagentaInk
        }
    }

    static func soft(_ kind: WidgetSummary.Item.Kind) -> Color {
        switch kind {
        case .meeting: return Color.accentSoft
        case .birthday: return Color.clusterOrangeSoft
        case .special: return Color.clusterMagentaSoft
        }
    }
}

extension Font {
    /// D-day 큰 글씨 — 둥근 숫자. 크기는 글자 설정을 따른다.
    static func scaledRounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight, design: .rounded)
    }
}

// MARK: - 화면

/// **세상에서 가장 단순하게** (2026-11-06 사용자) — 얼굴 + 한 문장. 앱 이름 글자 · 날짜 · 종류 아이콘 · 구분선 · 꼬리표를 모두 뺐다.
/// 색은 D-day 하나(종류 색)뿐이고, 나머지는 조용하다. 그다음 것은 알약 둘로 맨 아래에.
struct UpcomingWidgetView: View {
    let entry: UpcomingEntry
    @Environment(\.widgetFamily) private var family

    private var today: Int { WidgetDay.number(of: entry.date) }

    /// 지난 날은 빼고 가까운 것부터 — 요약을 쓴 뒤 날이 지났을 수 있다.
    private var lines: [WidgetSummary.Item] {
        guard let summary = entry.summary else { return [] }
        return (summary.meetings + summary.days).filter { $0.day >= today }.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return TimeOfDay.sortKey($0.minute) < TimeOfDay.sortKey($1.minute)
        }
    }

    private var hero: WidgetSummary.Item? { lines.first }
    private var rest: [WidgetSummary.Item] { Array(lines.dropFirst()) }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemSmall: home(compact: true)
        default: home(compact: false)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular: AccessoryWidgetBackground()
        case .accessoryRectangular, .accessoryInline: Color.clear
        default: Color.raised
        }
    }

    // MARK: 홈 화면

    private func home(compact: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let summary = entry.summary {
                    if summary.mode == .countsOnly {
                        countsOnly(summary, compact: compact)
                    } else if let hero {
                        heroView(hero, compact: compact)
                    } else {
                        quiet("다가오는 약속이 없습니다", "다음 만남을 적어 두면 여기에 보입니다", compact: compact)
                    }
                } else {
                    quiet("앱을 한 번 열어 주세요", "다가오는 약속이 여기에 보입니다", compact: compact)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // 앱 표시는 잎 하나 — 글자는 두지 않는다.
            Image(systemName: "leaf.fill")
                .font(.scaled(11, weight: .semibold))
                .foregroundStyle(Color.faint)
                .widgetAccentable()
        }
    }

    /// 얼굴 + 한 문장. 작은 것은 세로로, 중간 것은 얼굴을 왼쪽에.
    private func heroView(_ item: WidgetSummary.Item, compact: Bool) -> some View {
        let faces = AvatarStack(avatars: item.avatars, more: item.moreCount, kind: item.kind, size: compact ? 40 : 52)
        return VStack(alignment: .leading, spacing: 0) {
            if compact {
                faces
                Spacer(minLength: 6)
                sentence(item, compact: true)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    faces
                    sentence(item, compact: false)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                if !rest.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(rest.prefix(2).enumerated()), id: \.offset) { _, next in
                            pill(next)
                        }
                    }
                }
            }
        }
        .widgetURL(link(item))
    }

    /// `D-DAY` 크게 · 제목 · `오늘 오후 6:00 · 김하늘 외 2명`.
    private func sentence(_ item: WidgetSummary.Item, compact: Bool) -> some View {
        let when = RelativeDay.phrase(days: today - item.day) + (item.minute.map { " " + TimeOfDay.text($0) } ?? "")
        let detail = [when, compact ? nil : item.names].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 2) {
            Text(WidgetSummary.dDay(day: item.day, today: today))
                .font(.scaledRounded(compact ? 28 : 30))
                .foregroundStyle(KindStyle.ink(item.kind))
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.title ?? KindStyle.label(item.kind))
                .font(.scaled(compact ? 14 : 15, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.scaled(11))
                .foregroundStyle(Color.muted)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 그다음 하나 — `D-5 저녁식사` 알약. 누르면 그것으로.
    private func pill(_ item: WidgetSummary.Item) -> some View {
        let text = Text(WidgetSummary.dDay(day: item.day, today: today) + " " + (item.title ?? KindStyle.label(item.kind)))
            .font(.scaled(11, weight: .medium))
            .foregroundStyle(KindStyle.ink(item.kind))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(KindStyle.soft(item.kind), in: Capsule())
        return Group {
            if let url = link(item) {
                Link(destination: url) { text }
            } else {
                text
            }
        }
    }

    /// 아무것도 없을 때 · 처음 — 한 줄만, 조용하게.
    private func quiet(_ main: String, _ sub: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text(main)
                .font(.scaled(14, weight: .semibold))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !compact {
                Text(sub)
                    .font(.scaled(11))
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// 앱 잠금 — 숫자 둘.
    private func countsOnly(_ summary: WidgetSummary, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: compact ? 12 : 20) {
                stat(summary.meetingCount, "약속", kind: .meeting)
                stat(summary.dayCount, compact ? "생일" : "생일 · 기념일", kind: .birthday)
            }
            Text("잠금 중 · 건수만")
                .font(.scaled(11))
                .foregroundStyle(Color.muted)
            Spacer(minLength: 0)
        }
    }

    private func stat(_ count: Int, _ label: String, kind: WidgetSummary.Item.Kind) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(count)")
                .font(.scaledRounded(30))
                .foregroundStyle(KindStyle.ink(kind))
                .widgetAccentable()
            Text(label)
                .font(.scaled(12, weight: .medium))
                .foregroundStyle(Color.muted)
                .lineLimit(1)
        }
    }

    // MARK: 잠금 화면

    private var circular: some View {
        VStack(spacing: 0) {
            if let hero {
                Text(hero.day == today ? "오늘" : WidgetSummary.dDay(day: hero.day, today: today))
                    .font(.scaledRounded(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: KindStyle.symbol(hero.kind))
                    .font(.scaled(9, weight: .semibold))
            } else {
                Image(systemName: "leaf.fill")
                    .font(.scaled(16))
            }
        }
        .widgetAccentable()
        .widgetURL(hero.flatMap(link))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let hero {
                Text(WidgetSummary.dDay(day: hero.day, today: today) + (hero.minute.map { " · " + TimeOfDay.text($0) } ?? ""))
                    .font(.scaled(12, weight: .semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                Text(hero.title ?? KindStyle.label(hero.kind))
                    .font(.scaled(14, weight: .bold))
                    .lineLimit(1)
                if let names = hero.names {
                    Text(names)
                        .font(.scaled(12))
                        .lineLimit(1)
                }
            } else {
                Text("느린 인연")
                    .font(.scaled(12, weight: .semibold))
                    .widgetAccentable()
                Text(entry.summary == nil ? "앱을 한 번 열어 주세요" : "다가오는 약속이 없습니다")
                    .font(.scaled(12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(hero.flatMap(link))
    }

    private var inline: some View {
        Group {
            if let hero {
                let time = hero.minute.map { " " + TimeOfDay.text($0) } ?? ""
                Text("\(Image(systemName: KindStyle.symbol(hero.kind))) \(RelativeDay.phrase(days: today - hero.day))\(time) · \(hero.title ?? KindStyle.label(hero.kind))")
            } else {
                Text("\(Image(systemName: "leaf.fill")) 다가오는 약속 없음")
            }
        }
        .widgetURL(hero.flatMap(link))
    }

    private func link(_ item: WidgetSummary.Item) -> URL? {
        guard let person = item.personID else { return nil }
        if let record = item.recordID { return AppLink.record(record, person: person) }
        return AppLink.person(person)
    }
}

/// 겹친 얼굴 — 사진이 있으면 사진, 없으면 첫 글자. 얼굴이 하나도 없으면(이름 숨김 · 사람 없음) 종류 그림 하나.
struct AvatarStack: View {
    let avatars: [WidgetSummary.Avatar]
    let more: Int
    let kind: WidgetSummary.Item.Kind
    let size: CGFloat

    var body: some View {
        let side = Font.scaledLength(size)
        HStack(spacing: -side * 0.28) {
            if avatars.isEmpty {
                ZStack {
                    Circle().fill(KindStyle.soft(kind))
                    Image(systemName: KindStyle.symbol(kind))
                        .font(.scaled(size * 0.4, weight: .semibold))
                        .foregroundStyle(KindStyle.ink(kind))
                }
                .frame(width: side, height: side)
                .widgetAccentable()
            }
            ForEach(Array(avatars.enumerated()), id: \.offset) { _, avatar in
                face(avatar, side: side)
            }
            if more > 0 {
                Text("+\(more)")
                    .font(.scaled(size * 0.34, weight: .semibold))
                    .foregroundStyle(Color.muted)
                    .frame(width: side, height: side)
                    .background(Color.chip, in: Circle())
                    .overlay(Circle().strokeBorder(Color.raised, lineWidth: 2))
            }
        }
    }

    private func face(_ avatar: WidgetSummary.Avatar, side: CGFloat) -> some View {
        Group {
            if let data = avatar.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(avatar.initial)
                    .font(.scaled(size * 0.4, weight: .semibold))
                    .foregroundStyle(KindStyle.ink(kind))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KindStyle.soft(kind))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.raised, lineWidth: 2))
    }
}
