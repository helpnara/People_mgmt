import Core
import SwiftUI

/// 사람 상세의 **관계 돌아보기** (FR-044 · 요구사항 5.5 이인 지표).
///
/// "내가 이 인연을 어떻게 돌보고 있는가" 에만 답한다 — 점수 · 순위가 없다 (ADR-0004).
/// 줄마다 누르면 근거가 된 기록이 나온다 (원칙 2). 기록이 모자라면 값 대신 몇 건부터 보이는지 말한다 (원칙 4).
struct RelationshipReviewSection: View {
    let person: Person

    /// 지표는 기록이 바뀔 때 한 번 센다 (전수조사 이슈 18) — 본문이 그려질 때마다 셈하지 않는다.
    @State private var metrics: DyadMetrics?

    /// 다시 셀 때 — 기록 수 · 가장 최근에 고친 기록 · 처음 만난 날이 바뀌면.
    private struct Key: Hashable {
        let count: Int
        let latestEdit: Date?
        let firstMet: Date?
    }

    var body: some View {
        // 지운 기록의 고친 날을 읽지 않는다 — 지운 직후 다시 그려질 때 앱이 꺼진다 (이슈 27).
        let records = LaunchTiming.measure("상세 · 관계 돌아보기 기록 거르기") { (person.records ?? []).filter { !$0.isGone } }
        Section {
            if let metrics {
                content(metrics)
            }
        } header: {
            Text("관계 돌아보기")
        } footer: {
            // 무엇을 얼마나 적으면 무엇이 보이는지 — 앱이 알려 줄 수 있는 것의 조건 (사용자 요청 · 2026-10-18).
            Text("내가 기록한 범위 기준입니다. 적지 않은 만남은 계산되지 않습니다. 이 사람과의 기록이 쌓이면 만남 빈도(\(DyadMetricsCalculator.frequencyMinimum)건) · 흐름(\(DyadMetricsCalculator.trendMinimum)건) · 함께한 일(\(DyadMetricsCalculator.diversityMinimum)건)이 차례로 열립니다. 처음 만난 날을 적으면 인연 기간이 그날부터 셉니다.")
        }
        .id(RelationshipReviewSection.anchor)
        .task(id: Key(count: records.count, latestEdit: records.map(\.updatedAt).max(), firstMet: person.firstMetDate)) {
            // 바깥의 `records` 를 붙잡지 않고 다시 읽는다 — 이 화면이 가진 값(`person`)만 쓴다.
            metrics = DyadMetricsCalculator.compute(
                records: (person.records ?? []).filter { !$0.isGone }.map { MetricRecord(id: $0.uuid, day: DayIndex.of($0.occurredAt), type: $0.recordType) },
                firstMetDay: person.firstMetDate.map { DayIndex.of($0) },
                today: DayIndex.of(Date()))
        }
    }

    @ViewBuilder
    private func content(_ metrics: DyadMetrics) -> some View {
            if metrics.total == 0 {
                Text("기록이 쌓이면 이 인연을 돌아볼 수 있습니다.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            } else {
                row("기록", value: "\(metrics.total)건 · 최근 12개월 \(metrics.lastYear)건",
                    evidence: metrics.pastIDs, title: "기록 \(metrics.total)건")
                if let days = metrics.daysSinceLast {
                    row("마지막 기록", value: RelativeDay.phrase(days: days),
                        evidence: metrics.lastID.map { [$0] } ?? [], title: "마지막 기록")
                }
                if let span = metrics.spanDays {
                    row("인연 기간", value: MetricText.span(days: span) + (metrics.spanFromFirstMeeting ? " · 처음 만난 날부터" : " · 첫 기록부터"),
                        evidence: [metrics.lastID, metrics.firstID].compactMap { $0 }.uniqued(), title: "처음과 마지막 기록")
                }
                row("만남 빈도",
                    value: metrics.perMonth.map(MetricText.frequency(perMonth:)) ?? waiting(DyadMetricsCalculator.frequencyMinimum, have: metrics.total),
                    evidence: metrics.perMonth == nil ? [] : metrics.pastIDs, title: "만남 빈도의 근거")
                row("흐름",
                    value: metrics.trend.map { "\(MetricText.trend($0)) · 최근 6개월 \(metrics.recentHalf)건 · 그 전 6개월 \(metrics.previousHalf)건" }
                        ?? waiting(DyadMetricsCalculator.trendMinimum, have: metrics.total),
                    evidence: metrics.trend == nil ? [] : metrics.recentHalfIDs + metrics.previousHalfIDs, title: "최근 12개월 기록")
                row("함께한 일",
                    value: metrics.diversityClass.map { "\(MetricText.diversity($0)) · " + typeSummary(metrics.typeCounts) }
                        ?? waiting(DyadMetricsCalculator.diversityMinimum, have: metrics.total),
                    evidence: metrics.diversityClass == nil ? [] : metrics.pastIDs, title: "함께한 일")
            }
    }

    /// 문턱 아래 — 몇 건부터 보이고, 지금 몇 건이며, 몇 건 더 적으면 되는지 (원칙 4 · 사용자 요청).
    private func waiting(_ minimum: Int, have: Int) -> String {
        "기록 \(minimum)건부터 보입니다 · 지금 \(have)건, \(max(minimum - have, 1))건 더"
    }

    /// CI 스크린샷이 이 구역으로 내려오려고 쓰는 자리 이름.
    static let anchor = "relationshipReview"

    private func typeSummary(_ counts: [DyadMetrics.TypeCount]) -> String {
        counts.prefix(3).map { "\(RecordType.named($0.type).label) \($0.count)" }.joined(separator: " · ")
    }

    @ViewBuilder
    private func row(_ label: String, value: String, evidence: [UUID], title: String) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.scaled(13)).foregroundStyle(Color.muted)
            Text(value).font(.scaled(16)).foregroundStyle(evidence.isEmpty ? Color.muted : Color.ink)
        }
        .accessibilityElement(children: .combine)
        if evidence.isEmpty {
            content
        } else {
            // 값으로 연다 (이슈 16).
            NavigationLink(value: EvidenceRoute(title: title, recordIDs: evidence, viewerID: person.uuid)) {
                content
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
