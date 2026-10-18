import Combine
import Core
import SwiftData
import SwiftUI

/// 홈 — 사람 목록 (요구사항 4.2.1). 검색은 같은 화면의 검색 모드다 (4.2.6).
///
/// **속도 (이슈 6).** 5,000명 · 50,000건에서 정렬 · 검색을 본문이 그려질 때마다 다시 셈하니 목록 정렬이
/// 0.6~1초씩 되풀이되고 검색이 1.4~2.3초(첫 번 18초) 걸렸다. 그래서
/// - 정렬 결과와 검색 색인을 **상태에 담아** 자료가 바뀔 때만 다시 만든다 (`ModelContext.didSave` 로 자료 판을 센다)
/// - 정렬은 이름 열쇠를 항목마다 한 번만 만든다 (`Core.NameSort.sorted`)
/// - 검색 색인은 칸을 미리 접어 두고(`Core.SearchIndex`), 찾기는 주 스레드 밖에서 한다
struct PeopleListView: View {
    let arguments: LaunchArguments
    let isSampleData: Bool

    @Environment(\.modelContext) private var context
    @Query private var fetched: [Person]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    /// 목록 정렬 (FR-027). 기기 편의라 UserDefaults.
    @AppStorage("people.sort") private var sortOption: PeopleSortOption = .name
    @State private var showingAdd = false
    @State private var pendingDelete: Person?
    @State private var errorMessage: String?
    @State private var appliedArguments = false

    /// 저장할 때마다 하나씩 오른다. 정렬 · 색인을 다시 만들 때를 이것으로 안다.
    @State private var dataVersion = 0
    @State private var sortedPeople: [Person] = []
    @State private var searchIndex: SearchIndex?
    @State private var indexVersion = -1
    @State private var searchRows: [SearchRow] = []
    /// `searchRows` 가 어느 검색어의 결과인가 — 아직 찾는 중인지 가르려고.
    @State private var searchedText = ""

    private var store: PersonStore { PersonStore(context: context) }

    /// 보여 줄 목록. 정렬이 끝나기 전(첫 화면 · 사람 수가 막 바뀐 때)에는 받은 차례 그대로.
    ///
    /// **여기서 사람마다 SwiftData 에 묻지 않는다 (이슈 10).** 빌드 4 에서 주 스레드가 이 자리(`filter { !$0.isGone }`)를
    /// 10초 넘게 돌다 시스템에 꺼졌다 — 본문이 그려질 때마다 전원의 삭제 여부를 두 번씩 물었다.
    /// 지운 사람은 저장과 함께 `@Query` 에서 빠지고 사람 수가 달라져 정렬 결과 대신 받은 차례를 쓴다.
    /// 그 틈의 지운 객체는 **화면에 그려지는 줄에서만** 거른다 (`ForEach` 안).
    private var displayedPeople: [Person] {
        sortedPeople.count == fetched.count ? sortedPeople : fetched
    }

    private var isQuerying: Bool { !SearchQuery(parsing: searchText).isEmpty }

    private struct ListKey: Hashable {
        let version: Int
        let sort: PeopleSortOption
        let count: Int
    }

