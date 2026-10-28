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
    /// 견본 둘러보기 중 (D-55) — 견본 안내 줄 대신 뿌리의 띠가 말한다.
    var isDemo = false

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
    /// 최근 기록 3건 (FR-028) — 오늘까지의 기록 가운데 날짜가 늦은 것부터. 자료가 바뀔 때만 읽는다.
    @State private var recentRecords: [Record] = []
    /// 목록 거르기 (FR-013) — 관계 유형 · 태그. 둘 다 고르면 둘 다 맞는 사람. 기기 편의라 저장하지 않는다.
    @State private var filterType: String?
    @State private var filterTag: String?
    /// 고를 수 있는 것 · 거른 결과 — 자료 · 정렬 · 거르기가 바뀔 때만 센다 (본문에서 전원을 훑지 않는다).
    @State private var typeChoices: [String] = []
    @State private var tagChoices: [String] = []
    @State private var filteredPeople: [Person] = []

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
        if isFiltering { return filteredPeople }
        return sortedPeople.count == fetched.count ? sortedPeople : fetched
    }

    private var isFiltering: Bool { filterType != nil || filterTag != nil }

    /// 머리말 · 풀기 줄에 쓰는 지금 거른 것.
    private var filterSummary: String {
        [filterType, filterTag.map { "#" + $0 }].compactMap { $0 }.joined(separator: " · ")
    }

    private var isQuerying: Bool { !SearchQuery(parsing: searchText).isEmpty }

    private struct ListKey: Hashable {
        let version: Int
        let sort: PeopleSortOption
        let count: Int
        let type: String?
        let tag: String?
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
        .task(id: ListKey(version: dataVersion, sort: sortOption, count: fetched.count, type: filterType, tag: filterTag)) {
            sortedPeople = LaunchTiming.measure("목록 정렬 (\(fetched.count)명)") {
                PersonStore.sorted(fetched, by: sortOption)
            }
            if !sortedPeople.isEmpty { LaunchTiming.once("목록 정렬 끝 (\(sortedPeople.count)명)") }
            refreshFilter()
            LaunchTiming.measure("최근 기록 3건 읽기") { loadRecentRecords() }
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
            LaunchTiming.once("입력 상태 세기 시작 (자료 판 \(dataVersion))")
            let input = await NetworkSnapshotBuilder.readiness(container: context.container, version: dataVersion)
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
        .onAppear { LaunchTiming.once("목록 화면 나타남 (사람 \(fetched.count)명 읽힘)") }
        .onChange(of: shortcuts.pending) { _, _ in handleShortcut() }
        .onAppear(perform: handleShortcut)
    }

    /// 목록 화면 — 아이폰은 이것이 뿌리, 아이패드는 사람 칸의 왼쪽 목록이다.
    private var home: some View {
        Group {
            if fetched.isEmpty && meList.isEmpty && searchText.isEmpty {
                EmptyPeopleView(onAdd: { showingAdd = true }, onDemo: { DemoMode.shared.start() })
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
                // 정렬 · 거르기 (FR-027 · FR-013) — 위 줄 단추를 늘리지 않게 차림표 하나에.
                Menu {
                    Picker("정렬", selection: $sortOption) {
                        ForEach(PeopleSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    if !typeChoices.isEmpty {
                        Picker("관계 유형", selection: $filterType) {
                            Text("관계 유형 전체").tag(String?.none)
                            ForEach(typeChoices, id: \.self) { type in
                                Text(type).tag(String?.some(type))
                            }
                        }
                    }
                    if !tagChoices.isEmpty {
                        Picker("태그", selection: $filterTag) {
                            Text("태그 전체").tag(String?.none)
                            ForEach(tagChoices, id: \.self) { tag in
                                Text("#\(tag)").tag(String?.some(tag))
                            }
                        }
                    }
                    if isFiltering {
                        Button {
                            clearFilter()
                        } label: {
                            Label("거르기 풀기", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Label("정렬 · 거르기", systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "arrow.up.arrow.down")
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
            // 견본 둘러보기 (D-55) — 목록 첫 칸. 화면 위에 띄우면 내비게이션 막대의 단추를 덮는다(빌드 33 CI 스크린샷 36).
            if isDemo {
                Section {
                    DemoBanner(demo: DemoMode.shared)
                }
            }
            if isSampleData && !isDemo && !arguments.storeShots {
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
                if !recentRecords.isEmpty {
                    recentSection
                }
                Section {
                    if isFiltering {
                        Button {
                            clearFilter()
                        } label: {
                            Label("\(filterSummary)만 보는 중 — 누르면 모두 보기", systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.scaled(14))
                                .foregroundStyle(Color.accent)
                        }
                        if displayedPeople.isEmpty {
                            Text("조건에 맞는 사람이 없습니다")
                                .font(.scaled(15))
                                .foregroundStyle(Color.muted)
                        }
                    }
                    // 줄마다 정확히 한 칸 (`LiveRow`) — 줄 안에 `if` 를 바로 두면 줄 수가 정해지지 않아 SwiftUI 가 5,000줄을
                    // 미리 다 만든다(기준 5 · 실행 80: 화면이 나타난 뒤 첫 줄까지 2.3초). 지운 사람 거르기는 그 칸 안에서.
                    ForEach(displayedPeople) { person in
                        LiveRow(isGone: person.isGone) {
                            personLink(person) {
                                PersonRow(person: person, evidence: nil, showsLastRecord: true, showsPhoto: true)
                            }
                            // 기준 5 — 사람 줄이 실제로 그려진 때 (정렬이 끝난 때보다 늦다).
                            .onAppear { LaunchTiming.once("첫 사람 줄 그려짐") }
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
                    Text(isFiltering
                         ? "\(displayedPeople.count)명 · \(sortOption.label) · \(filterSummary)"
                         : "\(displayedPeople.count)명 · \(sortOption.label)")
                }
            } else {
                Section {
                    ForEach(searchRows) { row in
                        LiveRow(isGone: row.person.isGone) {
                            // 기록에서 일치했으면 그 기록 상세까지 바로 연다 (FR-034). 그래서 NavigationLink 가 아니라 Button 이다.
                            Button {
                                open(row.person, recordID: row.hit.recordID)
                            } label: {
                                HStack {
                                    PersonRow(person: row.person, evidence: row.hit.evidence, showsPhoto: true)
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

    /// 최근 기록 (FR-028) — 누르면 그 기록으로. 아이패드는 함께한 사람의 상세를 오른쪽에 열고 그 위에 기록을 연다.
    private var recentSection: some View {
        Section {
            ForEach(recentRecords) { record in
                if !record.isGone {
                    if isWide {
                        Button {
                            if let person = Self.firstCompanion(of: record) { open(person, recordID: record.uuid) }
                        } label: {
                            HStack {
                                RecentRecordRow(record: record)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: record) {
                            RecentRecordRow(record: record)
                        }
                    }
                }
            }
        } header: {
            Text("최근 기록")
        }
    }

    /// 함께한 사람 가운데 이름 순으로 처음 — 나는 뺀다.
    private static func firstCompanion(of record: Record) -> Person? {
        let others = (record.participants ?? []).filter { !$0.isGone && !$0.isMe }
        return NameSort.sorted(others, name: \.name, createdAt: \.createdAt).first
    }

    /// 고를 수 있는 관계 유형 · 태그와 거른 결과 (FR-013). 규칙은 `Core.ListFilter` · `TagCatalog` 하나다.
    /// 고른 것이 자료에서 사라졌으면(태그 이름을 바꾸는 등) 거르기를 푼다.
    private func refreshFilter() {
        let people = fetched.filter { !$0.isGone }
        LaunchTiming.measure("거르기 고를 것 (\(people.count)명)") {
            typeChoices = ListFilter.typeChoices(people.map(\.relationshipType))
            tagChoices = TagCatalog(personTags: people.map(\.tags), recordTags: []).entries.map(\.tag)
        }
        if let type = filterType, !typeChoices.contains(where: { NameSort.key($0) == NameSort.key(type) }) { filterType = nil }
        if let tag = filterTag, !tagChoices.contains(where: { TagNormalizer.key($0) == TagNormalizer.key(tag) }) { filterTag = nil }
        guard isFiltering else {
            filteredPeople = []
            return
        }
        filteredPeople = sortedPeople.filter {
            !$0.isGone && ListFilter.matches(type: $0.relationshipType, tags: $0.tags, wantedType: filterType, wantedTag: filterTag)
        }
    }

    private func clearFilter() {
        filterType = nil
        filterTag = nil
    }

    /// 오늘까지의 기록 가운데 날짜가 늦은 셋 (같은 날이면 나중에 적은 것부터). 잠긴 동안은 읽지 않는다 (이슈 31).
    /// 앱이 막 뜰 때는 아직 앞에 나오기 전이라 여기서 걸린다 — 표시만 해 두면 앞으로 나올 때 다시 센다(빌드 27 CI 스크린샷 02).
    private func loadRecentRecords() {
        guard StoreAccess.isReadable(scenePhase) else {
            pendingChange = true
            return
        }
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        var descriptor = FetchDescriptor<Record>(
            predicate: #Predicate<Record> { $0.occurredAt < endOfToday },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        recentRecords = (try? context.fetch(descriptor)) ?? []
    }

    /// **나** (이슈 12). 인맥은 나를 기준으로 그린다 — 목록 맨 위에 늘 있다.
    @ViewBuilder
    private var meSection: some View {
        Section {
            if let me = meList.first, !me.isGone {
                personLink(me) {
                    HStack(spacing: 12) {
                        // 사진이 있으면 사진, 없으면 사람 그림 (빌드 29 실기기 — 나에게 넣은 사진이 목록에 안 보였다).
                        // 크기는 큰 글씨에서 1.6배에서 멈춘다 — 가장 큰 글씨에서 이름보다 커지지 않게 (빌드 18).
                        PersonAvatar(person: me, size: 36, placeholderSymbol: "person.crop.circle.fill")
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

    /// 아이패드 칸 나누기 — **한 칸에 화면 쌓기(NavigationStack)는 하나만** (이슈 50).
    ///
    /// 빌드 25~34 는 왼쪽 바 옆 한 칸 안에 목록 쌓기와 상세 쌓기를 나란히 두었다. 그러면 시스템이 상세 쪽 쌓기를 따로 보지 않아,
    /// 상세 안의 링크(타임라인 기록 · 소개자 · 소개한 인연 · 아는 사이 · 함께한 사람)를 눌러도 목적지가 없는 목록 쪽으로 가서
    /// 아무 일도 없었다(화면 이동 시험 · 아이패드 4개 모두 실패). 그래서 사람 칸은 애플이 권하는 **세 칸 분할**(왼쪽 바 · 목록 · 상세)로,
    /// 다른 칸은 두 칸 분할로 둔다. 칸을 바꾸면 분할 화면이 새로 만들어지지만, 고른 칸 · 사람은 상태로 남는다.
    @ViewBuilder
    private var wideLayout: some View {
        switch section ?? .people {
        case .people:
            NavigationSplitView {
                sidebar
            } content: {
                home
                    .navigationSplitViewColumnWidth(min: 320, ideal: Self.listWidth, max: 460)
            } detail: {
                personDetailStack
            }
        case .network(let tab):
            NavigationSplitView {
                sidebar
            } detail: {
                networkPane(tab)
            }
        case .settings:
            NavigationSplitView {
                sidebar
            } detail: {
                NavigationStack {
                    SettingsView()
                        .appDestinations()
                }
            }
        }
    }

    /// 왼쪽 바 — 사람 · 내 인맥 넷 · 설정. 세로로 돌리면 숨김 단추로 접힌다(시스템 기본).
    private var sidebar: some View {
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
    }

    /// 사람 칸의 상세 — 분할 화면의 상세 칸 뿌리가 쌓기 하나다. 상세 안에서 기록 · 소개한 사람으로 더 들어간다.
    private var personDetailStack: some View {
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

    /// 내 인맥 칸 — 칸 전체를 쓴다. 관계도는 **칸 전체 높이**, 누른 사람은 관계도 위에 **떠 있는 요약 카드** (이슈 51 · 2026-10-28 사용자 —
    /// 빌드 25~35 의 아래 4분의 1 칸에 사람 상세 전체를 두니 보기 불편했다). 카드의 `자세히 보기` 는 칸 전체에 상세를 열고,
    /// 뒤로 가면 관계도로 돌아온다 — 쌓기는 하나다 (이슈 50 · D-57).
    private func networkPane(_ tab: NetworkView.Tab) -> some View {
        NavigationStack(path: $networkPath) {
            NetworkView(initialTab: tab, showsTabs: false, floatsCard: tab == .graph)
                .appDestinations()
        }
        .id(tab)
    }

    /// 목록 칸 너비 — 글자 크기를 따르되 너무 좁거나 넓지 않게.
    private static var listWidth: CGFloat { min(max(Font.scaledLength(340), 320), 460) }

    private func delete(_ person: Person) {
        if selectedPersonID == person.uuid { selectedPersonID = nil }
        do {
            // 지운 직후 5초 동안 되돌리기 (FR-031).
            try DeletionUndo.shared.delete(person, in: context)
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
        if let tag = arguments.filterTag { filterTag = tag }
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
        if arguments.measureSave { measureSaves() }
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
            LaunchTiming.begin("상세")
            LaunchTiming.begin("상세 타임라인")
            show(opened)
            if arguments.openRecord, let latest = RecordStore.timeline(of: opened).first {
                if isWide { detailPath.append(latest) } else { path.append(latest) }
            }
        }
    }
}

/// 목록의 한 줄 — 지운 사람이면 높이 없는 빈 줄. 줄마다 언제나 한 칸이라 목록이 보이는 줄만 그린다 (기준 5).
/// 지운 객체는 그려지는 줄에서만 거른다(CLAUDE.md) — 거르는 자리는 그대로이고, `ForEach` 바로 안의 `if` 만 이 칸 안으로 옮겼다.
private struct LiveRow<Content: View>: View {
    let isGone: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isGone {
            Color.clear
                .frame(height: 0)
                .listRowSeparator(.hidden)
                .accessibilityHidden(true)
        } else {
            content()
        }
    }
}

extension PeopleListView {
    /// CI 큰 견본(`-measureSave`): 사람 한 명 · 기록 한 건을 저장소 문으로 저장해 시간을 남긴다 (요구사항 8.5 저장 0.3초).
    /// 견본은 메모리 저장소라 실기기 디스크보다 빠를 수 있다 — 숫자는 참고로 본다.
    @MainActor fileprivate func measureSaves() {
        var draft = PersonDraft()
        draft.name = "저장시간견본"
        let created = LaunchTiming.measure("저장 · 사람 추가 (\(fetched.count)명 저장소)") {
            try? PersonStore(context: context).create(draft)
        }
        guard let person = created else { return }
        var record = RecordDraft(anchor: person)
        record.title = "저장 시간 견본"
        _ = LaunchTiming.measure("저장 · 기록 추가") {
            try? RecordStore(context: context).create(record)
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
    /// 사진 썸네일 (FR-012) — 사람 목록 · 검색 결과에서만. 고르기 창은 이름만으로 빠르게.
    var showsPhoto = false

    var body: some View {
        if showsPhoto {
            HStack(spacing: 12) {
                PersonAvatar(person: person, size: 40)
                text
            }
        } else {
            text
        }
    }

    private var text: some View {
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
