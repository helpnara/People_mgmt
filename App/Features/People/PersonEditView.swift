import Core
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 사람 추가 · 수정 (요구사항 4.2.2). 모달 시트. 취소 시 변경 사항이 있으면 버릴지 묻는다 (FR-022).
///
/// 채우는 길이 셋이다: 손으로 · **연락처에서 가져오기**(FR-015) · **명함**(FR-050, 촬영 또는 사진첩 → 글자 읽기 → 제안).
/// 추가할 때는 **저장하고 다음 사람**(FR-051)으로 시트를 닫지 않고 이어서 등록한다 — 하루 10명 입력이 전제다.
struct PersonEditView: View {
    enum Mode {
        case create
        /// **나** 를 처음 적는다 (이슈 12). 관계 유형 · 알게 된 경로 · 첫 인연 · 이어서 등록은 없다.
        case createMe
        case edit(Person)
    }

    let mode: Mode
    let onSaved: (Person) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// 나는 빠진다 — 기록의 참여자 · 소개자가 되지 않는다 (이슈 12).
    @Query(filter: #Predicate<Person> { $0.isMe == false }) private var everyone: [Person]

    @State private var draft: PersonDraft
    @State private var original: PersonDraft
    @State private var confirmingDiscard = false
    @State private var saveError: String?
    @FocusState private var nameFocused: Bool

    // 명함
    @State private var cardItem: PhotosPickerItem?
    /// 사진첩 고르기 창. **양식(Form) 줄 안에 `PhotosPicker` 뷰를 두지 않는다** — 단추는 이 값만 켜고,
    /// 창은 시트 바깥쪽의 `.photosPicker` 수식어가 띄운다 (느린 여백과 같은 길 · 이슈 10).
    @State private var pickingCardPhoto = false
    @State private var readingCard = false
    @State private var cardReading: CardReadingResult?
    @State private var viewingCard = false

    // 이어서 등록
    @State private var savedInRow: [String] = []
    @State private var appliedArguments = false

    /// 관계 유형 · 알게 된 경로 선택지 — 기본값 + 직접 입력해 쓴 값 (이슈 13).
    /// **본문에서 세지 않는다** — 화면을 열 때와 이어서 등록할 때 한 번 센다 (CLAUDE.md · 이슈 10).
    @State private var relationshipChoices = RelationshipPresets.relationshipTypes
    @State private var metThroughChoices = RelationshipPresets.metThroughOptions

    /// 소개자 · 아는 사람 후보(자기 자신은 뺀다, 이름 순)와 같은 이름 찾기 사전.
    /// **본문에서 사람 전원을 훑지 않는다** (전수조사 이슈 18) — 빌드 11 까지는 글자를 칠 때마다 전원을 거르고
    /// 두 번 정렬하고 이름 열쇠를 다시 셌다. 사람 수가 바뀔 때만 다시 만들고, 같은 이름은 이름이 바뀔 때만 찾는다.
    @State private var candidates: [Person] = []
    @State private var nameIndex: [String: [Person]] = [:]
    @State private var duplicates: [Person] = []
    /// 태그 칸에 치던 글자 — 저장할 때 태그로 넣는다 (이슈 19).
    @State private var pendingTag = ""
    /// 명함 사진을 읽지 못했다 (이슈 19) — 말없이 넘어가지 않는다.
    @State private var cardFailed = false

    init(mode: Mode, onSaved: @escaping (Person) -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        let draft: PersonDraft
        switch mode {
        case .create, .createMe: draft = PersonDraft()
        case .edit(let person): draft = PersonDraft(person: person)
        }
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    private var editingPerson: Person? {
        if case .edit(let person) = mode { return person }
        return nil
    }

    private var isCreate: Bool { editingPerson == nil }
    /// 나를 적는 중인가 — 새로 적든 고치든.
    private var isMe: Bool {
        if case .createMe = mode { return true }
        return editingPerson?.isMe ?? false
    }
    private var title: String {
        if isMe { return isCreate ? "내 정보" : "내 정보 수정" }
        return isCreate ? "사람 추가" : "사람 수정"
    }
    private var hasChanges: Bool { draft != original }
    private var store: PersonStore { PersonStore(context: context) }

    private var acquaintanceSummary: String {
        let names = draft.acquaintances.prefix(2).map(\.name)
        if draft.acquaintances.isEmpty { return "고르지 않음" }
        let rest = draft.acquaintances.count - names.count
        return names.joined(separator: ", ") + (rest > 0 ? " 외 \(rest)명" : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if !savedInRow.isEmpty { savedBanner }
                importSection
                nameSection
                Section("소속") {
                    TextField("회사 · 조직", text: $draft.organization)
                        .limited($draft.organization, to: Limits.organization)
                    TextField("직무 · 직책", text: $draft.role)
                        .limited($draft.role, to: Limits.role)
                }
                cardSection
                contactSection
                if !isMe { relationshipSections }
                Section("태그") {
                    TagEditor(tags: $draft.tags, input: $pendingTag)
                }
                if isCreate && !isMe {
                    Section {
                        Button(action: saveAndContinue) {
                            Label("저장하고 다음 사람 추가", systemImage: "person.badge.plus")
                                .font(.scaled(16, weight: .semibold))
                        }
                        .disabled(!draft.canSave)
                    } footer: {
                        Text("시트를 닫지 않고 바로 다음 사람을 적습니다.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedInRow.isEmpty ? "취소" : "닫기") {
                        if hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(!draft.canSave)
                }
            }
            .confirmationDialog("변경 사항을 버리시겠습니까?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive) { dismiss() }
                Button("계속 편집", role: .cancel) {}
            }
            .alert("명함 사진을 읽지 못했습니다", isPresented: $cardFailed) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text("다른 사진으로 다시 시도해 주세요.")
            }
            .alert("저장하지 못했습니다", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("다시 시도", action: save)
                Button("닫기", role: .cancel) {}
            } message: {
                Text("\(saveError ?? "") 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요. 입력한 내용은 그대로 남아 있습니다.")
            }
            .sheet(item: $cardReading) { reading in
                CardSuggestionView(suggestion: reading.suggestion, draft: $draft)
            }
            .fullScreenCover(isPresented: $viewingCard) {
                if let data = draft.businessCard { BusinessCardViewer(data: data) }
            }
            .photosPicker(isPresented: $pickingCardPhoto, selection: $cardItem, matching: .images)
            .onChange(of: cardItem) { _, item in
                guard let item else { return }
                cardItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        cardFailed = true
                        return
                    }
                    await ingestCard(data, alreadyStraight: false)
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onAppear(perform: applyArgumentsOnce)
        .onAppear(perform: rebuildPeopleIndex)
        .onChange(of: everyone.count) { _, _ in rebuildPeopleIndex() }
        .onChange(of: draft.name) { _, _ in refreshDuplicates() }
    }

    // MARK: - 구역

    private var savedBanner: some View {
        Section {
            Label {
                Text("\(savedInRow.last ?? "") 저장됨 · 이번에 \(savedInRow.count)명")
                    .font(.scaled(15, weight: .medium))
                    .foregroundStyle(Color.accent)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accent)
            }
        }
    }

    /// 관계 유형 · 알게 된 경로 · 첫 인연 — 나에게는 없다 (이슈 12).
    @ViewBuilder
    private var relationshipSections: some View {
        Section("관계 유형") {
            ChoiceChips(options: relationshipChoices,
                        selection: $draft.relationshipType,
                        maxLength: Limits.relationshipType)
        }
        Section("알게 된 경로") {
            ChoiceChips(options: metThroughChoices,
                        selection: $draft.metThrough,
                        maxLength: Limits.metThrough)
            if draft.metThrough == RelationshipPresets.introducedLabel {
                NavigationLink {
                    PersonPickerView(people: candidates, selection: $draft.introducedBy)
                } label: {
                    LabeledContent("소개한 사람", value: draft.introducedBy?.name ?? "선택 안 함")
                }
            }
        }
        Section {
            NavigationLink {
                PeopleMultiPickerView(people: candidates, selection: $draft.acquaintances, title: "아는 사람")
            } label: {
                LabeledContent("아는 사람", value: acquaintanceSummary)
            }
        } header: {
            Text("아는 사이")
        } footer: {
            Text("서로 아는 사람을 고르면 기록이 없어도 관계도에 선이 생기고, 모임(그룹)을 찾는 바탕이 됩니다.")
        }
        Section("첫 인연") {
            Toggle("처음 만난 날짜", isOn: $draft.hasFirstMetDate)
            if draft.hasFirstMetDate {
                DatePicker("날짜", selection: $draft.firstMetDate, displayedComponents: .date)
            }
            TextField("어떤 계기로 알게 되었나요?", text: $draft.firstNote, axis: .vertical)
                .lineLimit(3...8)
                .limited($draft.firstNote, to: Limits.firstNote)
        }
    }

    /// 연락 수단 다섯 칸 (FR-032 · 이슈 11). 칸 이름이 왼쪽에 늘 보인다 — 채운 뒤에도 무슨 칸인지 알게.
    private var contactSection: some View {
        Section {
            contactField("휴대전화", text: $draft.mobilePhone, prompt: "010-0000-0000", limit: Limits.phone, keyboard: .phonePad)
            contactField("사무실", text: $draft.officePhone, prompt: "02-000-0000", limit: Limits.phone, keyboard: .phonePad)
            contactField("팩스", text: $draft.faxNumber, prompt: "02-000-0000", limit: Limits.phone, keyboard: .phonePad)
            contactField("이메일", text: $draft.email, prompt: "name@example.com", limit: Limits.email, keyboard: .emailAddress)
            LabeledContent {
                TextField("다른 번호 · 메모", text: $draft.contactNote, axis: .vertical)
                    .lineLimit(1...4)
                    .limited($draft.contactNote, to: Limits.contactNote)
            } label: {
                Text("기타").font(.scaled(15)).foregroundStyle(Color.muted)
            }
        } header: {
            Text("연락 수단")
        } footer: {
            Text("명함이나 연락처에서 가져오면 칸을 나눠 채웁니다. 칸에 들지 않는 번호는 기타로 갑니다.")
        }
    }

    private func contactField(_ label: String, text: Binding<String>, prompt: String, limit: Int, keyboard: UIKeyboardType) -> some View {
        LabeledContent {
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .limited(text, to: limit)
        } label: {
            Text(label).font(.scaled(15)).foregroundStyle(Color.muted)
        }
    }

    /// 직접 입력해 쓴 값을 선택지로 (이슈 13). 저장소를 읽으므로 **동작에서만** 부른다.
    private func refreshChoices() {
        let people = (try? store.allPeople()) ?? []
        relationshipChoices = RelationshipPresets.choices(presets: RelationshipPresets.relationshipTypes,
                                                          used: people.compactMap(\.relationshipType))
        metThroughChoices = RelationshipPresets.choices(presets: RelationshipPresets.metThroughOptions,
                                                        used: people.compactMap(\.metThrough))
    }

    private var importSection: some View {
        Section {
            Button(action: importContact) {
                Label("연락처에서 가져오기", systemImage: "person.crop.circle.badge.plus")
            }
        } footer: {
            Text("고른 한 사람의 이름 · 소속 · 직무 · 전화 · 메일만 가져옵니다. 연락처 전체를 읽지 않습니다.")
        }
    }

    private var nameSection: some View {
        Section {
            TextField("이름", text: $draft.name)
                .font(.scaled(18, weight: .semibold))
                .focused($nameFocused)
                .submitLabel(.next)
                .limited($draft.name, to: Limits.name)
            if let problem = draft.nameProblem, !TextNormalization.normalized(draft.name).isEmpty {
                Text(problem).font(.scaled(13)).foregroundStyle(Color.danger)
            }
            if !isMe && !duplicates.isEmpty {
                Label(duplicateText, systemImage: "person.2")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
        } header: {
            Text("이름")
        } footer: {
            Text("이름만 있으면 저장할 수 있습니다. 나머지는 나중에 채워도 됩니다.")
        }
    }

    private var cardSection: some View {
        Section {
            if let data = draft.businessCard {
                Button {
                    viewingCard = true
                } label: {
                    BusinessCardThumbnail(data: data)
                }
                .buttonStyle(.plain)
            }
            if DocumentScanner.isAvailable {
                Button {
                    DocumentScanner.shared.start { data in
                        guard let data else { return }
                        Task { await ingestCard(data, alreadyStraight: true) }
                    }
                } label: {
                    Label(draft.businessCard == nil ? "명함 촬영" : "명함 다시 촬영", systemImage: "camera.viewfinder")
                }
            }
            Button {
                pickingCardPhoto = true
            } label: {
                Label("사진첩에서 명함 고르기", systemImage: "photo.on.rectangle")
            }
            .disabled(readingCard)
            if draft.businessCard != nil {
                Button {
                    Task { await readCard() }
                } label: {
                    Label("명함 글자 읽기", systemImage: "text.viewfinder")
                }
                .disabled(readingCard)
                Button(role: .destructive) {
                    draft.businessCard = nil
                } label: {
                    Label("명함 지우기", systemImage: "trash")
                }
            }
            if readingCard {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("명함을 펴고 글자를 읽는 중…").font(.scaled(14)).foregroundStyle(Color.muted)
                }
            }
        } header: {
            Text("명함")
        } footer: {
            Text("촬영하면 명함 테두리를 자동으로 찾아 반듯하게 폅니다. 사진첩 사진도 테두리를 찾아 폅니다. 글자는 기기 안에서만 읽고 어디로도 보내지 않습니다.")
        }
    }

    private var duplicateText: String {
        let shown = duplicates.prefix(2).map { person -> String in
            if let subtitle = person.subtitle { return "\(person.name) (\(subtitle))" }
            return person.name
        }
        var text = "같은 이름이 \(duplicates.count)명 있습니다: \(shown.joined(separator: ", "))"
        if duplicates.count > 2 { text += " 외" }
        return text + ". 동명이인이면 그대로 저장해도 됩니다."
    }

    // MARK: - 동작

    /// 명함 사진을 받아 저장하고 바로 글자를 읽는다.
    private func ingestCard(_ data: Data, alreadyStraight: Bool) async {
        readingCard = true
        var processed = alreadyStraight
            ? await CardImaging.normalizedCard(from: data)
            : await CardImaging.straightenedCard(from: data)
        // 펴지 못했으면 줄이기만 한다. **원본을 그대로 담지 않는다** — 휴대폰 사진은 수 MB 이고 화면마다 다시 풀린다 (이슈 10).
        if processed == nil, !alreadyStraight {
            processed = await CardImaging.normalizedCard(from: data)
        }
        guard let card = processed else {
            readingCard = false
            cardFailed = true
            return
        }
        draft.businessCard = card
        await readCard()
    }

    private func readCard() async {
        guard let data = draft.businessCard else { return }
        readingCard = true
        let suggestion = await CardReading.read(data)
        readingCard = false
        cardReading = CardReadingResult(suggestion: suggestion)
    }

    private func importContact() {
        ContactPicker.shared.start { picked in
            guard let picked else { return }
            let name = ContactName.compose(given: picked.given, family: picked.family)
            if !name.isEmpty { draft.name = String(name.prefix(Limits.name)) }
            if !picked.organization.isEmpty { draft.organization = String(picked.organization.prefix(Limits.organization)) }
            let role = [picked.department, picked.jobTitle]
                .map { TextNormalization.normalized($0) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !role.isEmpty { draft.role = String(role.prefix(Limits.role)) }
            // 번호마다 붙은 이름표(휴대전화 · 직장 · 직장 팩스 …)로 칸을 나눈다 (이슈 11).
            draft.fill(ContactSorter.fromContact(phones: picked.phones, emails: picked.emails))
        }
    }

    /// 사람 수가 바뀔 때만 — 후보 목록과 같은 이름 사전을 다시 만든다 (이슈 18).
    private func rebuildPeopleIndex() {
        let others = everyone.filter { $0 !== editingPerson && !$0.isGone }
        candidates = PersonStore.sorted(others, by: .name)
        var index: [String: [Person]] = [:]
        for person in others { index[NameSort.key(person.name), default: []].append(person) }
        nameIndex = index
        refreshDuplicates()
    }

    /// 동명이인 (FR-021). 안내만 하고 막지 않는다. 이름이 바뀔 때만 사전에서 찾는다.
    private func refreshDuplicates() {
        let key = NameSort.key(draft.name)
        duplicates = key.isEmpty ? [] : (nameIndex[key] ?? []).filter { !$0.isGone }
    }

    /// 태그 칸에 치다 만 글자를 태그로 넣는다 — 저장할 때 버려지지 않게 (이슈 19).
    private func flushPendingTag() {
        draft.tags = TagEditor.merged(draft.tags, pending: pendingTag)
        pendingTag = ""
    }

    private func save() {
        flushPendingTag()
        do {
            let person: Person
            switch mode {
            case .create:
                person = try store.create(draft)
            case .createMe:
                person = try store.create(draft, isMe: true)
            case .edit(let existing):
                try store.apply(draft, to: existing)
                person = existing
            }
            dismiss()
            onSaved(person)
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// 저장하고 시트를 비운 채로 다음 사람을 받는다 (FR-051).
    private func saveAndContinue() {
        flushPendingTag()
        do {
            let person = try store.create(draft)
            savedInRow.append(person.name)
            draft = PersonDraft()
            original = draft
            nameFocused = true
            // 방금 직접 입력한 유형 · 경로가 다음 사람의 선택지에 바로 붙는다 (이슈 13).
            refreshChoices()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func applyArgumentsOnce() {
        guard !appliedArguments else { return }
        appliedArguments = true
        refreshChoices()
        let arguments = LaunchArguments.current
        // CI 스크린샷(-addPerson)에서는 포커스를 주지 않는다 — 시뮬레이터가 키보드 안내 팝업을 띄워 화면을 가린다.
        if isCreate && !arguments.addPerson { nameFocused = true }
        // CI 스크린샷: 견본 명함의 글자를 바로 읽어 제안 화면을 띄운다.
        if arguments.readCard, draft.businessCard != nil {
            Task { await readCard() }
        }
        // CI: 시트가 다 올라온 뒤 사진첩 고르기 창을 띄운다.
        if arguments.pickCardPhoto {
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                pickingCardPhoto = true
            }
        }
    }
}
