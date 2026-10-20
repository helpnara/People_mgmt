import CoreData
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
    /// 나를 뺀 사람들. 나는 맨 위 칸에 따로 서고 사람 수 · 검색 · 정렬에 들지 않는다 (이슈 12).
    @Query(filter: #Predicate<Person> { $0.isMe == false }) private var fetched: [Person]
    @Query(filter: #Predicate<Person> { $0.isMe == true }) private var meList: [Person]

    @State private var path = NavigationPath()

    // 아이패드 (이슈 32) — 왼쪽 바 · 사람 목록 · 상세를 나란히. 아이폰(좁은 폭)은 위의 스택 하나 그대로.
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
    @State private var section: AppSection? = .people
    @State private var selectedPersonID: UUID?
    @State private var detailPath = NavigationPath()
    @State private var networkPath = NavigationPath()
    @State private var graphPersonID: UUID?
    @State private var searchText = ""
    /// 목록 정렬 (FR-027). 기기 편의라 UserDefaults.
    @AppStorage("people.sort") private var sortOption: PeopleSortOption = .name
    @State private var showingAdd = false
    @State private var addingMe = false
    @State private var pendingDelete: Person?
    @State private var errorMessage: String?
    @State private var appliedArguments = false

    /// 저장할 때마다 하나씩 오른다. 정렬 · 색인을 다시 만들 때를 이것으로 안다.
    @State private var dataVersion = 0
    /// 앱이 뒤에 있거나 잠긴 동안 들어온 변경 — 앞으로 나올 때 한 번에 센다 (이슈 31).
    @State private var pendingChange = false
    @State private var pendingRemoteChange = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var sortedPeople: [Person] = []
    @State private var searchIndex: SearchIndex?
    @State private var indexVersion = -1
    @State private var searchRows: [SearchRow] = []
    /// `searchRows` 가 어느 검색어의 결과인가 — 아직 찾는 중인지 가르려고.
    @State private var searchedText = ""
    /// 입력 상태 한 줄 (D-31). 따로 연 문맥에서 자료가 바뀔 때만 센다 — 본문에서 세지 않는다.
    @State private var readinessLine: String?

    // 단축어 (빌드 16) — 사람 추가 · 기록 추가 · 명함 찍기.
    @ObservedObject private var shortcuts = ShortcutRequests.shared
    /// 사람 추가를 열자마자 명함 촬영을 띄운다.
    @State private var scanOnAdd = false
    @State private var pickingRecordPerson = false
    /// 고를 사람 — 고르기 창을 열 때 한 번 정렬한다 (본문에서 정렬하지 않는다).
    @State private var recordCandidates: [Person] = []
    @State private var recordPick: Person?
    @State private var recordAnchor: Person?
    /// 나에서 보통 사람으로 바꾼 이름 (iCloud 동기화 · D-43) — 한 번 알린다.
    @State private var demotedMe: [String] = UserDefaults.standard.stringArray(forKey: PersonStore.demotedMeKey) ?? []

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
        Group {
            if isWide {
                wideLayout
            } else {
                NavigationStack(path: $path) {
                    home
                        .appDestinations()
                }
            }
        }
        .sheet(isPresented: $showingAdd, onDismiss: { scanOnAdd = false }) {
            PersonEditView(mode: .create, startsScan: scanOnAdd) { person in
                show(person)
            }
        }
        // 단축어 기록 추가 — 누구와의 기록인지 고르고, 고르기 창이 닫힌 뒤 기록 쓰기를 띄운다.
        .sheet(isPresented: $pickingRecordPerson, onDismiss: {
            if let person = recordPick {
                recordPick = nil
                recordAnchor = person
            }
        }) {
            NavigationStack {
                PersonPickerView(people: recordCandidates, selection: $recordPick, title: "누구와의 기록인가요")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("취소") { pickingRecordPerson = false }
                        }
                    }
            }
        }
        .sheet(item: $recordAnchor) { person in
            RecordEditView(mode: .create(anchor: person)) { _ in
                show(person)
            }
        }
        .sheet(isPresented: $addingMe) {
            PersonEditView(mode: .createMe) { _ in }
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
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            noteChange()
        }
        // 다른 기기에서 바뀐 자료가 iCloud 로 들어왔을 때 (D-42) — 정렬 · 색인 · 요약을 다시 세고, 나가 둘이면 정리한다.
        // 앱이 뒤에 있거나 잠긴 동안(조용한 푸시로 깨어남)에는 표시만 하고, 앞으로 나올 때 센다 (이슈 31).
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            guard CloudSync.isActive else { return }
            guard StoreAccess.isReadable(scenePhase) else {
                pendingChange = true
                pendingRemoteChange = true
                return
            }
            applyRemoteChange()
        }
        .onChange(of: scenePhase) { _, _ in
            guard StoreAccess.isReadable(scenePhase) else { return }
            if pendingRemoteChange { applyRemoteChange() }
            if pendingChange {
                pendingChange = false
                dataVersion += 1
            }
        }
        .alert("나는 한 사람만 둡니다", isPresented: Binding(get: { !demotedMe.isEmpty }, set: { if !$0 { demotedMe = [] } })) {
            Button("확인", role: .cancel) {
                UserDefaults.standard.removeObject(forKey: PersonStore.demotedMeKey)
            }
        } message: {
            Text("다른 기기에서도 나를 적어 두어 나가 둘이 되었습니다. 먼저 만든 나를 남기고 나머지는 보통 사람으로 바꿨습니다 — \(demotedMe.joined(separator: ", ")). 지우지는 않았습니다.")
        }
        .task(id: ListKey(version: dataVersion, sort: sortOption, count: fetched.count)) {
            sortedPeople = LaunchTiming.measure("목록 정렬 (\(fetched.count)명)") {
                PersonStore.sorted(fetched, by: sortOption)
            }
        }
        .task(id: SearchKey(text: searchText, version: dataVersion)) {
            await runSearch()
        }
        .task(id: dataVersion) {
            // 저장이 이어지면(하루 10명 입력) 마지막 저장 뒤 한 번만 센다.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            // 그 1초 사이에 뒤로 가거나 잠겼으면 앞으로 나올 때 다시 (이슈 31).
            guard StoreAccess.isReadable(scenePhase) else {
                pendingChange = true
                return
            }
            let input = await NetworkSnapshotBuilder.readiness(container: context.container)
            guard !Task.isCancelled else { return }
            readinessLine = input.people > 0 ? InputReadiness.summary(InputReadiness.evaluate(input)) : nil
            // 알림도 다시 건다 (D-40) — 생일 · 처음 만난 날 · 기록이 바뀌었을 수 있다. 켠 알림이 없으면 바로 끝난다.
            await ReminderScheduler.refresh(container: context.container)
            // 검색 색인도 미리 만들어 둔다 (이슈 8) — 첫 검색이 기다리지 않게.
            if !fetched.isEmpty, indexVersion != dataVersion {
                await rebuildIndex()
            }
        }
        .task { await applyArgumentsOnce() }
        .onChange(of: shortcuts.pending) { _, _ in handleShortcut() }
        .onAppear(perform: handleShortcut)
    }

    /// 목록 화면 — 아이폰은 이것이 뿌리, 아이패드는 사람 칸의 왼쪽 목록이다.
    private var home: some View {
        Group {
            if fetched.isEmpty && meList.isEmpty && searchText.isEmpty {
                EmptyPeopleView { showingAdd = true }
            } else if isQuerying && searchRows.isEmpty && searchedText == searchText {
                // 요구사항 문구 그대로 — 시스템 기본 문구 대신 (전수조사 이슈 22). 조사는 `Core.Josa` 로.
                let shown = TextNormalization.normalized(searchText)
                ContentUnavailableView {
                    Label("'\(shown)'\(Josa.gwaWa(shown)) 일치하는 사람이 없습니다", systemImage: "magnifyingglass")
                } description: {
                    Text("이름 · 소속 · 메모 · 태그로 찾습니다. 태그만 찾으려면 #을 붙이세요.")
                }
            } else {
                list
            }
        }
        .background(Color.ground)
        .navigationTitle(isWide ? "사람" : "느린 인연")
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
            // 아이패드는 왼쪽 바에 내 인맥 · 설정이 있다 (이슈 32) — 위 단추는 아이폰에만.
            if !isWide {
                ToolbarItem(placement: .topBarLeading) {
                    // 내 인맥 (6번째 묶음) — 목록 위 단추 (2026-10-18 사용자 결정).
                    NavigationLink(value: NetworkRoute(tab: .graph)) {
                        Label("내 인맥", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 설정 (FR-030 · D-34) — 백업 · 복원 · 개인정보 안내. 값으로 연다 (이슈 16).
                    NavigationLink(value: SettingsRoute()) {
                        Label("설정", systemImage: "gearshape")
                    }
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
    }

    /// 저장 뒤 — 앞에 있으면 바로 다시 세고, 뒤에 있거나 잠겼으면 표시만 (이슈 31).
    private func noteChange() {
        if StoreAccess.isReadable(scenePhase) {
            dataVersion += 1
        } else {
            pendingChange = true
        }
    }

    /// 다른 기기의 변경을 반영한다 — 다시 세고, 나가 둘이면 정리한다 (D-43).
    private func applyRemoteChange() {
        pendingRemoteChange = false
        dataVersion += 1
        if let names = try? store.resolveDuplicateMe(), !names.isEmpty { demotedMe = names }
    }

    /// 단축어가 남긴 요청을 한 번 처리한다 (빌드 16). 앱이 꺼져 있었으면 목록이 뜬 뒤에, 켜져 있었으면 바로.
    private func handleShortcut() {
        guard let request = shortcuts.pending else { return }
        shortcuts.pending = nil
        switch request {
        case .addPerson:
            scanOnAdd = false
            showingAdd = true
        case .scanCard:
            scanOnAdd = true
            showingAdd = true
        case .addRecord:
            // 사람이 없으면 기록을 붙일 곳이 없다 — 사람 추가부터.
            guard !fetched.isEmpty else {
                showingAdd = true
                return
            }
            recordCandidates = PersonStore.sorted(fetched.filter { !$0.isGone }, by: .name)
            recordPick = nil
            pickingRecordPerson = true
        }
    }

    private var list: some View {
        List {
            if isSampleData && !arguments.storeShots {
                Section {
                    Label("견본 자료입니다. 실제 인연이 아닙니다.", systemImage: "info.circle")
                        .font(.scaled(13))
                        .foregroundStyle(Color.muted)
                }
            }
            if !isQuerying {
                meSection
                if let readinessLine, !fetched.isEmpty {
                    Section {
                        // 입력 상태 (D-31) — 무엇을 더 적으면 무엇이 보이는지. 내 인맥의 입력 상태 칸으로 간다.
                        let label = Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("입력 상태").font(.scaled(15, weight: .semibold)).foregroundStyle(Color.ink)
                                Text(readinessLine).font(.scaled(13)).foregroundStyle(Color.muted)
                            }
                        } icon: {
                            Image(systemName: "checklist").foregroundStyle(Color.accent)
                        }
                        if isWide {
                            // 아이패드는 왼쪽 바의 입력 상태 칸으로 (이슈 32).
                            Button { openSection(.network(.readiness)) } label: { label }
                                .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: NetworkRoute(tab: .readiness)) { label }
                        }
                    }
                }
                Section {
                    ForEach(displayedPeople) { person in
                        if !person.isGone {
                            personLink(person) {
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

    /// **나** (이슈 12). 인맥은 나를 기준으로 그린다 — 목록 맨 위에 늘 있다.
    @ViewBuilder
    private var meSection: some View {
        Section {
            if let me = meList.first, !me.isGone {
                personLink(me) {
                    HStack(spacing: 12) {
                        // 그림은 xxxLarge 에서 멈춘다 — 가장 큰 글씨에서 이름보다 커지지 않게 (빌드 18).
                        Image(systemName: "person.crop.circle.fill")
                            .font(.scaledCapped(30))
                            .foregroundStyle(Color.accent)
                        PersonRow(person: me, evidence: nil)
                    }
                }
            } else {
                Button {
                    addingMe = true
                } label: {
                    Label("내 정보를 적어 보세요", systemImage: "person.crop.circle.badge.plus")
                        .font(.scaled(16, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
            }
        } header: {
            Text("나")
        } footer: {
            if meList.isEmpty {
                Text("인맥은 나를 기준으로 그립니다. 내 이름 · 소속 · 연락 수단 · 명함을 적어 두세요.")
            }
        }
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
            await rebuildIndex()
            guard !Task.isCancelled else { return }
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

    /// 색인을 따로 연 문맥에서 만든다 (이슈 8) — 주 스레드는 기다리기만 한다.
    private func rebuildIndex() async {
        let version = dataVersion
        let index = await SearchIndexBuilder.build(container: context.container)
        // 만드는 사이 저장이 또 있었으면 이 색인은 옛것이다 — 다음 검색 · 다음 미리 만들기가 다시 만든다.
        guard version == dataVersion else { return }
        searchIndex = index
        indexVersion = version
    }

    /// 사람 상세를 열고, 기록이 지정됐으면 그 기록 상세까지 연다.
    private func open(_ person: Person, recordID: UUID?) {
        show(person)
        if let recordID, let record = (person.records ?? []).first(where: { $0.uuid == recordID }) {
            if isWide { detailPath.append(record) } else { path.append(record) }
        }
    }

    /// 사람을 연다 — 아이폰은 스택에 쌓고, 아이패드는 사람 칸의 오른쪽에 (이슈 32).
    private func show(_ person: Person) {
        if isWide {
            section = .people
            selectedPersonID = person.uuid
            detailPath = NavigationPath()
        } else {
            path.append(person)
        }
    }

    /// 아이패드 왼쪽 바의 칸을 연다 — 그 칸에서 쌓아 둔 화면 · 고른 점은 비운다.
    private func openSection(_ next: AppSection) {
        section = next
        networkPath = NavigationPath()
        graphPersonID = nil
    }

    /// 목록의 사람 한 줄 — 아이폰은 상세로 넘어가고, 아이패드는 오른쪽에 연다(고른 줄은 옅게 칠한다).
    @ViewBuilder
    private func personLink<Content: View>(_ person: Person, @ViewBuilder content: () -> Content) -> some View {
        if isWide {
            Button {
                show(person)
            } label: {
                HStack {
                    content()
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedPersonID == person.uuid ? Color.accent.opacity(0.15) : nil)
            .accessibilityAddTraits(selectedPersonID == person.uuid ? .isSelected : [])
        } else {
            NavigationLink(value: person) { content() }
        }
    }

    // MARK: - 아이패드 (이슈 32)

    /// 왼쪽 바 · 오른쪽 칸. 세로로 돌리면 왼쪽 바는 숨김 단추로 접힌다(시스템 기본).
    private var wideLayout: some View {
        NavigationSplitView {
            List(selection: Binding(get: { section }, set: { if let next = $0 { openSection(next) } })) {
                Section {
                    Label("사람", systemImage: "person.2").tag(AppSection.people)
                }
                Section("내 인맥") {
                    ForEach(NetworkView.Tab.allCases) { tab in
                        Label(tab.label, systemImage: tab.symbol).tag(AppSection.network(tab))
                    }
                }
                Section {
                    Label("설정", systemImage: "gearshape").tag(AppSection.settings)
                }
            }
            .navigationTitle("느린 인연")
        } detail: {
            switch section ?? .people {
            case .people:
                peoplePane
            case .network(let tab):
                networkPane(tab)
            case .settings:
                NavigationStack {
                    SettingsView()
                        .appDestinations()
                }
            }
        }
    }

    /// 사람 칸 — 왼쪽에 목록, 오른쪽에 고른 사람. 오른쪽 안에서 기록 · 소개한 사람으로 더 들어간다.
    private var peoplePane: some View {
        HStack(spacing: 0) {
            NavigationStack {
                home
            }
            .frame(width: Self.listWidth)
            Divider()
            NavigationStack(path: $detailPath) {
                Group {
                    if let id = selectedPersonID {
                        PersonByIDView(id: id)
                            .id(id)
                    } else {
                        ContentUnavailableView("사람을 고르세요", systemImage: "person.crop.rectangle",
                                               description: Text("왼쪽 목록에서 사람을 누르면 여기에 그 사람과의 인연이 보입니다."))
                    }
                }
                .appDestinations()
            }
        }
    }

    /// 내 인맥 칸. 관계도는 **위 4분의 3**, 누른 사람은 **아래 4분의 1** (이슈 32 · 2026-10-20 사용자 — 왼쪽 바는 그대로 두고,
    /// 가로로 셋으로 나누면 관계도가 작다. 빌드 25 의 3분의 2 도 가로 화면에서 작아 다른 칸을 줄여서라도 관계도를 크게). 아래 칸은 늘 두어 사람을 누를 때 관계도 크기가 바뀌지 않게 (이슈 29 와 같은 까닭).
    /// 다른 칸(특성 · 돌아보기 · 입력 상태)은 칸 전체를 쓴다.
    @ViewBuilder
    private func networkPane(_ tab: NetworkView.Tab) -> some View {
        if tab == .graph {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    NavigationStack(path: $networkPath) {
                        NetworkView(initialTab: .graph, showsTabs: false, onSelectPerson: { graphPersonID = $0 })
                            .appDestinations()
                    }
                    .frame(height: proxy.size.height * 3 / 4)
                    Divider()
                    NavigationStack {
                        Group {
                            if let id = graphPersonID {
                                PersonByIDView(id: id)
                                    .id(id)
                            } else {
                                ContentUnavailableView("점을 누르세요", systemImage: "hand.tap",
                                                       description: Text("관계도에서 사람을 누르면 여기에 그 사람과의 인연이 보입니다. 두 손가락으로 키우고 옮기고, 두 번 누르면 처음 크기로."))
                            }
                        }
                        .appDestinations()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        } else {
            NavigationStack(path: $networkPath) {
                NetworkView(initialTab: tab, showsTabs: false)
                    .appDestinations()
            }
            .id(tab)
        }
    }

    /// 목록 칸 너비 — 글자 크기를 따르되 너무 좁거나 넓지 않게.
    private static var listWidth: CGFloat { min(max(Font.scaledLength(340), 320), 460) }

    private func delete(_ person: Person) {
        if selectedPersonID == person.uuid { selectedPersonID = nil }
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
        if arguments.openSettings {
            if isWide { openSection(.settings) } else { path.append(SettingsRoute()) }
            return
        }
        if arguments.openFillFirstMet {
            let snapshot = await NetworkSnapshotBuilder.build(container: context.container)
            let route = PeopleListRoute(title: "처음 만난 날이 빈 사람", ids: snapshot.gaps.noFirstMet, fill: .firstMet)
            if isWide {
                openSection(.network(.readiness))
                networkPath.append(route)
            } else {
                path.append(route)
            }
            return
        }
        if arguments.openSuggestions {
            let snapshot = await NetworkSnapshotBuilder.build(container: context.container)
            let route = AcquaintanceSuggestionRoute(items: snapshot.suggestions)
            if isWide {
                openSection(.network(.readiness))
                networkPath.append(route)
            } else {
                path.append(route)
            }
            return
        }
        if let name = arguments.openNetwork {
            let tab = NetworkView.Tab(rawValue: name) ?? .graph
            if isWide { openSection(.network(tab)) } else { path.append(NetworkRoute(tab: tab)) }
            return
        }
        if arguments.addPerson { showingAdd = true }
        var opened: Person?
        if arguments.openMe {
            opened = meList.first
        } else if let name = arguments.openPerson {
            opened = fetched.first { NameSort.key($0.name) == NameSort.key(name) }
        } else if arguments.openFirstPerson {
            opened = PersonStore.sorted(fetched, by: .name).first
        }
        if let opened {
            show(opened)
            if arguments.openRecord, let latest = RecordStore.timeline(of: opened).first {
                if isWide { detailPath.append(latest) } else { path.append(latest) }
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
            // 큰 글씨에서는 마지막 기록일을 이름 아래로 (D-33).
            AdaptiveStack {
                Text(person.name)
                    .font(.scaled(17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                if showsLastRecord {
                    Spacer(minLength: 8)
                    Text(lastRecordText)
                        .font(.scaled(12))
                        .foregroundStyle(Color.muted)
                        .readableLineLimit(1)
                }
            }
            if let subtitle = person.subtitle {
                Text(subtitle)
                    .font(.scaled(14))
                    .foregroundStyle(Color.muted)
                    .readableLineLimit(1)
            }
            if let evidence {
                Text(evidence)
                    .font(.scaled(13))
                    .foregroundStyle(Color.accent)
                    .readableLineLimit(1)
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
