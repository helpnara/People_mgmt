import Core
import SwiftUI

/// **돌아보기** — 내 인연 전체 (FR-045). 활성 인원 · 올해 새로 만난 사람 · 최근 기록 없는 사람 · 아직 기록이 없는 사람.
/// 말은 중립으로 (원칙 5): `소홀한 인연` 이 아니라 `최근 기록 없음`.
struct OverviewView: View {
    let snapshot: NetworkSnapshot

    /// 최근 기록 없음의 기준 개월. 기기 편의라 UserDefaults.
    @AppStorage("network.quietMonths") private var quietMonths = 6
    @State private var overview: NetworkOverview?
    /// 처음 만난 날을 적은 사람 수 — 자료가 바뀔 때 한 번 센다 (본문에서 전원을 훑지 않는다).
    @State private var withFirstMet = 0

    var body: some View {
        List {
            if let overview {
                Section {
                    // 큰 글씨에서는 세 칸을 위아래로 (D-33).
                    AdaptiveStack(spacing: 10) {
                        Tile(value: overview.total, label: "사람")
                        Tile(value: overview.activeCount, label: "최근 12개월\n기록 있음")
                        Tile(value: overview.newThisYearIDs.count, label: "올해\n처음 만남")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                } footer: {
                    // 숫자가 무엇으로 세어지는지 · 지금 얼마나 채워졌는지 (사용자 요청 · 2026-10-18).
                    Text("최근 12개월은 기록 날짜로 셉니다 — 기록이 있는 사람 \(withRecords)명 / \(overview.total)명. 올해 처음 만남은 처음 만난 날을 적은 사람만 셉니다 — 적은 사람 \(withFirstMet)명 / \(overview.total)명.")
                }
                Section {
                    link("올해 처음 만난 사람", ids: overview.newThisYearIDs, detail: .firstMet)
                    link("최근 \(quietMonths)개월 넘게 기록 없음", ids: overview.quietIDs, detail: .lastRecord)
                    link("아직 기록이 없는 사람", ids: overview.noRecordIDs, detail: .none)
                } footer: {
                    Menu {
                        Picker("기준", selection: $quietMonths) {
                            Text("3개월").tag(3)
                            Text("6개월").tag(6)
                            Text("12개월").tag(12)
                        }
                    } label: {
                        Label("최근 기록 없음의 기준 바꾸기 · 지금 \(quietMonths)개월", systemImage: "slider.horizontal.3")
                            .font(.scaled(13))
                    }
                }
            } else {
                ProgressView()
            }
            changesSection
            Section {
                RecordedScopeNotice()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .task(id: OverviewKey(generation: snapshot.generation, months: quietMonths)) {
            let people = snapshot.people.map {
                OverviewPerson(id: $0.id, name: $0.name, firstMetDay: $0.firstMetDay, lastDay: $0.lastDay)
            }
            let days = Int((Double(quietMonths) * DyadMetricsCalculator.daysPerMonth).rounded())
            withFirstMet = snapshot.readiness.withFirstMet
            overview = NetworkOverview.compute(people: people, today: snapshot.today, yearStart: snapshot.yearStart,
                                               yearEnd: snapshot.yearEnd, neglectDays: days)
        }
    }

    /// **모임의 변화** (8번째 묶음 · D-32) — 해마다 모임이 (D-59) 어떻게 변했나. 말은 중립으로 (원칙 5).
    /// 누르면 그 시점 그 모임의 사람들. 최근 것부터.
    @ViewBuilder
    private var changesSection: some View {
        let timeline = snapshot.timeline
        Section {
            if timeline.changes.isEmpty {
                Text(timeline.slices.isEmpty
                     ? "기록이 두 해를 넘게 쌓이면 해마다 모임이 어떻게 변했는지 보입니다."
                     : "아직 해끼리 견줄 만큼 모임이 드러나지 않았습니다. 한 해에 진한 선이 \(TemporalNetwork.minimumStrongEdges)개 넘게 쌓이면 모임의 변화가 보입니다.")
                    .font(.scaled(14))
                    .foregroundStyle(Color.muted)
            } else {
                ForEach(timeline.changes.prefix(30)) { change in
                    NavigationLink(value: PeopleListRoute(title: "\(change.sliceLabel) · \(change.name)", ids: change.memberIDs)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(change.name) — \(change.phrase)")
                                .font(.scaled(15))
                                .foregroundStyle(Color.ink)
                            Text(change.sliceLabel + (change.beforeUse ? " · 앱을 쓰기 전 시기" : "") + " · \(change.memberIDs.count)명")
                                .font(.scaled(12))
                                .foregroundStyle(Color.muted)
                        }
                    }
                }
            }
        } header: {
            Text("모임의 변화")
        } footer: {
            Text("해마다 그 해 12개월의 함께한 기록 · 아는 사이 · 소개로 모임을 다시 찾고, 전 해와 사람이 얼마나 겹치는지로 견줍니다 — 작은 모임은 절반 넘게 겹치면 같은 모임으로 보고, 쉬었다가 다시 보인 모임은 다시 모임으로 알립니다. 여럿이 함께한 기록은 사람 수로 나눠 셉니다. 소속은 날짜가 없어 넣지 않습니다. 앱을 쓰기 시작한 뒤의 시기가 더 정확합니다.")
        }
    }

    private var withRecords: Int { snapshot.people.count - (overview?.noRecordIDs.count ?? 0) }

    private struct OverviewKey: Hashable {
        let generation: UUID
        let months: Int
    }

    private func link(_ title: String, ids: [UUID], detail: PeopleRowDetail) -> some View {
        // 값으로 연다 (이슈 16) — 화면을 직접 밀면 그 안에서 사람을 열 때 목록이 빠진다.
        NavigationLink(value: PeopleListRoute(title: title, ids: ids, fill: nil, detail: detail)) {
            LabeledContent(title) {
                Text("\(ids.count)명").monospacedDigit()
            }
            .font(.scaled(15))
        }
        .disabled(ids.isEmpty)
    }
}

private struct Tile: View {
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
