import Core
import PhotosUI
import SwiftData
import SwiftUI

/// 사람 추가 · 수정 (요구사항 4.2.2). 모달 시트. 취소 시 변경 사항이 있으면 버릴지 묻는다 (FR-022).
///
/// 채우는 길이 셋이다: 손으로 · **연락처에서 가져오기**(FR-015) · **명함**(FR-050, 촬영 또는 사진첩 → 글자 읽기 → 제안).
/// 추가할 때는 **저장하고 다음 사람**(FR-051)으로 시트를 닫지 않고 이어서 등록한다 — 하루 10명 입력이 전제다.
struct PersonEditView: View {
    enum Mode {
        case create
        case edit(Person)
    }

    let mode: Mode
    let onSaved: (Person) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var everyone: [Person]

    @State private var draft: PersonDraft
    @State private var original: PersonDraft
    @State private var confirmingDiscard = false
    @State private var saveError: String?
    @FocusState private var nameFocused: Bool

    // 명함
    @State private var cardItem: PhotosPickerItem?
    @State private var readingCard = false
    @State private var cardReading: CardReadingResult?
    @State private var viewingCard = false

    // 이어서 등록
    @State private var savedInRow: [String] = []
    @State private var appliedArguments = false

    init(mode: Mode, onSaved: @escaping (Person) -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        let draft: PersonDraft
        switch mode {
        case .create: draft = PersonDraft()
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
    private var hasChanges: Bool { draft != original }
    private var store: PersonStore { PersonStore(context: context) }

    /// 동명이인 (FR-021). 안내만 하고 막지 않는다.
    private var duplicates: [Person] {
        store.sameName(as: draft.name, excluding: editingPerson)
    }

    /// 소개자 후보 — 자기 자신은 뺀다.
    private var introducerCandidates: [Person] {
        PersonStore.sorted(everyone.filter { $0 !== editingPerson }, by: .name)
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
                Section {
                    TextField("전화 · 메일", text: $draft.contactNote, axis: .vertical)
                        .lineLimit(1...4)
                        .limited($draft.contactNote, to: Limits.contactNote)
                } header: {
                    Text("연락 수단")
                } footer: {
                    Text("명함이나 연락처에서 가져오면 여기 채워집니다. 형식은 자유입니다.")
                }
                Section("관계 유형") {
                    ChoiceChips(options: RelationshipPresets.relationshipTypes,
                                selection: $draft.relationshipType,
                                maxLength: Limits.relationshipType)
                }
                Section("알게 된 경로") {
                    ChoiceChips(options: RelationshipPresets.metThroughOptions,
                                selection: $draft.metThrough,
                                maxLength: Limits.metThrough)
                    if draft.metThrough == RelationshipPresets.introducedLabel {
                        NavigationLink {
                            PersonPickerView(people: introducerCandidates, selection: $draft.introducedBy)
                        } label: {
                            LabeledContent("소개한 사람", value: draft.introducedBy?.name ?? "선택 안 함")
                        }
                    }
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
                Section("태그") {
                    TagEditor(tags: $draft.tags)
                }
                if isCreate {
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
            .navigationTitle(isCreate ? "사람 추가" : "사람 수정")
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
            .onChange(of: cardItem) { _, item in
                guard let item else { return }
                cardItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    await ingestCard(data, alreadyStraight: false)
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onAppear(perform: applyArgumentsOnce)
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
            if !duplicates.isEmpty {
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
            PhotosPicker(selection: $cardItem, matching: .images) {
                Label("사진첩에서 명함 고르기", systemImage: "photo.on.rectangle")
            }
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
        let processed = alreadyStraight
            ? await CardImaging.normalizedCard(from: data)
            : await CardImaging.straightenedCard(from: data)
        draft.businessCard = processed ?? data
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
            let note = ContactNote.compose(phones: picked.phones, emails: picked.emails)
            if !note.isEmpty { draft.contactNote = note }
        }
    }

    private func save() {
        do {
            let person: Person
            switch mode {
            case .create:
                person = try store.create(draft)
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
        do {
            let person = try store.create(draft)
            savedInRow.append(person.name)
            draft = PersonDraft()
            original = draft
            nameFocused = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func applyArgumentsOnce() {
        guard !appliedArguments else { return }
        appliedArguments = true
        let arguments = LaunchArguments.current
        // CI 스크린샷(-addPerson)에서는 포커스를 주지 않는다 — 시뮬레이터가 키보드 안내 팝업을 띄워 화면을 가린다.
        if isCreate && !arguments.addPerson { nameFocused = true }
        // CI 스크린샷: 견본 명함의 글자를 바로 읽어 제안 화면을 띄운다.
        if arguments.readCard, draft.businessCard != nil {
            Task { await readCard() }
        }
    }
}
