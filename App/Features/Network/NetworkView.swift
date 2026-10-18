import Combine
import Core
import SwiftData
import SwiftUI

/// 목록 위 단추가 내 인맥을 여는 길.
struct NetworkRoute: Hashable {
    let tab: NetworkView.Tab
}

/// 사람을 가리키는 값 — 인맥 화면은 값(`NetworkSnapshot`)으로 그리므로, 누르면 이 값으로 사람 상세를 연다.
struct PersonID: Hashable {
    let id: UUID
}

/// **내 인맥** (6번째 묶음 · FR-045 · 047 · 048). 목록 위 단추로 연다 (2026-10-18 사용자 결정).
///
/// 관계도 · 특성 · 돌아보기 셋. 자료는 따로 연 문맥에서 값으로 만들어 그린다 — 주 스레드를 막지 않는다.
/// **사람을 점수화하지 않는다** (ADR-0004) — 순위 · 점수가 없고, 모든 칸은 눌러서 그 사람들을 본다.
struct NetworkView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case graph, traits, overview
        var id: String { rawValue }
        var label: String {
            switch self {
            case .graph: return "관계도"
            case .traits: return "특성"
            case .overview: return "돌아보기"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @State private var tab: Tab
    @State private var snapshot: NetworkSnapshot?
    @State private var dataVersion = 0

    init(initialTab: Tab = .graph) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("보기", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ZStack {
                Color.ground.ignoresSafeArea()
                if let snapshot {
                    if snapshot.isEmpty {
                        ContentUnavailableView("아직 사람이 없습니다", systemImage: "person.3",
                                               description: Text("사람을 적으면 여기에 인맥이 그려집니다."))
                    } else {
                        switch tab {
                        case .graph: RelationGraphView(snapshot: snapshot)
                        case .traits: TraitsView(snapshot: snapshot)
                        case .overview: OverviewView(snapshot: snapshot)
                        }
                    }
                } else {
                    ProgressView("인맥을 그리는 중…")
                }
            }
        }
        .background(Color.ground)
        .navigationTitle("내 인맥")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            dataVersion += 1
        }
        .task(id: dataVersion) {
            snapshot = await NetworkSnapshotBuilder.build(container: context.container)
        }
    }
}

/// 맨 아래 고지 (요구사항 5.5 원칙 3).
struct RecordedScopeNotice: View {
    var body: some View {
        Label("내가 기록한 범위 기준입니다. 적지 않은 만남은 계산되지 않습니다.", systemImage: "info.circle")
            .font(.scaled(12))
            .foregroundStyle(Color.muted)
    }
}

/// 값(`PersonID`)으로 사람 상세를 연다. 그 한 사람만 찾는다 — 전원을 읽지 않는다.
struct PersonByIDView: View {
    @Query private var found: [Person]

    init(id: UUID) {
        _found = Query(filter: #Predicate<Person> { $0.uuid == id })
    }

    var body: some View {
        if let person = found.first {
            PersonDetailView(person: person)
        } else {
            ContentUnavailableView("찾을 수 없는 사람입니다", systemImage: "person.slash")
        }
    }
}

extension NetworkSnapshot {
    /// id 들을 사람으로 — 차례는 받은 그대로.
    func people(_ ids: [UUID]) -> [PersonInfo] {
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// 이름 순으로.
    func peopleByName(_ ids: [UUID]) -> [PersonInfo] {
        NameSort.sorted(people(ids), name: \.name, createdAt: { _ in Date.distantPast })
    }
}
