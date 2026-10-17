import Core
import SwiftData
import SwiftUI

/// 홈 — 사람 목록 (요구사항 4.2.1). 검색은 같은 화면의 검색 모드다 (4.2.6).
struct PeopleListView: View {
    let arguments: LaunchArguments
    let isSampleData: Bool

    @Environment(\.modelContext) private var context
    /// 정렬은 저장소가 아니라 `Core.NameSort` 가 한다 — 정답표와 같은 규칙, 같은 답.
    @Query private var fetched: [Person]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var pendingDelete: Person?
    @State private var errorMessage: String?
    @State private var appliedArguments = false

    private var store: PersonStore { PersonStore(context: context) }

    private var people: [Person] {
        fetched.sorted {
            NameSort.areInIncreasingOrder((name: $0.name, createdAt: $0.createdAt),
                                          (name: $1.name, createdAt: $1.createdAt))
        }
    }

    private var query: SearchQuery { SearchQuery(parsing: searchText) }

    private var hits: [(person: Person, hit: SearchHit)] {
        guard !query.isEmpty else { return [] }
        var byID: [UUID: Person] = [:]
        for person in fetched { byID[person.uuid] = person }
        let searchable = fetched.map { SearchablePerson(person: $0) }
        return SearchMatcher.hits(query, in: searchable).compactMap { hit in
            byID[hit.personID].map { (person: $0, hit: hit) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if fetched.isEmpty && searchText.isEmpty {
                    EmptyPeopleView { showingAdd = true }
                } else if !query.isEmpty && hits.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    list
                }
            }
            .background(Color.ground)
            .navigationTitle("느린 인연")
            .searchable(text: $searchText, prompt: "이름, 소속, 메모, 태그")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("사람 추가", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .navigationDestination(for: Record.self) { record in
                RecordDetailView(record: record)
            }
            .sheet(isPresented: $showingAdd) {
                PersonEditView(mode: .create) { person in
                    path.append(person)
                }
            }
            .confirmationDialog(
                "삭제",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .hidden,
                presenting: pendingDelete
            ) { person in
                Button("삭제", role: .destructive) { delete(person) }
                Button("취소", role: .cancel) { pendingDelete = nil }
            } message: { person in
                Text(store.deletionMessage(for: person))
            }
            .alert("삭제하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { await applyArgumentsOnce() }
    }

    private var list: some View {
        List {
            if isSampleData {
                Section {
                    Label("견본 자료입니다. 실제 인연이 아닙니다.", systemImage: "info.circle")
                        .font(.scaled(13))
                        .foregroundStyle(Color.muted)
                }
            }
            if query.isEmpty {
                Section {
                    ForEach(people) { person in
                        NavigationLink(value: person) {
                            PersonRow(person: person, evidence: nil)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // 역할 없는 단추 — `role: .destructive` 는 확인 전에 줄을 먼저 접는다 (느린 부자 178~182).
                            Button {
                                pendingDelete = person
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            .tint(Color.danger)
                        }
                    }
                } header: {
                    Text("\(people.count)명")
                }
            } else {
                Section {
                    ForEach(hits, id: \.person.uuid) { item in
                        NavigationLink(value: item.person) {
                            PersonRow(person: item.person, evidence: item.hit.evidence)
                        }
                    }
                } header: {
                    Text("\(hits.count)명")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func delete(_ person: Person) {
        do {
            try store.delete(person)
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
        pendingDelete = nil
    }

    /// CI 스크린샷용 실행 인자를 **한 번만** 적용한다. `@Query` 가 첫 결과를 내놓을 시간을 조금 준다.
    private func applyArgumentsOnce() async {
        guard !appliedArguments else { return }
        appliedArguments = true
        try? await Task.sleep(for: .milliseconds(300))
        if let search = arguments.search { searchText = search }
        if arguments.addPerson { showingAdd = true }
        var opened: Person?
        if let name = arguments.openPerson {
            opened = people.first { NameSort.key($0.name) == NameSort.key(name) }
        } else if arguments.openFirstPerson {
            opened = people.first
        }
        if let opened {
            path.append(opened)
            if arguments.openRecord, let latest = RecordStore.timeline(of: opened).first {
                path.append(latest)
            }
        }
    }
}

struct PersonRow: View {
    let person: Person
    let evidence: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(person.name)
                .font(.scaled(17, weight: .semibold))
                .foregroundStyle(Color.ink)
            if let subtitle = person.subtitle {
                Text(subtitle)
                    .font(.scaled(14))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
            }
            if let evidence {
                Text(evidence)
                    .font(.scaled(13))
                    .foregroundStyle(Color.accent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
