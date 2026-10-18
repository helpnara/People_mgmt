import Core
import SwiftData
import SwiftUI

/// **화면 이동은 값 하나로** (이슈 16).
///
/// 앱은 `NavigationStack(path:)` 하나에 값으로 쌓는다. 빌드 9 는 목록 · 근거 화면을 `NavigationLink { 화면 }`
/// (화면을 직접 만들어 미는 길)으로 열었다 — 그렇게 열린 화면에서 다시 값으로 사람을 열면 SwiftUI 가 쌓인 길을
/// 값으로 다시 맞추며 **방금 연 화면을 빼 버린다**. 사용자에게는 "열리는 듯하다가 목록 그대로" 로 보였다.
/// 그래서 목록도 근거도 값(`…Route`)으로 열고, 목적지는 뿌리(`PeopleListView`) 한 곳에 둔다.

/// 사람 목록 칸에 덧붙일 말.
enum PeopleRowDetail: Hashable {
    case none
    /// 처음 만난 날이 언제인가.
    case firstMet
    /// 마지막 기록이 언제인가.
    case lastRecord
}

/// 미지정 목록에서 무엇을 채우러 가는가 — 누르면 **바로 편집**이 열리고, 채우면 그 줄에 `채웠습니다` (D-31 · 이슈 16).
enum FillField: String, Hashable {
    case relationshipType, metThrough, organization, tags

    var label: String {
        switch self {
        case .relationshipType: return "관계 유형"
        case .metThrough: return "알게 된 경로"
        case .organization: return "소속"
        case .tags: return "태그"
        }
    }

    func isFilled(_ person: Person) -> Bool {
        switch self {
        case .relationshipType: return !(person.relationshipType ?? "").isEmpty
        case .metThrough: return !(person.metThrough ?? "").isEmpty
        case .organization: return !(person.organization ?? "").isEmpty
        case .tags: return !person.tags.isEmpty
        }
    }
}

/// 사람 몇 명을 보여 주는 길. 차례는 `ids` 그대로.
struct PeopleListRoute: Hashable {
    let title: String
    let ids: [UUID]
    var fill: FillField?
    var detail: PeopleRowDetail = .none
}

/// 지표의 근거 기록을 보여 주는 길.
struct EvidenceRoute: Hashable {
    let title: String
    let recordIDs: [UUID]
    let viewerID: UUID
}

/// `PeopleListRoute` 의 목적지. 그 사람들만 찾는다 — 전원을 읽지 않는다.
struct PeopleRouteView: View {
    let route: PeopleListRoute
    @Query private var found: [Person]
    @State private var editing: Person?

    init(route: PeopleListRoute) {
        self.route = route
        let ids = route.ids
        _found = Query(filter: #Predicate<Person> { ids.contains($0.uuid) })
    }

    var body: some View {
        let byID = Dictionary(found.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let people = route.ids.compactMap { byID[$0] }.filter { !$0.isGone }
        List {
            Section {
                ForEach(people) { person in
                    if let fill = route.fill {
                        // 채울 것 목록 — 누르면 바로 편집.
                        Button {
                            editing = person
                        } label: {
                            row(person, trailing: fill.isFilled(person) ? "채웠습니다" : "\(fill.label) 채우기",
                                done: fill.isFilled(person))
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: person) {
                            row(person, trailing: detailText(person), done: false)
                        }
                    }
                }
            } header: {
                Text("\(people.count)명")
            } footer: {
                if let fill = route.fill {
                    Text("누르면 바로 편집이 열립니다. \(fill.label)\(Josa.eulReul(fill.label)) 채우고 저장하면 이 목록에 채웠습니다로 표시됩니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { person in
            PersonEditView(mode: .edit(person)) { _ in }
        }
    }

    private func row(_ person: Person, trailing: String?, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink)
                if let subtitle = person.subtitle {
                    Text(subtitle).font(.scaled(13)).foregroundStyle(Color.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Label {
                    Text(trailing)
                } icon: {
                    if done { Image(systemName: "checkmark.circle.fill") }
                }
                .font(.scaled(12, weight: done ? .semibold : .regular))
                .foregroundStyle(done ? Color.accent : Color.faint)
                .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private func detailText(_ person: Person) -> String? {
        switch route.detail {
        case .none:
            return nil
        case .firstMet:
            return person.firstMetDate.map { RelativeDay.phrase(from: $0, to: Date(), calendar: .current) }
        case .lastRecord:
            return person.lastRecordAt.map { "마지막 기록 " + RelativeDay.phrase(from: $0, to: Date(), calendar: .current) }
        }
    }
}

/// `EvidenceRoute` 의 목적지 — 근거가 된 기록들, 받은 차례(최근 것부터).
struct EvidenceRouteView: View {
    let route: EvidenceRoute
    @Query private var records: [Record]
    @Query private var viewers: [Person]

    init(route: EvidenceRoute) {
        self.route = route
        let ids = route.recordIDs
        let viewerID = route.viewerID
        _records = Query(filter: #Predicate<Record> { ids.contains($0.uuid) })
        _viewers = Query(filter: #Predicate<Person> { $0.uuid == viewerID })
    }

    var body: some View {
        let byID = Dictionary(records.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = route.recordIDs.compactMap { byID[$0] }.filter { !$0.isGone }
        List {
            Section {
                if let viewer = viewers.first {
                    ForEach(ordered) { record in
                        NavigationLink(value: record) {
                            TimelineRow(record: record, viewer: viewer)
                        }
                    }
                }
            } header: {
                Text("\(ordered.count)건")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
