import Core
import SwiftData
import SwiftUI

/// 한 해 돌아보기로 가는 길 (값으로 연다 — 이슈 16).
struct YearReviewRoute: Hashable {
    let year: Int
}

/// **한 해 돌아보기** (FR-059 · D-67 · 2026-11-03 사용자) — 내 인맥 → 돌아보기 맨 위 `2026년 돌아보기`.
///
/// 해를 앞뒤로 넘기며 본다. 숫자는 모두 나 단위다 — 사람 이름을 기록 수로 줄 세우지 않는다(ADR-0004).
/// 셈은 `Core.YearInReview` 하나, 재료는 `YearReviewData`(따로 연 문맥에서 한 번).
struct YearReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var data: YearReviewData?
    @State private var year: Int
    @State private var summary: YearInReview.Summary?
    /// 사람의 흐름 명단 넷 — 셈과 함께 만든다 (이슈 78).
    @State private var lists: YearReviewData.Lists?
    /// 누른 달 막대 — 그달 기록을 아래에 보인다. 해를 넘기면 비운다 (이슈 79).
    @State private var chosenMonth: Int?
    /// 고를 수 있는 해 — 재료를 읽을 때 한 번 센다(본문에서 기록 전부를 훑지 않는다 · CLAUDE.md).
    @State private var years: [Int] = []

    init(route: YearReviewRoute) {
        _year = State(initialValue: route.year)
    }

    var body: some View {
        List {
            if let summary {
                Section { pager }
                peopleSections(summary)
                recordSections(summary)
                if summary.isEmpty {
                    Section {
                        Text("이 해에는 기록도, 처음 만난 사람도 없습니다.")
                            .font(.scaled(14))
                            .foregroundStyle(Color.muted)
                    }
                }
                Section {
                    Text("오늘까지의 기록만 셉니다. 예정된 만남은 그날이 온 뒤에 들어갑니다. 처음 만난 사람은 처음 만난 날을 적은 사람만 셉니다.")
                        .font(.scaled(12))
                        .foregroundStyle(Color.muted)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(yearText + "년 돌아보기")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard data == nil else { return }
            let built = await YearReviewData.build(container: context.container)
            data = built
            years = built.years
            let counted = await Self.summarize(built, year: year)
            summary = counted.summary
            lists = counted.lists
        }
        .onChange(of: year) { _, newYear in
            chosenMonth = nil
            guard let data else { return }
            Task {
                let counted = await Self.summarize(data, year: newYear)
                // 빨리 넘기면 앞의 셈이 늦게 끝날 수 있다 — 지금 고른 해의 것만 쓴다.
                if year == newYear {
                    summary = counted.summary
                    lists = counted.lists
                }
            }
        }
    }

    /// 수 세 칸 · 함께한 사람 · 처음 만난 사람 · 사람의 흐름 — 본문에서 떼어 둔다(빌드 45 교훈).
    @ViewBuilder
    private func peopleSections(_ summary: YearInReview.Summary) -> some View {
        Section {
            AdaptiveStack(spacing: 10) {
                ReviewTile(value: summary.recordCount, label: "기록")
                ReviewTile(value: summary.peopleCount, label: "함께한\n사람")
                ReviewTile(value: summary.newlyMet.count, label: "처음\n만난 사람")
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            if summary.peopleCount > 0, let lists {
                NavigationLink(value: lists.together) {
                    LabeledContent("함께한 사람 보기") {
                        Text("\(summary.peopleCount)명").monospacedDigit()
                    }
                    .font(.scaled(15))
                }
                .accessibilityIdentifier("yearTogether")
            }
            if !summary.newlyMet.isEmpty {
                NavigationLink(value: PeopleListRoute(title: yearText + "년 처음 만난 사람", ids: summary.newlyMet,
                                                      fill: nil, detail: .firstMet)) {
                    LabeledContent("처음 만난 사람 보기") {
                        Text("\(summary.newlyMet.count)명").monospacedDigit()
                    }
                    .font(.scaled(15))
                }
            }
        } footer: {
            Text(comparisonText(summary))
        }
        if summary.peopleCount > 0 || summary.resting > 0 {
            Section {
                flowRow("새로 함께한 사람", summary.fresh, symbol: "sparkles", route: lists?.fresh, id: "yearFresh")
                flowRow("다시 함께한 사람", summary.returning, symbol: "arrow.triangle.2.circlepath",
                        route: lists?.returning, id: "yearReturning")
                flowRow("쉬어 간 사람", summary.resting, symbol: "moon.zzz", route: lists?.resting, id: "yearResting")
            } header: {
                Text("사람의 흐름")
            } footer: {
                FootnoteText("새로는 이 해에 처음 기록한 사람, 다시는 그 앞 해에도 기록이 있던 사람입니다. 쉬어 간 사람은 지난해엔 함께했는데 이 해엔 기록이 없는 사람입니다. 누르면 명단을 봅니다 — 기록 수가 아니라 날짜 차례입니다.")
            }
        }
    }

    /// 달마다 기록 · 누른 달의 기록 · 기록 유형 — 본문 한 식이 길면 컴파일러가 형식을 제때 못 맞춘다(빌드 45 교훈)라 떼어 둔다.
    @ViewBuilder
    private func recordSections(_ summary: YearInReview.Summary) -> some View {
        if summary.recordCount > 0 {
            Section {
                MonthBars(monthly: summary.monthly, chosen: chosenMonth) { month in
                    chosenMonth = chosenMonth == month ? nil : month
                }
                .padding(.vertical, 8)
                if let month = summary.busiestMonth {
                    Text("가장 기록이 많은 달은 \(month)월 (\(summary.monthly[month - 1])건)")
                        .font(.scaled(14))
                        .foregroundStyle(Color.bodyText)
                }
            } header: {
                Text("달마다 기록")
            } footer: {
                Text(monthFooter(summary))
            }
            if let month = chosenMonth, (1...12).contains(month), summary.monthly[month - 1] > 0 {
                Section {
                    MonthRecordsList(ids: summary.monthRecords[month - 1])
                } header: {
                    Text("\(month)월 기록 \(summary.monthly[month - 1])건")
                }
                .id(month)
            }
            Section("기록 유형") {
                let top = summary.types.first?.count ?? 1
                ForEach(summary.types, id: \.type) { item in
                    TypeRow(type: RecordType.named(item.type), count: item.count, top: top)
                }
            }
        }
    }

    /// 연도는 자릿수 쉼표 없이 (`2,026년` 이 되지 않게).
    private var yearText: String { String(year) }

    /// 기록 수만 · 사람 수만큼은 주 스레드 밖에서 센다 — 명단 넷도 함께 (이슈 78).
    private static func summarize(_ data: YearReviewData, year: Int) async -> (summary: YearInReview.Summary, lists: YearReviewData.Lists) {
        await Task.detached(priority: .userInitiated) {
            let summary = data.summary(of: year)
            return (summary, data.lists(for: summary))
        }.value
    }

    private func monthFooter(_ summary: YearInReview.Summary) -> String {
        var parts = ["막대를 누르면 그달 기록이 아래에 보입니다. 다시 누르면 닫힙니다."]
        if summary.unknownMonth > 0 {
            parts.append("연도만 적은 기록 \(summary.unknownMonth)건은 달 막대에 들지 않습니다.")
        }
        return parts.joined(separator: " ")
    }

    /// 해 넘기기 — 앞 해 · 뒤 해가 고를 수 있는 해에 있을 때만.
    private var pager: some View {
        let index = years.firstIndex(of: year)
        let earlier = index.flatMap { $0 > 0 ? years[$0 - 1] : nil }
        let later = index.flatMap { $0 + 1 < years.count ? years[$0 + 1] : nil }
        return HStack {
            Button {
                if let earlier { year = earlier }
            } label: {
                Image(systemName: "chevron.left").font(.scaled(17, weight: .semibold)).tapTarget()
            }
            .buttonStyle(.borderless)
            .disabled(earlier == nil)
            .accessibilityLabel("앞 해")
            Spacer()
            Text(yearText + "년")
                .font(.scaled(20, weight: .bold))
                .foregroundStyle(Color.ink)
            Spacer()
            Button {
                if let later { year = later }
            } label: {
                Image(systemName: "chevron.right").font(.scaled(17, weight: .semibold)).tapTarget()
            }
            .buttonStyle(.borderless)
            .disabled(later == nil)
            .accessibilityLabel("뒤 해")
        }
    }

    /// 사람의 흐름 한 줄 — 사람이 있으면 누르면 명단 (이슈 78).
    @ViewBuilder
    private func flowRow(_ title: String, _ count: Int, symbol: String, route: PeopleListRoute?, id: String) -> some View {
        let content = LabeledContent {
            Text("\(count)명").monospacedDigit()
        } label: {
            Label(title, systemImage: symbol)
        }
        .font(.scaled(15))
        if count > 0, let route {
            NavigationLink(value: route) { content }
                .accessibilityIdentifier(id)
        } else {
            content
        }
    }

    private func comparisonText(_ summary: YearInReview.Summary) -> String {
        let base = comparison(summary)
        // 올해는 아직 끝나지 않았다 — 지난해 한 해 전체와 견주는 것임을 밝힌다.
        guard summary.year == data?.currentYear else { return base }
        return "올해는 오늘까지 센 수입니다. " + base
    }

    private func comparison(_ summary: YearInReview.Summary) -> String {
        let previous = String(summary.year - 1) + "년"
        guard summary.previousRecordCount > 0 else {
            return summary.recordCount > 0 ? previous + "에는 기록이 없습니다." : "기록이 쌓이면 지난해와 견줘 봅니다."
        }
        let gap = summary.recordCount - summary.previousRecordCount
        if gap == 0 { return previous + "과 같은 \(summary.previousRecordCount)건입니다." }
        return previous + " \(summary.previousRecordCount)건보다 \(abs(gap))건 " + (gap > 0 ? "많습니다." : "적습니다.")
    }
}

private struct ReviewTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.scaled(26, weight: .bold))
                .foregroundStyle(Color.ink)
                .monospacedDigit()
            Text(label)
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// 1월 ~ 12월 막대 — 가장 많은 달이 꽉 찬 높이. 기록이 있는 달은 **누르는 단추**다(이슈 79) — 누른 달만 진하게, 나머지는 옅게.
/// 목록 한 줄 안에 단추가 열둘이라 `.borderless` 로 둔다 — 아니면 줄 전체가 한 단추가 되어 어느 달을 눌러도 같이 눌린다.
private struct MonthBars: View {
    let monthly: [Int]
    let chosen: Int?
    let choose: (Int) -> Void

    var body: some View {
        let top = max(monthly.max() ?? 0, 1)
        let height = Font.scaledLength(90)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(monthly.enumerated()), id: \.offset) { index, count in
                let month = index + 1
                if count > 0 {
                    Button {
                        choose(month)
                    } label: {
                        column(month: month, count: count, top: top, height: height)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(month)월 \(count)건")
                    .accessibilityHint(chosen == month ? "눌러서 닫습니다" : "눌러서 그달 기록을 봅니다")
                    .accessibilityAddTraits(chosen == month ? .isSelected : [])
                    .accessibilityIdentifier("monthBar\(month)")
                } else {
                    column(month: month, count: 0, top: top, height: height)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: height + Font.scaledLength(36), alignment: .bottom)
    }

    private func column(month: Int, count: Int, top: Int, height: CGFloat) -> some View {
        let dimmed = chosen != nil && chosen != month
        return VStack(spacing: 4) {
            if count > 0 {
                Text("\(count)")
                    .font(.scaled(10, weight: chosen == month ? .bold : .regular))
                    .foregroundStyle(chosen == month ? Color.accent : Color.muted)
                    .monospacedDigit()
            }
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(count > 0 ? Color.accent.opacity(dimmed ? 0.3 : 1) : Color.rule)
                .frame(height: count > 0 ? max(height * CGFloat(count) / CGFloat(top), 4) : 2)
            Text("\(month)")
                .font(.scaled(10, weight: chosen == month ? .bold : .regular))
                .foregroundStyle(chosen == month ? Color.accent : Color.muted)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

/// 누른 달의 기록 (이슈 79) — 그 기록들만 찾는다(전부 읽지 않는다). 차례는 받은 id 그대로(날이 이른 것부터 · `Core.YearInReview`).
/// 줄은 홈의 최근 기록과 같은 줄(유형 · 날짜 · 함께한 사람 · 표시명), 누르면 기록 상세.
private struct MonthRecordsList: View {
    let ids: [UUID]
    @Query private var found: [Record]

    init(ids: [UUID]) {
        self.ids = ids
        _found = Query(filter: #Predicate<Record> { ids.contains($0.uuid) })
    }

    var body: some View {
        // 한 달 기록(수십 건)만 받은 차례로 맞춘다 — 저장소를 읽지도, 사람 전원을 훑지도 않는다. 목록 안의 한 칸이라
        // `.task` 로 상태에 담으면 빈 목록에 붙은 작업이 돌지 않는다(ForEach 의 수식어는 줄마다 붙는다).
        let byID = Dictionary(found.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        ForEach(ids.compactMap { byID[$0] }) { record in
            if !record.isGone {
                NavigationLink(value: record) {
                    RecentRecordRow(record: record)
                }
                .accessibilityIdentifier("monthRecordRow")
            }
        }
    }
}

/// 기록 유형 한 줄 — 그림 · 이름 · 막대 · 수.
private struct TypeRow: View {
    let type: RecordType
    let count: Int
    let top: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: type.symbol)
                    .foregroundStyle(Color.accent)
                    .frame(width: Font.scaledLength(22))
                Text(type.label)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(count)건")
                    .foregroundStyle(Color.muted)
                    .monospacedDigit()
            }
            .font(.scaled(15))
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.accentSoft)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accent)
                            .frame(width: proxy.size.width * CGFloat(count) / CGFloat(max(top, 1)))
                    }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
