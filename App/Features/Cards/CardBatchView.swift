import Core
import PhotosUI
import SwiftData
import SwiftUI

/// **명함 여러 장 등록** (1.1.9 · 이슈 103 · FR-073 다시 · 2026-11-06 사용자).
///
/// 빌드 62 의 연속 촬영(사람 추가 안에서 한 장씩 채우기)은 쓰기 불편했다 — 홈 `+` 차림표에 따로 두고, 한 화면에서 모아 저장한다.
/// 1. 명함을 찍거나(문서 카메라 · 여러 장) 사진첩에서 고른다(여러 장). 더 찍어 덧붙일 수 있다.
/// 2. 앱이 모두 읽어 한 줄씩 세운다 — 명함 그림 · 이름 · 소속 · 직무. 이름을 못 읽은 장은 꺼 둔다.
/// 3. 줄을 눌러 고치고(읽은 글자에서 고르기 포함), 빼고 싶은 장은 끈다.
/// 4. **모두에게** — 관계 유형 · 알게 된 경로 · 처음 만난 날 · 태그를 한 번에.
/// 5. 맨 아래 `n명 저장` 한 번.
struct CardBatchView: View {
    let onSaved: (Int) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var items: [CardBatchItem] = []
    @State private var reading = 0
    @State private var pickingPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var editingID: UUID?
    @State private var confirmingDiscard = false
    @State private var saveError: String?
    @State private var readFailed = false

    // 모두에게
    @State private var relationshipType: String?
    @State private var metThrough: String?
    @State private var hasFirstMetDate = true
    @State private var firstMetDate = Date()
    @State private var tags: [String] = []
    @State private var pendingTag = ""
    @State private var relationshipChoices = RelationshipPresets.relationshipTypes
    @State private var metThroughChoices = RelationshipPresets.metThroughOptions
    /// 이미 있는 이름 — 같은 사람을 두 번 넣지 않게 줄에 알린다. 화면을 열 때 한 번 센다.
    @State private var existingNames: Set<String> = []

    /// 한 번에 다루는 장 수 — 원본 사진을 들고 있는 동안의 메모리를 묶는다.
    static let limit = 20

    private var included: [CardBatchItem] { items.filter { $0.include && $0.draft.canSave } }

