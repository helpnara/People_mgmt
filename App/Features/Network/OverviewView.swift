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
                    HStack(spacing: 10) {
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
                    link("올해 처음 만난 사람", ids: overview.newThisYearIDs, keepOrder: true) { person in
                        person.firstMetDay.map { snapshot.phrase(forDay: $0) }
                    }
                    link("최근 \(quietMonths)개월 넘게 기록 없음", ids: overview.quietIDs, keepOrder: true) { person in
                        person.lastDay.map { "마지막 기록 " + snapshot.phrase(forDay: $0) }
                    }
                    link("아직 기록이 없는 사람", ids: overview.noRecordIDs, keepOrder: true) { _ in nil }
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
            Section {
                RecordedScopeNotice()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .task(id: OverviewKey(count: snapshot.people.count, months: quietMonths, today: snapshot.today)) {
            let people = snapshot.people.map {
                OverviewPerson(id: $0.id, name: $0.name, firstMetDay: $0.firstMetDay, lastDay: $0.lastDay)
            }
            let days = Int((Double(quietMonths) * DyadMetricsCalculator.daysPerMonth).rounded())
            withFirstMet = snapshot.people.filter { $0.firstMetDay != nil }.count
            overview = NetworkOverview.compute(people: people, today: snapshot.today, yearStart: snapshot.yearStart,
                                               yearEnd: snapshot.yearEnd, neglectDays: days)
        }
    }

    private var withRecords: Int { snapshot.people.count - (overview?.noRecordIDs.count ?? 0) }

    private struct OverviewKey: Hashable {
        let count: Int
        let months: Int
        let today: Int
    }

    private func link(_ title: String, ids: [UUID], keepOrder: Bool,
                      detail: @escaping (NetworkSnapshot.PersonInfo) -> String?) -> some View {
        NavigationLink {
            PeopleByIDsView(title: title, people: keepOrder ? snapshot.people(ids) : snapshot.peopleByName(ids), detail: detail)
        } label: {
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
