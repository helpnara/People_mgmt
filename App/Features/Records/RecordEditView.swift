import Core
import PhotosUI
import SwiftData
import SwiftUI

/// 기록 추가 · 수정 (요구사항 4.2.4). 모달 시트.
struct RecordEditView: View {
    enum Mode {
        case create(anchor: Person)
        case edit(Record)
    }

    let mode: Mode
    let onSaved: (Record) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// 나는 빠진다 — 기록의 참여자 · 소개자가 되지 않는다 (이슈 12).
    @Query(filter: #Predicate<Person> { $0.isMe == false }) private var everyone: [Person]

    @State private var draft: RecordDraft
    @State private var original: RecordDraft
    @State private var confirmingDiscard = false
    @State private var saveError: String?
    /// 함께한 사람 후보 — 이름 순. **본문에서 정렬하지 않는다** (전수조사 이슈 18): 빌드 11 까지는 메모를 한 글자
    /// 칠 때마다 사람 전원을 비교마다 열쇠를 만드는 방식으로 정렬했다(이슈 6 의 0.6초). 사람 수가 바뀔 때만 만든다.
    @State private var candidates: [Person] = []
    /// 태그 칸에 치던 글자 — 저장할 때 태그로 넣는다 (이슈 19).
    @State private var pendingTag = ""
    /// 태그 자동완성 (FR-026) — 화면이 열릴 때 주 스레드 밖에서 한 번 만든다.
    @State private var tagCatalog: TagCatalog?
    /// 새 기록이면 제목 칸에 바로 커서를 둔다 — 기록 30초(1.4 성공 기준) · 전수조사 이슈 22.
    @FocusState private var titleFocused: Bool
    /// 최근 함께한 사람 (빌드 16) — 최근 기록부터 처음 보이는 사람 8명. 사람 수가 바뀔 때 한 번 센다.
    @State private var recentPeople: [Person] = []
    /// CI 스크린샷 — 함께한 사람 고르기를 바로 연다 (`-pickParticipants` · 이슈 49).
    @State private var pickingParticipants = LaunchArguments.current.pickParticipants
    /// 지난 기록의 장소 — 눌러야 들어간다 (빌드 16). 저절로 채우면 틀린 장소가 저장되기 쉽다.
    private let lastLocation = RecordMemory.lastLocation
    // 기록 사진 (9판 · FR-058). 사진첩 창은 양식(Form) 줄 안이 아니라 바깥 수식어가 띄운다 (사람 수정과 같은 길 · 이슈 10).
    @State private var pickingPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var processingPhotos = false
    @State private var photoFailed = false
    @State private var removingPhoto: DraftPhoto?
    /// 눌러 고른 사진 — 맨 앞으로 · 빼기를 묻는다 (빌드 48 · 길게 누르기 메뉴는 양식 칸 안에서 뜨지 않았다).
    @State private var choosingPhoto: DraftPhoto?
    /// 기록 틀 (12판 · 이슈 95 · FR-070) — 화면이 열릴 때 한 번 읽는다.
    @State private var templates: [RecordTemplate] = []
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var templateSaved = false

    init(mode: Mode, onSaved: @escaping (Record) -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        let draft: RecordDraft
        switch mode {
        case .create(let anchor):
            var fresh = RecordDraft(anchor: anchor)
            // 지난번에 고른 기록 유형으로 시작한다 (빌드 16) — 하루 여러 명이면 같은 유형이 이어진다.
            if let last = RecordMemory.lastType { fresh.recordType = last }
            draft = fresh
        case .edit(let record): draft = RecordDraft(record: record)
        }
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    private var anchor: Person? {
        if case .create(let person) = mode { return person }
        return nil
    }

    private var isCreate: Bool { anchor != nil }

    /// 고치는 기록 — 저장된 사진을 찾을 곳. 새 기록이면 nil.
    private var editingRecord: Record? {
        if case .edit(let record) = mode { return record }
        return nil
    }

    private var canAddPhoto: Bool { draft.photos.count < RecordPhotos.limit && !processingPhotos }
    private var hasChanges: Bool { draft != original }
    private var store: RecordStore { RecordStore(context: context) }

    /// 시각 넣기 — 켜면 지금 시각을 30분 단위로 내린 값에서 시작한다. 끄면 시각을 비운다.
    private var hasTime: Binding<Bool> {
        Binding(get: { draft.occurredMinute != nil }, set: { on in
            if on {
                // 시각 고르개를 쓰기 전에 키보드를 내린다 — 초점이 제목 칸에 남아 화면이 튀지 않게 (이슈 61).
                Keyboard.dismiss()
                let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
                draft.occurredMinute = (parts.hour ?? 12) * 60 + ((parts.minute ?? 0) / 30) * 30
            } else {
                draft.occurredMinute = nil
            }
        })
    }

    /// 시각 고르개 ↔ 자정부터 센 분. 날짜는 쓰지 않는다(날짜는 위 칸).
    private var timeOfDay: Binding<Date> {
        Binding(get: {
            let minute = draft.occurredMinute ?? 12 * 60
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft.occurredMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

    var body: some View {
        NavigationStack {
            photoHandling(editor)
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
        }
        .interactiveDismissDisabled(hasChanges)
        // 열린 동안 뿌리 화면의 뼈대를 바꾸지 않는다 — 바뀌면 이 창이 내려가 적던 것이 사라진다 (이슈 77).
        .holdsLayout()
        .task(id: everyone.count) {
            candidates = PersonStore.sorted(everyone.filter { !$0.isGone }, by: .name)
            loadRecentPeople()
            templates = TemplateStore(context: context).templates()
        }
        .modifier(TemplateNaming(naming: $namingTemplate, name: $templateName, saved: $templateSaved, onSave: saveTemplate))
    }

    /// 양식과 그 둘레(키보드 · 고르기 화면 · 제목 · 단추). 칸마다 따로 떼어 둔다 — 한 식이 길면 컴파일러가 형식을 제때 못 맞춘다
    /// (빌드 45 첫 CI · `unable to type-check this expression in reasonable time`).
    private var editor: some View {
        ScrollViewReader { proxy in
            Form {
                if isCreate && !templates.isEmpty { templateSection }
                dateSection
                typeSection
                contentSection
                photoSection
                placeSection
                participantSection
                tagSection
                saveTemplateSection
            }
            .task { await showTagInputForScreenshot(proxy) }
            // 키보드가 가린 만큼 끝에 여백 — 키보드가 올라와도 마지막 칸까지 내려간다 (이슈 80).
            .keyboardScrollRoom()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $pickingParticipants) {
            PeopleMultiPickerView(people: candidates, selection: $draft.participants, locked: anchor)
        }
        .navigationTitle(isCreate ? "기록 추가" : "기록 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    if hasChanges { confirmingDiscard = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(!draft.canSave)
            }
        }
    }

    /// 기록 사진의 사진첩 창 · 빼기 확인 · 실패 안내 (9판 · FR-058).
    private func photoHandling<Content: View>(_ content: Content) -> some View {
        photoDialogs(content)
            .photosPicker(isPresented: $pickingPhotos, selection: $photoItems,
                          maxSelectionCount: max(1, RecordPhotos.limit - draft.photos.count), matching: .images)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                Task { await ingestPhotos(items) }
            }
            .alert("사진을 읽지 못했습니다", isPresented: $photoFailed) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text("다른 사진을 골라 주세요. iCloud 에만 있는 사진은 내려받은 뒤에 고를 수 있습니다.")
            }
    }

    /// 사진 빼기 확인 · 눌러 고른 사진의 맨 앞으로 / 빼기 (식을 나눠 형식 맞추기 시간을 줄인다 — 빌드 45 첫 CI).
    private func photoDialogs<Content: View>(_ content: Content) -> some View {
        content
            .confirmationDialog("사진을 뺄까요?", isPresented: Binding(get: { removingPhoto != nil }, set: { if !$0 { removingPhoto = nil } }),
                                titleVisibility: .visible, presenting: removingPhoto) { photo in
                Button("사진 빼기", role: .destructive) {
                    draft.photos.removeAll { $0.id == photo.id }
                    removingPhoto = nil
                }
                Button("취소", role: .cancel) { removingPhoto = nil }
            } message: { _ in
                Text("저장하면 이 기록에서 사진이 지워집니다. 저장하기 전에는 취소로 되돌릴 수 있습니다.")
            }
            .confirmationDialog("이 사진을", isPresented: Binding(get: { choosingPhoto != nil }, set: { if !$0 { choosingPhoto = nil } }),
                                titleVisibility: .visible, presenting: choosingPhoto) { photo in
                if draft.photos.first?.id != photo.id {
                    Button("맨 앞으로 — 대표 사진으로") {
                        moveToFront(photo)
                        choosingPhoto = nil
                    }
                }
                // 이 창에서 고르는 것이 곧 확인이다(모든 삭제에 확인 · CLAUDE.md). 저장해야 지워진다.
                Button("사진 빼기", role: .destructive) {
                    draft.photos.removeAll { $0.id == photo.id }
                    choosingPhoto = nil
                }
                Button("취소", role: .cancel) { choosingPhoto = nil }
            } message: { photo in
                Text(draft.photos.first?.id == photo.id
                     ? "대표 사진입니다. 목록에 작게 보입니다. 빼면 저장할 때 이 기록에서 지워집니다."
                     : "대표 사진은 목록에 작게 보입니다. 빼면 저장할 때 이 기록에서 지워집니다.")
            }
    }

    private var dateSection: some View {
        Section {
            PrecisionPicker(selection: $draft.occurredPrecision)
            ApproxDateField("날짜", date: $draft.occurredAt, precision: draft.occurredPrecision)
            // 시각 (8판 · D-63) — 날짜까지 정한 기록에만. 같은 날 약속이 여럿이면 차례가 이것으로 정해진다.
            if draft.occurredPrecision == .day {
                Toggle("시각 넣기", isOn: hasTime)
                    .accessibilityIdentifier("recordTimeToggle")
                if draft.occurredMinute != nil {
                    DatePicker("시각", selection: timeOfDay, displayedComponents: .hourAndMinute)
                }
                // 반복 (12판 · 이슈 94 · FR-069) — 그 회차가 지나거나 결과를 적으면 다음 회차 하나를 앞날짜로 만든다.
                Picker("반복", selection: $draft.repeatRule) {
                    ForEach(RepeatRule.allCases) { rule in
                        Text(RepeatRule.describe(rule, on: civilDay(draft.occurredAt), anchorDay: anchorDayForLabel)).tag(rule)
                    }
                }
                .accessibilityIdentifier("repeatPicker")
            }
        } footer: {
            Text(draft.repeatRule == .none || draft.occurredPrecision != .day
                 ? "기본은 오늘입니다. 예정된 만남은 앞날짜로 적어도 됩니다. 같은 날 약속이 여럿이면 시각을 넣어 두면 차례대로 보입니다. 날짜가 정확하지 않으면 월까지 · 연도만을 고르세요."
                 : "반복하는 약속은 이 회차의 날이 지나거나 결과를 적으면 다음 회차 하나를 앞날짜로 만들어 둡니다. 다음 회차에서 반복을 끄면 더 만들지 않습니다.")
        }
    }

    /// 날짜 칸의 그날 — 반복 이름에 쓴다.
    private func civilDay(_ date: Date) -> CivilDate {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// 매달 같은 날의 처음 날 — 날짜를 바꾸지 않았으면 저장된 처음 날(31일 → 2월 28일 회차에서도 `매달 31일`).
    private var anchorDayForLabel: Int? {
        guard let record = editingRecord, draft.occurredAt == original.occurredAt else { return nil }
        return record.repeatAnchorDay
    }

    /// 기록 틀 고르기 (12판 · 이슈 95 · FR-070) — 새 기록 맨 위. 누르면 유형 · 제목 · 장소 · 태그 · 함께한 사람을 채운다.
    private var templateSection: some View {
        Section {
            WrapLayout(spacing: 8) {
                ForEach(templates) { template in
                    Button {
                        if !template.isGone { TemplateStore(context: context).fill(&draft, from: template) }
                    } label: {
                        Chip(text: template.name)
                            .tapTarget()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("templateChip")
                }
            }
        } header: {
            Text("틀")
        } footer: {
            Text("자주 쓰는 기록 모양을 누르면 유형 · 제목 · 장소 · 태그 · 함께한 사람이 채워집니다. 날짜 · 메모는 그대로입니다.")
        }
    }

    /// 틀로 저장 (12판 · FR-070) — 지금 유형 · 제목 · 장소 · 태그 · 함께한 사람을 이름 붙여 둔다.
    private var saveTemplateSection: some View {
        Section {
            Button {
                templateName = TextNormalization.nilIfEmpty(draft.title) ?? ""
                namingTemplate = true
            } label: {
                Label("이 기록을 틀로 저장", systemImage: "square.on.square")
                    .font(.scaled(15))
            }
            .accessibilityIdentifier("saveTemplate")
        } footer: {
            Text("설정 → 기록 틀에서 이름을 바꾸거나 뺄 수 있습니다.")
        }
    }

    private func saveTemplate() {
        do {
            if try TemplateStore(context: context).save(draft, name: templateName) != nil {
                templates = TemplateStore(context: context).templates()
                templateSaved = true
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var typeSection: some View {
        Section("기록 유형") {
            RecordTypeChips(selection: $draft.recordType)
        }
    }

    private var contentSection: some View {
        Section {
            TextField("제목", text: $draft.title)
                .focused($titleFocused)
                .font(.scaled(17, weight: .semibold))
                .limited($draft.title, to: Limits.recordTitle)
            TextField("함께한 일이나 나눈 이야기", text: $draft.note, axis: .vertical)
                .lineLimit(4...12)
                .limited($draft.note, to: Limits.recordNote)
        } header: {
            Text("내용")
        } footer: {
            Text("제목이나 메모 중 하나만 있으면 저장할 수 있습니다.")
        }
    }

    private var placeSection: some View {
        Section("장소") {
            TextField("장소", text: $draft.location)
                .limited($draft.location, to: Limits.location)
            if isCreate, draft.location.isEmpty, let lastLocation {
                Button {
                    draft.location = lastLocation
                } label: {
                    Label("지난 장소: \(lastLocation)", systemImage: "arrow.uturn.backward")
                        .font(.scaled(14))
                        .lineLimit(2)
                }
            }
        }
    }

    private var participantSection: some View {
        Section("함께한 사람") {
            NavigationLink {
                PeopleMultiPickerView(people: candidates, selection: $draft.participants, locked: anchor)
            } label: {
                LabeledContent("함께한 사람", value: participantSummary)
            }
            if !draft.participants.isEmpty {
                WrapLayout(spacing: 8) {
                    ForEach(draft.participants) { person in
                        Chip(text: person.name, selected: person === anchor)
                    }
                }
            }
            recentChips
        }
    }

    private var tagSection: some View {
        Section("태그") {
            TagEditor(tags: $draft.tags, input: $pendingTag, catalog: tagCatalog)
                .task {
                    guard tagCatalog == nil else { return }
                    tagCatalog = await TagCatalogBuilder.build(container: context.container)
                }
                .id(Self.tagSectionID)
        }
    }

    private static let tagSectionID = "tags"

    /// 기록 사진 (9판 · FR-058) — 최대 4장. 줄 하나에 단추 하나(사람 사진 칸과 같은 까닭 · 빌드 29).
    private var photoSection: some View {
        Section {
            if !draft.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(draft.photos) { photo in
                            // 사진을 누르면 맨 앞으로 · 빼기를 묻는다. 칩(`+ 이름`)과 같은 꾸밈 없는 단추라 양식 칸 안에서도 눌린다.
                            Button {
                                choosingPhoto = photo
                            } label: {
                                RecordPhotoTile(draft: photo, record: editingRecord, side: 76)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(draft.photos.first?.id == photo.id ? "대표 사진" : "사진")
                            .accessibilityHint("눌러서 맨 앞으로 옮기거나 뺍니다")
                            .overlay(alignment: .bottomLeading) {
                                // 첫 사진이 목록 줄의 작은 그림이다.
                                if draft.photos.first?.id == photo.id {
                                    Text("대표")
                                        .font(.scaled(11, weight: .semibold))
                                        .foregroundStyle(Color.ink)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.raised.opacity(0.9), in: Capsule())
                                        .padding(5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                // 역할 없는 단추 + 확인 창 — 확인 전에 빼지 않는다 (CLAUDE.md).
                                Button {
                                    removingPhoto = photo
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.scaled(20))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(Color.raised, Color.ink.opacity(0.7))
                                        .padding(4)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("사진 빼기")
                            }
                        }
                    }
                    // 가로 스크롤 칸은 위아래를 자른다 — 테두리 · 단추가 깎이지 않게 여백을 둔다 (이슈 63).
                    .padding(.vertical, 4)
                }
            }
            if PhotoCamera.isAvailable {
                Button {
                    Keyboard.dismiss()
                    PhotoCamera.shared.start(front: false) { data in
                        guard let data else { return }
                        Task { await ingestPhotoData([data]) }
                    }
                } label: {
                    Label("사진 찍기", systemImage: "camera")
                        .mutedWhenDisabled()
                }
                .disabled(!canAddPhoto)
            }
            Button {
                Keyboard.dismiss()
                pickingPhotos = true
            } label: {
                Label("사진첩에서 고르기", systemImage: "photo.on.rectangle")
                    .mutedWhenDisabled()
            }
            .disabled(!canAddPhoto)
            if draft.photos.count >= RecordPhotos.limit {
                Text("4장이 다 찼습니다. 사진을 빼면 더 넣을 수 있습니다.")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
            if processingPhotos {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("사진을 줄이는 중…").font(.scaled(14)).foregroundStyle(Color.muted)
                }
            }
        } header: {
            Text("사진 \(draft.photos.count)/\(RecordPhotos.limit)")
        } footer: {
            Text("한 기록에 4장까지 붙입니다. 대표(첫 사진)가 목록에 작게 보입니다 — 사진을 누르면 맨 앞으로 옮길 수 있습니다. 긴 변 1,024px 로 줄여 이 기기(동기화를 켜면 내 iCloud)에만 저장합니다.")
        }
    }

    private func moveToFront(_ photo: DraftPhoto) {
        guard let index = draft.photos.firstIndex(where: { $0.id == photo.id }), index > 0 else { return }
        draft.photos.insert(draft.photos.remove(at: index), at: 0)
    }

    private func ingestPhotos(_ items: [PhotosPickerItem]) async {
        processingPhotos = true
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) { loaded.append(data) } else { photoFailed = true }
        }
        processingPhotos = false
        await ingestPhotoData(loaded)
    }

    /// 줄여서 넣는다 — 4장이 차면 나머지는 버린다. 줄이지 못한 사진이 있으면 알린다.
    private func ingestPhotoData(_ raw: [Data]) async {
        processingPhotos = true
        defer { processingPhotos = false }
        for data in raw {
            guard draft.photos.count < RecordPhotos.limit else { break }
            guard let photo = await RecordPhotos.normalized(from: data) else {
                photoFailed = true
                continue
            }
            draft.photos.append(DraftPhoto(data: photo))
        }
    }

    /// CI 스크린샷 (`-tagInput ㅁㅌ` · 빌드 27 이슈 34) — 태그 칸에 글자를 넣고 그 자리까지 내려 자동완성 칩을 찍는다.
    /// 빌드 27 은 칩 글자가 빠진 채 나갔다 — 자동완성이 뜬 화면이 스크린샷에 없었다.
    private func showTagInputForScreenshot(_ proxy: ScrollViewProxy) async {
        guard let input = LaunchArguments.current.tagInput else { return }
        try? await Task.sleep(for: .milliseconds(600))
        proxy.scrollTo(Self.tagSectionID, anchor: .center)
        try? await Task.sleep(for: .milliseconds(400))
        pendingTag = input
    }

    /// 최근 함께한 사람 중 아직 고르지 않은 사람 — 누르면 함께한 사람에 들어간다 (빌드 16 · 조사 보고서 지금 7).
    @ViewBuilder
    private var recentChips: some View {
        let shown = recentPeople.filter { person in !draft.participants.contains { $0 === person } }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("최근 함께한 사람 — 누르면 넣습니다")
                    .font(.scaled(12))
                    .foregroundStyle(Color.muted)
                WrapLayout(spacing: 8) {
                    ForEach(shown) { person in
                        Button {
                            draft.participants.append(person)
                        } label: {
                            Chip(text: "+ \(person.name)", selected: false)
                                .tapTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(person.name) 넣기")
                    }
                }
            }
        }
    }

    /// 오늘까지의 최근 기록 40건에서 사람을 모은다 — 본문이 아니라 화면을 열 때 한 번 (CLAUDE.md).
    private func loadRecentPeople() {
        let todayNoon = DayNormalizer.noon(of: Date(), calendar: .current)
        var descriptor = FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.occurredAt <= todayNoon },
                                                 sortBy: [SortDescriptor(\Record.occurredAt, order: .reverse)])
        descriptor.fetchLimit = 40
        let recent = (try? context.fetch(descriptor)) ?? []
        let entries = recent.map { record in
            RecentCompanions.Entry(occurredAt: record.occurredAt, createdAt: record.createdAt,
                                   participants: (record.participants ?? []).filter { !$0.isMe && !$0.isGone }.map {
                                       RecentCompanions.Participant(id: $0.uuid, name: $0.name)
                                   })
        }
        let ids = RecentCompanions.pick(entries, excluding: Set(anchor.map { [$0.uuid] } ?? []))
        var byID: [UUID: Person] = [:]
        for person in candidates { byID[person.uuid] = person }
        recentPeople = ids.compactMap { byID[$0] }
    }

    private var participantSummary: String {
        let names = draft.participants.map(\.name)
        switch names.count {
        case 0: return "선택하세요"
        case 1: return names[0]
        case 2: return names.joined(separator: ", ")
        default: return "\(names[0]), \(names[1]) 외 \(names.count - 2)명"
        }
    }

    private func save() {
        // 태그 칸에 치다 만 글자도 넣는다 — 저장할 때 버려지지 않게 (이슈 19).
        draft.tags = TagEditor.merged(draft.tags, pending: pendingTag)
        pendingTag = ""
        do {
            let record: Record
            switch mode {
            case .create:
                record = try store.create(draft)
                RecordMemory.remember(type: draft.recordType, location: draft.location)
            case .edit(let existing):
                try store.apply(draft, to: existing)
                record = existing
            }
            dismiss()
            onSaved(record)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// 기록 쓰기가 기억하는 것 (빌드 16 · 조사 보고서 지금 7) — 마지막 기록 유형과 장소. 이 기기에만 둔다.
enum RecordMemory {
    private static let typeKey = "lastRecordType"
    private static let locationKey = "lastRecordLocation"

    /// 아는 유형일 때만 — 없어진 키로 시작하지 않게.
    static var lastType: String? {
        guard let key = UserDefaults.standard.string(forKey: typeKey),
              RecordType.all.contains(where: { $0.key == key }) else { return nil }
        return key
    }

    static var lastLocation: String? {
        TextNormalization.nilIfEmpty(UserDefaults.standard.string(forKey: locationKey) ?? "")
    }

    @MainActor
    static func remember(type: String, location: String) {
        // 견본 둘러보기 중에 쓴 유형 · 장소는 내 다음 기록에 남기지 않는다 (D-55).
        if DemoMode.shared.isActive { return }
        UserDefaults.standard.set(type, forKey: typeKey)
        // 장소를 비운 기록은 지난 장소를 지우지 않는다 — 어제의 장소가 다음에도 쓸모 있다.
        if let place = TextNormalization.nilIfEmpty(location) {
            UserDefaults.standard.set(place, forKey: locationKey)
        }
    }
}

/// 틀 이름 묻기 · 저장했다는 알림 — 양식 줄 안이 아니라 화면에 붙인다(이슈 72 교훈).
private struct TemplateNaming: ViewModifier {
    @Binding var naming: Bool
    @Binding var name: String
    @Binding var saved: Bool
    let onSave: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("틀 이름", isPresented: $naming) {
                TextField("예: 주간 1:1", text: $name)
                Button("저장", action: onSave)
                Button("취소", role: .cancel) {}
            } message: {
                Text("유형 · 제목 · 장소 · 태그 · 함께한 사람을 틀로 둡니다. 날짜 · 메모 · 사진은 넣지 않습니다.")
            }
            .alert("틀로 저장했습니다", isPresented: $saved) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("새 기록을 적을 때 맨 위 틀에서 고르세요.")
            }
    }
}