    var body: some View {
        NavigationStack {
            Form {
                addSection
                if !items.isEmpty || reading > 0 { cardsSection }
                if !items.isEmpty { commonSections }
            }
            .keyboardScrollRoom()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("명함 여러 장 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
        .interactiveDismissDisabled(!items.isEmpty)
        .task { loadOnce() }
        .photosPicker(isPresented: $pickingPhotos, selection: $photoItems,
                      maxSelectionCount: max(1, Self.limit - items.count), matching: .images)
        .onChange(of: photoItems) { _, picked in
            guard !picked.isEmpty else { return }
            photoItems = []
            Task { await ingestPhotos(picked) }
        }
        .sheet(item: editingBinding) { item in
            CardBatchItemEditor(item: binding(for: item.id), isDuplicate: isDuplicate(item))
        }
        .modifier(CardBatchAlerts(confirmingDiscard: $confirmingDiscard, saveError: $saveError, readFailed: $readFailed,
                                  onDiscard: { dismiss() }))
    }

    // MARK: 구역

    private var addSection: some View {
        Section {
            if DocumentScanner.isAvailable {
                Button {
                    scan()
                } label: {
                    Label(items.isEmpty ? "명함 찍기" : "더 찍기", systemImage: "camera.viewfinder")
                }
                .disabled(items.count >= Self.limit)
                .accessibilityIdentifier("batchScan")
            }
            Button {
                pickingPhotos = true
            } label: {
                Label("사진첩에서 고르기", systemImage: "photo.on.rectangle")
                    .mutedWhenDisabled()
            }
            .disabled(items.count >= Self.limit)
            .accessibilityIdentifier("batchPhotos")
        } footer: {
            Text(items.isEmpty
                 ? "명함을 여러 장 이어 찍거나 사진첩에서 여러 장 고르세요(한 번에 \(Self.limit)장까지). 다 읽으면 한 화면에서 고치고 한 번에 저장합니다. 글자는 기기 안에서만 읽습니다."
                 : "모두 \(items.count)장 · 저장할 사람 \(included.count)명")
        }
    }

    private var cardsSection: some View {
        Section {
            ForEach($items) { $item in
                CardBatchRow(item: $item, isDuplicate: isDuplicate(item)) {
                    editingID = item.id
                }
            }
            if reading > 0 {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("명함 \(reading)장을 읽는 중…")
                        .font(.scaled(15))
                        .foregroundStyle(Color.muted)
                }
            }
        } header: {
            Text("명함 \(items.count)장")
        } footer: {
            Text("줄을 누르면 이름 · 소속 · 연락 수단을 고칩니다. 오른쪽 동그라미를 끄면 그 장은 저장하지 않습니다. 이름을 읽지 못한 장은 꺼 두었습니다.")
        }
    }

    @ViewBuilder
    private var commonSections: some View {
        Section {
            ChoiceChips(options: relationshipChoices, selection: $relationshipType, maxLength: Limits.relationshipType)
        } header: {
            Text("모두에게 · 관계 유형")
        }
        Section {
            ChoiceChips(options: metThroughChoices.filter { $0 != RelationshipPresets.introducedLabel },
                        selection: $metThrough, maxLength: Limits.metThrough)
        } header: {
            Text("모두에게 · 알게 된 경로")
        } footer: {
            Text("행사 · 모임 이름을 직접 적어 두면 나중에 같은 자리에서 만난 사람을 함께 찾을 수 있습니다.")
        }
        Section {
            Toggle("처음 만난 날 넣기", isOn: $hasFirstMetDate)
                .tint(Color.accent)
            if hasFirstMetDate {
                ApproxDateField("처음 만난 날", date: $firstMetDate, precision: .day)
            }
        } header: {
            Text("모두에게 · 처음 만난 날")
        }
        Section {
            TagEditor(tags: $tags, input: $pendingTag, catalog: nil)
        } header: {
            Text("모두에게 · 태그")
        } footer: {
            Text("여기 고른 것은 저장할 모든 사람에게 같이 들어갑니다. 한 사람만 다른 것은 저장한 뒤 그 사람 수정에서 고치세요.")
        }
    }

    private var saveBar: some View {
        Group {
            if !items.isEmpty {
                Button(action: save) {
                    Text(included.isEmpty ? "저장할 사람이 없습니다" : "\(included.count)명 저장")
                        .font(.scaled(17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: Font.scaledLength(50))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .disabled(included.isEmpty || reading > 0)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.ground)
                .accessibilityIdentifier("batchSave")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("취소") {
                if items.isEmpty { dismiss() } else { confirmingDiscard = true }
            }
        }
    }

    // MARK: 도움

    private var editingBinding: Binding<CardBatchItem?> {
        Binding(get: { items.first { $0.id == editingID } }, set: { if $0 == nil { editingID = nil } })
    }

    private func binding(for id: UUID) -> Binding<CardBatchItem> {
        Binding(get: { items.first { $0.id == id } ?? CardBatchItem(card: nil) },
                set: { new in
                    if let index = items.firstIndex(where: { $0.id == id }) { items[index] = new }
                })
    }

    private func isDuplicate(_ item: CardBatchItem) -> Bool {
        let key = NameSort.key(item.draft.name)
        return !key.isEmpty && existingNames.contains(key)
    }

    private func loadOnce() {
        // CI 스크린샷 52 — 시뮬레이터에는 문서 카메라가 없어 견본 명함 셋을 그려 넣는다(지어낸 사람).
        if LaunchArguments.current.cardBatch && items.isEmpty && reading == 0 {
            let samples = [
                SampleData.renderCard(organization: "솔빛출판", name: "한서연", role: "편집장", phone: "010-5555-0101", email: "seoyeon@example.com"),
                SampleData.renderCard(organization: "다올건축사무소", name: "오지훈", role: "실장", phone: "010-5555-0102", email: "jihoon@example.com"),
                SampleData.renderCard(organization: "푸른숲협동조합", name: "남궁별", role: "사무국장", phone: "010-5555-0103", email: "byeol@example.com"),
            ].compactMap { $0 }
            Task { await ingest(samples, alreadyStraight: true) }
        }
        guard existingNames.isEmpty else { return }
        let store = PersonStore(context: context)
        let people = ((try? store.allPeople()) ?? []).filter { !$0.isGone }
        existingNames = Set(people.map { NameSort.key($0.name) })
        relationshipChoices = ChoiceStore.choices(.relationshipType, used: people.compactMap(\.relationshipType), in: context)
        metThroughChoices = ChoiceStore.choices(.metThrough, used: people.compactMap(\.metThrough), in: context)
    }

    private func scan() {
        DocumentScanner.shared.start { pages in
            guard !pages.isEmpty else { return }
            Task { await ingest(pages, alreadyStraight: true) }
        }
    }

    private func ingestPhotos(_ picked: [PhotosPickerItem]) async {
        reading += picked.count
        var loaded: [Data] = []
        for item in picked {
            if let data = try? await item.loadTransferable(type: Data.self) { loaded.append(data) } else { readFailed = true }
        }
        reading -= picked.count
        await ingest(loaded, alreadyStraight: false)
    }

    /// 한 장씩 차례로 — 펴고(사진첩에서 고른 것) 줄이고 읽는다. 원본은 한 장을 다 읽으면 놓는다.
    private func ingest(_ pages: [Data], alreadyStraight: Bool) async {
        let room = max(Self.limit - items.count, 0)
        let pages = Array(pages.prefix(room))
        reading += pages.count
        for page in pages {
            var card = alreadyStraight ? await CardImaging.normalizedCard(from: page) : await CardImaging.straightenedCard(from: page)
            if card == nil, !alreadyStraight { card = await CardImaging.normalizedCard(from: page) }
            guard let card else {
                reading -= 1
                readFailed = true
                continue
            }
            let suggestion = await CardReading.read(card)
            items.append(CardBatchItem(card: card, suggestion: suggestion))
            reading -= 1
        }
    }

    private func save() {
        let store = PersonStore(context: context)
        let commonTags = TagEditor.merged(tags, pending: pendingTag)
        var saved = 0
        for item in included {
            var draft = item.draft
            draft.businessCard = item.card
            if draft.relationshipType == nil { draft.relationshipType = relationshipType }
            if draft.metThrough == nil { draft.metThrough = metThrough }
            if hasFirstMetDate && !draft.hasFirstMetDate {
                draft.hasFirstMetDate = true
                draft.firstMetDate = firstMetDate
                draft.firstMetPrecision = .day
            }
            draft.tags = TagNormalizer.normalizeList(draft.tags + commonTags)
            do {
                _ = try store.create(draft)
                saved += 1
                items.removeAll { $0.id == item.id }
            } catch {
                saveError = "\(saved)명은 저장했고, \(item.draft.name) 부터 저장하지 못했습니다. \(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 저장해 주세요."
                return
            }
        }
        onSaved(saved)
        dismiss()
    }
}

/// 명함 한 장 — 읽은 내용으로 채운 초안과 저장할지.
struct CardBatchItem: Identifiable, Equatable {
    let id = UUID()
    let card: Data?
    var draft = PersonDraft()
    var suggestion: CardSuggestion?
    var include = false

    init(card: Data?, suggestion: CardSuggestion? = nil) {
        self.card = card
        self.suggestion = suggestion
        guard let suggestion else { return }
        if let name = suggestion.name { draft.name = String(name.prefix(Limits.name)) }
        if let organization = suggestion.organization { draft.organization = String(organization.prefix(Limits.organization)) }
        if let role = suggestion.role { draft.role = String(role.prefix(Limits.role)) }
        draft.fill(suggestion.contact)
        include = draft.canSave
    }
}

/// 목록의 한 줄 — 명함 그림 · 이름 · 소속 · 직무, 오른쪽에 저장할지.
private struct CardBatchRow: View {
    @Binding var item: CardBatchItem
    let isDuplicate: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    if let card = item.card {
                        BusinessCardThumbnail(data: card, maxHeight: Font.scaledLength(48))
                            .frame(width: Font.scaledLength(84))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.draft.name.isEmpty ? "이름을 읽지 못했습니다" : item.draft.name)
                            .font(.scaled(16, weight: .medium))
                            .foregroundStyle(item.draft.name.isEmpty ? Color.muted : Color.ink)
                        let detail = [item.draft.organization, item.draft.role].filter { !$0.isEmpty }.joined(separator: " · ")
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                        }
                        if isDuplicate {
                            Text("같은 이름이 이미 있습니다")
                                .font(.scaled(13))
                                .foregroundStyle(Color.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("batchRow")
            Button {
                item.include.toggle()
            } label: {
                Image(systemName: item.include && item.draft.canSave ? "checkmark.circle.fill" : "circle")
                    .font(.scaled(22))
                    .foregroundStyle(item.include && item.draft.canSave ? Color.accent : Color.faint)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!item.draft.canSave)
            .accessibilityLabel(item.include ? "저장함" : "저장 안 함")
            .accessibilityIdentifier("batchInclude")
        }
    }
}

/// 한 장 고치기 — 이름 · 소속 · 직무 · 연락 수단. 읽은 글자에서 고르는 창은 사람 추가와 같은 것(`CardSuggestionView`).
private struct CardBatchItemEditor: View {
    @Binding var item: CardBatchItem
    let isDuplicate: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showingSuggestion = false
    @State private var viewingCard = false

    var body: some View {
        NavigationStack {
            Form {
                if let card = item.card {
                    Section {
                        Button {
                            viewingCard = true
                        } label: {
                            BusinessCardThumbnail(data: card)
                        }
                        .buttonStyle(.plain)
                        if item.suggestion != nil {
                            Button {
                                showingSuggestion = true
                            } label: {
                                Label("읽은 글자에서 고르기", systemImage: "text.viewfinder")
                            }
                        }
                    }
                }
                Section {
                    TextField("이름", text: $item.draft.name)
                        .limited($item.draft.name, to: Limits.name)
                    TextField("회사 · 조직", text: $item.draft.organization)
                        .limited($item.draft.organization, to: Limits.organization)
                    TextField("직무 · 직책", text: $item.draft.role)
                        .limited($item.draft.role, to: Limits.role)
                } header: {
                    Text("이름 · 소속")
                } footer: {
                    if isDuplicate {
                        Text("같은 이름이 이미 있습니다. 같은 사람이면 이 장을 끄고, 다른 사람이면 그대로 저장해도 됩니다.")
                    }
                }
                Section("연락 수단") {
                    TextField("휴대전화", text: $item.draft.mobilePhone)
                        .keyboardType(.phonePad)
                        .limited($item.draft.mobilePhone, to: Limits.phone)
                    TextField("사무실 전화", text: $item.draft.officePhone)
                        .keyboardType(.phonePad)
                        .limited($item.draft.officePhone, to: Limits.phone)
                    TextField("이메일", text: $item.draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .limited($item.draft.email, to: Limits.email)
                }
            }
            .keyboardScrollRoom()
            .navigationTitle("명함 한 장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        if item.draft.canSave && !item.include { item.include = true }
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSuggestion) {
                if let suggestion = item.suggestion {
                    CardSuggestionView(suggestion: suggestion, draft: $item.draft)
                }
            }
            .sheet(isPresented: $viewingCard) {
                if let card = item.card { BusinessCardViewer(data: card) }
            }
        }
    }
}

/// 버리기 확인 · 저장 실패 · 읽기 실패 — 양식 밖에 붙인다(이슈 72 교훈).
private struct CardBatchAlerts: ViewModifier {
    @Binding var confirmingDiscard: Bool
    @Binding var saveError: String?
    @Binding var readFailed: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("읽은 명함을 버릴까요?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive, action: onDiscard)
                Button("계속 고치기", role: .cancel) {}
            } message: {
                Text("저장하지 않은 명함은 사라집니다.")
            }
            .alert("저장하지 못했습니다", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .alert("읽지 못한 사진이 있습니다", isPresented: $readFailed) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text("명함이 화면을 채우게 밝은 곳에서 다시 찍어 보세요. iCloud 에만 있는 사진은 내려받은 뒤에 고를 수 있습니다.")
            }
    }
}
