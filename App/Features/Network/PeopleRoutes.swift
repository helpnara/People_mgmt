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
/// `record` 만 기록 쓰기를 열고, 나머지는 사람 편집을 연다.
enum FillField: String, Hashable {
    case relationshipType, metThrough, organization, tags, firstMet, acquaintances, record

    var label: String {
        switch self {
        case .relationshipType: return "관계 유형"
        case .metThrough: return "알게 된 경로"
        case .organization: return "소속"
        case .tags: return "태그"
        case .firstMet: return "처음 만난 날"
        case .acquaintances: return "아는 사이"
        case .record: return "기록"
        }
    }

    /// 줄 끝에 쓰는 말 — 아직일 때.
    var action: String {
        switch self {
        case .record: return "기록 쓰기"
        case .acquaintances: return "아는 사람 고르기"
        default: return "\(label) 채우기"
        }
    }

    func isFilled(_ person: Person) -> Bool {
        switch self {
        case .relationshipType: return !(person.relationshipType ?? "").isEmpty
        case .metThrough: return !(person.metThrough ?? "").isEmpty
        case .organization: return !(person.organization ?? "").isEmpty
        case .tags: return !person.tags.isEmpty
        case .firstMet: return person.firstMetDate != nil
        case .acquaintances: return !person.acquaintances.isEmpty
        case .record: return !(person.records ?? []).isEmpty
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

/// 고칠 기록 몇 건을 보여 주는 길 — 누르면 바로 기록 수정 (D-31: 함께한 사람이 한 명뿐인 기록).
struct RecordFillRoute: Hashable {
    let title: String
    let recordIDs: [UUID]
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
    /// 받은 차례대로 맞춘 사람들. **본문에서 만들지 않는다** (전수조사 이슈 18) — `관계 유형이 빈 사람` 은 사람 전원일
    /// 수 있다. 찾은 수가 바뀔 때만 다시 맞추고, 지운 사람은 그려지는 줄에서만 거른다 (이슈 10 의 교훈).
    @State private var people: [Person] = []

    init(route: PeopleListRoute) {
        self.route = route
        let ids = route.ids
        _found = Query(filter: #Predicate<Person> { ids.contains($0.uuid) })
    }

    var body: some View {
        List {
            Section {
                ForEach(people) { person in
                    if person.isGone {
                        EmptyView()
                    } else if let fill = route.fill {
                        // 채울 것 목록 — 누르면 바로 편집.
                        Button {
                            editing = person
                        } label: {
                            row(person, trailing: fill.isFilled(person) ? "채웠습니다" : fill.action,
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
                    if fill == .record {
                        Text("누르면 그 사람과의 기록 쓰기가 바로 열립니다. 저장하면 이 목록에 채웠습니다로 표시됩니다.")
                    } else {
                        Text("누르면 바로 편집이 열립니다. \(fill.label)\(Josa.eulReul(fill.label)) 채우고 저장하면 이 목록에 채웠습니다로 표시됩니다.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: found.count) {
            people = orderedByIDs(route.ids, found, id: { $0.uuid })
        }
        .sheet(item: $editing) { person in
            if route.fill == .record {
                RecordEditView(mode: .create(anchor: person)) { _ in }
            } else {
                PersonEditView(mode: .edit(person)) { _ in }
            }
        }
    }

    private func row(_ person: Person, trailing: String?, done: Bool) -> some View {
        // 큰 글씨에서는 오른쪽 말(채우기 · 채웠습니다)을 이름 아래로 (D-33).
        AdaptiveStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink)
                if let subtitle = person.subtitle {
                    Text(subtitle).font(.scaled(13)).foregroundStyle(Color.muted).readableLineLimit(1)
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
                .foregroundStyle(done ? Color.accent : Color.muted)
                .readableLineLimit(1)
            }
        }
        .contentShape(Rectangle())
        // 구분선은 줄 왼쪽 끝부터 (이슈 28). 정하지 않으면 SwiftUI 가 오른쪽 `Label` 의 글자 시작에 맞춰
        // 구분선을 `처음 만난 날 채우기` 아래에만 짧게 그린다.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
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

/// 받은 id 차례대로 — 찾지 못한(지운) 것은 뺀다. 화면의 `.task` 에서만 부른다.
private func orderedByIDs<T>(_ ids: [UUID], _ items: [T], id: (T) -> UUID) -> [T] {
    var byID: [UUID: T] = [:]
    for item in items where byID[id(item)] == nil { byID[id(item)] = item }
    return ids.compactMap { byID[$0] }
}

/// `EvidenceRoute` 의 목적지 — 근거가 된 기록들, 받은 차례(최근 것부터).
struct EvidenceRouteView: View {
    let route: EvidenceRoute
    @Query private var records: [Record]
    @Query private var viewers: [Person]
    /// 받은 차례대로 맞춘 기록 — 본문에서 만들지 않는다 (이슈 18).
    @State private var ordered: [Record] = []

    init(route: EvidenceRoute) {
        self.route = route
        let ids = route.recordIDs
        let viewerID = route.viewerID
        _records = Query(filter: #Predicate<Record> { ids.contains($0.uuid) })
        _viewers = Query(filter: #Predicate<Person> { $0.uuid == viewerID })
    }

    var body: some View {
        List {
            Section {
                if let viewer = viewers.first {
                    ForEach(ordered) { record in
                        if !record.isGone {
                            NavigationLink(value: record) {
                                TimelineRow(record: record, viewer: viewer)
                            }
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
        .task(id: records.count) {
            ordered = orderedByIDs(route.recordIDs, records, id: { $0.uuid })
        }
    }
}

/// `RecordFillRoute` 의 목적지 — 누르면 바로 기록 수정. 함께한 사람을 더하면 그 줄에 `채웠습니다`.
struct RecordFillRouteView: View {
    let route: RecordFillRoute
    @Query private var records: [Record]
    @State private var editing: Record?
    /// 받은 차례대로 맞춘 기록 — 수만 건일 수 있어 본문에서 만들지 않는다 (이슈 18).
    @State private var ordered: [Record] = []

    init(route: RecordFillRoute) {
        self.route = route
        let ids = route.recordIDs
        _records = Query(filter: #Predicate<Record> { ids.contains($0.uuid) })
    }

    var body: some View {
        List {
            Section {
                ForEach(ordered) { record in
                    if !record.isGone {
                        Button {
                            editing = record
                        } label: {
                            row(record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("\(ordered.count)건")
            } footer: {
                Text("누르면 기록 수정이 바로 열립니다. 그 자리에 함께한 사람이 더 있었다면 더하세요 — 함께한 사람끼리 관계도에 선이 생깁니다. 둘만 만난 기록이면 그대로 두어도 됩니다.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: records.count) {
            ordered = orderedByIDs(route.recordIDs, records, id: { $0.uuid })
        }
        .sheet(item: $editing) { record in
            RecordEditView(mode: .edit(record)) { _ in }
        }
    }

    private func row(_ record: Record) -> some View {
        let others = (record.participants ?? []).filter { !$0.isMe }
        let names = others.prefix(3).map(\.name)
        let done = others.count >= 2
        return AdaptiveStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayTitle).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink).readableLineLimit(1)
                Text(([record.occurredAt.formatted(date: .abbreviated, time: .omitted)] + names).joined(separator: " · "))
                    .font(.scaled(13)).foregroundStyle(Color.muted).readableLineLimit(1)
            }
            Spacer(minLength: 8)
            Label {
                Text(done ? "채웠습니다" : "함께한 사람 더하기")
            } icon: {
                if done { Image(systemName: "checkmark.circle.fill") }
            }
            .font(.scaled(12, weight: done ? .semibold : .regular))
            .foregroundStyle(done ? Color.accent : Color.muted)
            .readableLineLimit(1)
        }
        .contentShape(Rectangle())
        // 구분선은 줄 왼쪽 끝부터 (이슈 28) — 위 사람 줄과 같은 까닭.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
