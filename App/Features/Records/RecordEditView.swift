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
    @Query private var everyone: [Person]

    @State private var draft: RecordDraft
    @State private var original: RecordDraft
    @State private var confirmingDiscard = false
    @State private var saveError: String?

    init(mode: Mode, onSaved: @escaping (Record) -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        let draft: RecordDraft
        switch mode {
        case .create(let anchor): draft = RecordDraft(anchor: anchor)
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

    private var candidates: [Person] {
        everyone.sorted {
            NameSort.areInIncreasingOrder((name: $0.name, createdAt: $0.createdAt),
                                          (name: $1.name, createdAt: $1.createdAt))
        }
    }

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
                }
                Section("태그") {
                    TagEditor(tags: $draft.tags)
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
        do {
            let record: Record
            switch mode {
            case .create:
                record = try store.create(draft)
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
