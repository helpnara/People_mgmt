import Core
import SwiftUI

/// 사람 상세 맨 위의 **인연 연표** (빌드 41 · 1.1 · FR-056 · 2026-11-02 사용자) — 마일스톤 선.
///
/// 처음 만남 · 첫 기록 · n번째 기록 · 가장 많이 만난 해 · 마지막 기록 · 다가오는 만남을 한 줄에 놓는다.
/// 표식을 누르면 그해 기록이 아래에서 올라온다. 점수 · 순위가 아니다(ADR-0004) — 기록에서 센 사실만.
/// 표식은 기록이 바뀔 때 한 번 센다(`.task`) — 본문에서 기록을 셈하지 않는다. 고르는 규칙은 `Core.RelationshipMilestones`.
struct MilestoneSection: View {
    let person: Person

    @State private var milestones: [RelationshipMilestones.Milestone] = []
    @State private var details: [String: String] = [:]
    @State private var summary: String?
    @State private var chosenYear: YearPick?

    struct YearPick: Identifiable {
        let year: Int
        var id: Int { year }
    }

    /// 다시 셀 때 — 기록 수 · 가장 최근에 고친 기록 · 처음 만난 날 · 그 정밀도가 바뀌면 (관계 돌아보기와 같은 열쇠).
    private struct Key: Hashable {
        let count: Int
        let latestEdit: Date?
        let firstMet: Date?
        let firstMetPrecision: Int
    }

    var body: some View {
        // 지운 기록의 고친 날을 읽지 않는다 — 지운 직후 다시 그려질 때 앱이 꺼진다 (이슈 27).
        let records = (person.records ?? []).filter { !$0.isGone }
        Section {
            if milestones.isEmpty {
                Text("처음 만난 날이나 함께한 기록을 적으면 이 사람과의 연표가 그려집니다.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let summary {
                        Text(summary)
                            .font(.scaled(14, weight: .medium))
                            .foregroundStyle(Color.bodyText)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                                Button {
                                    chosenYear = YearPick(year: milestone.year)
                                } label: {
                                    node(milestone, isFirst: index == 0, isLast: index == milestones.count - 1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("그해 기록을 봅니다")
                            }
                        }
                        // 가로 스크롤 칸은 내용 밖을 잘라 낸다 — 위아래에 여유를 두어 동그라미가 온전히 보이게.
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("인연 연표")
        }
        .task(id: Key(count: records.count, latestEdit: records.map(\.updatedAt).max(),
                      firstMet: person.firstMetDate, firstMetPrecision: person.firstMetPrecision)) {
            compute()
        }
        .sheet(item: $chosenYear) { pick in
            YearRecordsView(person: person, year: pick.year)
        }
    }

    /// 표식 하나 — 선 위의 동그라미(종류 그림) · 이름 · 날. 첫 표식은 왼쪽 선, 마지막 표식은 오른쪽 선이 없다.
    private func node(_ milestone: RelationshipMilestones.Milestone, isFirst: Bool, isLast: Bool) -> some View {
        let upcoming = milestone.kind == .upcoming
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.accent.opacity(0.35))
                    .frame(height: 2)
                ZStack {
                    Circle()
                        .fill(upcoming ? Color.raised : Color.accent)
                    // 테두리는 원 안쪽에 — 바깥으로 그리면 가로 스크롤 칸이 위아래 1pt 를 잘랐다 (빌드 41 실기기).
                    Circle()
                        .strokeBorder(Color.accent, lineWidth: 2)
                    Image(systemName: Self.symbol(milestone.kind))
                        .font(.scaled(12, weight: .semibold))
                        .foregroundStyle(upcoming ? Color.accent : Color.raised)
                }
                .frame(width: Font.scaledLength(28), height: Font.scaledLength(28))
                Rectangle()
                    .fill(isLast ? Color.clear : Color.accent.opacity(0.35))
                    .frame(height: 2)
            }
            Text(milestone.title)
                .font(.scaled(12, weight: .semibold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = details[milestone.id] {
                Text(detail)
                    .font(.scaled(11))
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: Font.scaledLength(86))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private static func symbol(_ kind: RelationshipMilestones.Kind) -> String {
        switch kind {
        case .firstMet: return "star.fill"
        case .firstRecord: return "flag.fill"
        case .countReached: return "rosette"
        case .busiestYear: return "calendar"
        case .lastRecord: return "clock.arrow.circlepath"
        case .upcoming: return "calendar.badge.clock"
        }
    }

    /// 표식 · 한 줄 · 표식 아래 글을 센다 — 기록이 바뀔 때만.
    private func compute() {
        let calendar = Calendar.current
        let records = (person.records ?? []).filter { !$0.isGone }
        let today = DayIndex.of(Date(), calendar: calendar)
        let byID = Dictionary(records.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let input = records.map {
            RelationshipMilestones.Record(id: $0.uuid, day: DayIndex.of($0.occurredAt, calendar: calendar),
                                          year: calendar.component(.year, from: $0.occurredAt))
        }
        let firstMetDay = person.firstMetDate.map { DayIndex.of($0, calendar: calendar) }
        let firstMetYear = person.firstMetDate.map { calendar.component(.year, from: $0) }
        milestones = RelationshipMilestones.make(records: input, firstMetDay: firstMetDay, firstMetYear: firstMetYear, today: today)
        summary = RelationshipMilestones.summary(records: input, firstMetDay: firstMetDay, firstMetYear: firstMetYear, today: today)
        var text: [String: String] = [:]
        for milestone in milestones {
            switch milestone.kind {
            case .firstMet:
                text[milestone.id] = person.firstMetDate.map { Self.compactDate($0, precision: person.firstMetPrecision) }
            case .busiestYear:
                text[milestone.id] = String(milestone.year) + "년 · " + String(milestone.count ?? 0) + "건"
            case .lastRecord, .upcoming:
                text[milestone.id] = RelativeDay.phrase(days: today - milestone.day)
            case .firstRecord, .countReached:
                text[milestone.id] = milestone.recordID.flatMap { byID[$0] }.map { Self.compactDate($0.occurredAt, precision: $0.occurredPrecision) }
            }
        }
        details = text
    }

    /// 표식 아래의 짧은 날 — `2026. 10. 31.` (좁은 칸에서 두 줄로 꺾이지 않게). 월까지 · 연도만은 `2021년 3월` · `2019년`.
    private static func compactDate(_ date: Date, precision: Int) -> String {
        ApproximateDate.label(of: date, precision: .of(precision)) ?? date.formatted(.dateTime.year().month(.defaultDigits).day())
    }
}

/// 연표의 표식을 누르면 올라오는 **그해 기록** — 타임라인과 같은 줄 · 차례. 누르면 기록 상세로.
struct YearRecordsView: View {
    let person: Person
    let year: Int

    @Environment(\.dismiss) private var dismiss
    @State private var records: [Record] = []

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    Text(String(year) + "년에는 함께한 기록이 없습니다.")
                        .font(.scaled(15))
                        .foregroundStyle(Color.muted)
                }
                ForEach(records) { record in
                    if !record.isGone {
                        NavigationLink(value: record) {
                            TimelineRow(record: record, viewer: person)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.ground)
            .navigationTitle(String(year) + "년 · 기록 " + String(records.count) + "건")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .appDestinations()
        }
        .task {
            let calendar = Calendar.current
            records = RecordStore.timeline(of: person).filter { calendar.component(.year, from: $0.occurredAt) == year }
        }
    }
}
