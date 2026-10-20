import Core
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
    /// 지난 기록의 장소 — 눌러야 들어간다 (빌드 16). 저절로 채우면 틀린 장소가 저장되기 쉽다.
    private let lastLocation = RecordMemory.lastLocation

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
    private var hasChanges: Bool { draft != original }
    private var store: RecordStore { RecordStore(context: context) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("날짜", selection: $draft.occurredAt, displayedComponents: .date)
                } footer: {
                    Text("기본은 오늘입니다. 예정된 만남은 앞날짜로 적어도 됩니다.")
                }
                Section("기록 유형") {
                    RecordTypeChips(selection: $draft.recordType)
                }
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
                Section("태그") {
                    TagEditor(tags: $draft.tags, input: $pendingTag, catalog: tagCatalog)
                        .task {
                            guard tagCatalog == nil else { return }
                            tagCatalog = await TagCatalogBuilder.build(container: context.container)
                        }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
        .onAppear {
            if isCreate { titleFocused = true }
        }
        .task(id: everyone.count) {
            candidates = PersonStore.sorted(everyone.filter { !$0.isGone }, by: .name)
            loadRecentPeople()
        }
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

    static func remember(type: String, location: String) {
        UserDefaults.standard.set(type, forKey: typeKey)
        // 장소를 비운 기록은 지난 장소를 지우지 않는다 — 어제의 장소가 다음에도 쓸모 있다.
        if let place = TextNormalization.nilIfEmpty(location) {
            UserDefaults.standard.set(place, forKey: locationKey)
        }
    }
}
