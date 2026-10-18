import Core
import SwiftUI

/// **입력 상태** (D-31 · docs/input-readiness-review.md) — 내 입력이 어디까지 왔고, 무엇을 얼마나 더 적으면 무엇이 보이는지.
///
/// 점수를 매기는 대상은 **사람이 아니라 내 입력**이다 (ADR-0004). 종합 점수 하나로 묶지 않고 기능마다
/// `준비됨 · 거의 · 아직` 과 막대로 보인다. 빈 곳은 **채울 것 목록**으로 바로 채우러 간다 — 이름 순, 누르면 바로 편집.
struct ReadinessView: View {
    let snapshot: NetworkSnapshot

    @State private var items: [ReadinessItem] = []

    var body: some View {
        List {
            if !items.isEmpty {
                Section {
                    Text(InputReadiness.summary(items))
                        .font(.scaled(15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                } footer: {
                    Text("앱이 보여 주는 것은 모두 내가 적은 것에서 나옵니다. 기능마다 뜻을 갖는 최소 조건을 두고, 지금 입력이 거기까지 얼마나 왔는지 보입니다. 사람을 평가하는 점수가 아닙니다.")
                }
            }
            ForEach(items) { item in
                Section {
                    ReadinessRow(item: item)
                    fillLinks(item.feature)
                } header: {
                    Text(InputReadiness.title(item.feature))
                }
            }
            Section {
                RecordedScopeNotice()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 판정은 자료가 바뀔 때 한 번 (CLAUDE.md — 본문에서 세지 않는다).
        .task(id: snapshot.generation) {
            items = InputReadiness.evaluate(snapshot.readiness)
        }
    }

    /// 그 기능을 채우러 가는 목록들. 빈 것은 숨긴다.
    @ViewBuilder
    private func fillLinks(_ feature: ReadinessItem.Feature) -> some View {
        let gaps = snapshot.gaps
        switch feature {
        case .traits:
            fillLink("관계 유형이 빈 사람", ids: gaps.noRelationshipType, field: .relationshipType)
            fillLink("알게 된 경로가 빈 사람", ids: gaps.noMetThrough, field: .metThrough)
        case .firstMet:
            fillLink("처음 만난 날이 빈 사람", ids: gaps.noFirstMet, field: .firstMet)
        case .review:
            fillLink("아직 기록이 없는 사람", ids: gaps.noRecord, field: .record)
        case .graph:
            fillLink("아직 아무와도 이어지지 않은 사람", ids: gaps.unlinked, field: .acquaintances)
            if !gaps.singleParticipantRecords.isEmpty {
                NavigationLink(value: RecordFillRoute(title: "함께한 사람이 한 명뿐인 기록",
                                                      recordIDs: gaps.singleParticipantRecords)) {
                    LabeledContent("함께한 사람이 한 명뿐인 기록") {
                        Text("\(gaps.singleParticipantRecords.count)건").monospacedDigit()
                    }
                    .font(.scaled(15))
                }
            }
        case .groups:
            groupsStatus
        }
    }

    private func fillLink(_ title: String, ids: [UUID], field: FillField) -> some View {
        // 값으로 연다 (이슈 16). 목록에서 사람을 누르면 바로 편집 · 기록 쓰기.
        NavigationLink(value: PeopleListRoute(title: title, ids: ids, fill: field)) {
            LabeledContent(title) {
                Text("\(ids.count)명").monospacedDigit()
            }
            .font(.scaled(15))
        }
        .disabled(ids.isEmpty)
    }

    @ViewBuilder
    private var groupsStatus: some View {
        switch snapshot.communityStatus {
        case .shown:
            ForEach(snapshot.communities) { community in
                NavigationLink(value: PeopleListRoute(title: community.name, ids: community.memberIDs)) {
                    LabeledContent(community.name) {
                        Text("\(community.memberIDs.count)명").monospacedDigit()
                    }
                    .font(.scaled(15))
                }
            }
            Text("진한 선으로 서로 많이 이어진 사람들을 묶었습니다. 이름은 모임 안에서 가장 많은 소속 · 태그 · 알게 된 경로에서 제안합니다. 관계도에서 테두리로 보입니다.")
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
        case .noClearGroups:
            Text("연결은 넉넉하지만 아직 뚜렷하게 나뉘는 모임이 없습니다. 모임마다 함께한 기록을 남기거나 아는 사이를 이으면 드러납니다.")
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
        case .notEnoughLinks:
            EmptyView()
        }
    }
}

private struct ReadinessRow: View {
    let item: ReadinessItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 큰 글씨에서는 단계(준비됨 · 거의 · 아직)를 지금 상태 아래로 (D-33).
            AdaptiveStack {
                Text(item.current)
                    .font(.scaled(14))
                    .foregroundStyle(Color.bodyText)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(levelText)
                    .font(.scaled(12, weight: .semibold))
                    .foregroundStyle(item.level == .notYet ? Color.muted : Color.accent)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.rule.opacity(0.5))
                    Capsule()
                        .fill(item.level == .ready ? Color.accent : (item.level == .almost ? Color.accent.opacity(0.6) : Color.faint))
                        .frame(width: max(proxy.size.width * CGFloat(item.progress), 4))
                }
            }
            .frame(height: Font.scaledLength(6))
            Text(item.hint)
                .font(.scaled(13))
                .foregroundStyle(Color.muted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var levelText: String {
        switch item.level {
        case .ready: return "준비됨"
        case .almost: return "거의"
        case .notYet: return "아직"
        }
    }
}