    private struct SearchKey: Hashable {
        let text: String
        let version: Int
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if fetched.isEmpty && searchText.isEmpty {
                    EmptyPeopleView { showingAdd = true }
                } else if isQuerying && searchRows.isEmpty && searchedText == searchText {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    list
                }
            }
            .background(Color.ground)
            .navigationTitle("느린 인연")
            .searchable(text: $searchText, prompt: "이름, 소속, 메모, 태그")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("정렬", selection: $sortOption) {
                            ForEach(PeopleSortOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Label("정렬", systemImage: "arrow.up.arrow.down")
                    }
                }
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
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            dataVersion += 1
        }
        .task(id: ListKey(version: dataVersion, sort: sortOption, count: fetched.count)) {
            sortedPeople = LaunchTiming.measure("목록 정렬 (\(fetched.count)명)") {
                PersonStore.sorted(fetched, by: sortOption)
            }
        }
        .task(id: SearchKey(text: searchText, version: dataVersion)) {
            await runSearch()
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
            if !isQuerying {
                Section {
                    ForEach(displayedPeople) { person in
                        if !person.isGone {
                            NavigationLink(value: person) {
                                PersonRow(person: person, evidence: nil, showsLastRecord: true)
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
                    }
                } header: {
                    Text("\(displayedPeople.count)명 · \(sortOption.label)")
                }
            } else {
                Section {
                    ForEach(searchRows) { row in
                        if !row.person.isGone {
                            // 기록에서 일치했으면 그 기록 상세까지 바로 연다 (FR-034). 그래서 NavigationLink 가 아니라 Button 이다.
                            Button {
                                open(row.person, recordID: row.hit.recordID)
                            } label: {
                                HStack {
                                    PersonRow(person: row.person, evidence: row.hit.evidence)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.scaled(13, weight: .semibold))
                                        .foregroundStyle(Color.faint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(searchedText == searchText ? "\(searchRows.count)명" : "찾는 중…")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    /// 검색어가 멈춘 뒤 300ms 에 한 번만 센다 (요구사항 5.3). 색인은 자료가 바뀐 뒤 처음 찾을 때만 다시 만든다.
    private func runSearch() async {
        let text = searchText
        let query = SearchQuery(parsing: text)
        guard !query.isEmpty else {
            searchRows = []
            searchedText = text
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        if searchIndex == nil || indexVersion != dataVersion {
            searchIndex = LaunchTiming.measure("검색 색인 만들기 (\(fetched.count)명)") {
                SearchIndex(fetched.filter { !$0.isGone }.map { SearchablePerson(person: $0) })
            }
            indexVersion = dataVersion
        }
        guard let index = searchIndex else { return }
        let started = Date()
        let hits = await Task.detached(priority: .userInitiated) { SearchMatcher.hits(query, in: index) }.value
        LaunchTiming.log("검색 '\(text)' (\(index.count)명)", since: started)
        guard !Task.isCancelled else { return }

        var byID: [UUID: Person] = [:]
        for person in fetched { byID[person.uuid] = person }
        searchRows = hits.compactMap { hit in byID[hit.personID].map { SearchRow(person: $0, hit: hit) } }
        searchedText = text
    }

    /// 사람 상세를 열고, 기록이 지정됐으면 그 기록 상세까지 연다.
    private func open(_ person: Person, recordID: UUID?) {
        path.append(person)
        if let recordID, let record = (person.records ?? []).first(where: { $0.uuid == recordID }) {
            path.append(record)
        }
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
        LaunchTiming.mark("목록 첫 표시 (\(fetched.count)명)")
        if let search = arguments.search { searchText = search }
        if arguments.addPerson { showingAdd = true }
        var opened: Person?
        if let name = arguments.openPerson {
            opened = fetched.first { NameSort.key($0.name) == NameSort.key(name) }
        } else if arguments.openFirstPerson {
            opened = PersonStore.sorted(fetched, by: .name).first
        }
        if let opened {
            path.append(opened)
            if arguments.openRecord, let latest = RecordStore.timeline(of: opened).first {
                path.append(latest)
            }
        }
    }
}

/// 검색 결과 한 줄.
struct SearchRow: Identifiable {
    let person: Person
    let hit: SearchHit
    var id: UUID { hit.personID }
}

struct PersonRow: View {
    let person: Person
    let evidence: String?
    /// 목록에서만 마지막 기록일을 날 수로 (FR-040 · 이슈 7). 선택기 · 검색 결과에서는 끈다.
    var showsLastRecord = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(person.name)
                    .font(.scaled(17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                if showsLastRecord {
                    Spacer(minLength: 8)
                    Text(lastRecordText)
                        .font(.scaled(12))
                        .foregroundStyle(Color.faint)
                        .lineLimit(1)
                }
            }
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

    /// 기록 날짜는 그날 정오로 저장하므로 **날 수**로 센다 — 시각으로 세면 오전에 오늘 기록이 `3시간 후` 가 된다 (이슈 7).
    private var lastRecordText: String {
        guard let last = person.lastRecordAt else { return "기록 없음" }
        return "마지막 기록 " + RelativeDay.phrase(from: last, to: Date(), calendar: .current)
    }
}
