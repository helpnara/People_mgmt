import Core
import SwiftData
import SwiftUI

/// **선택지 고치기** (FR-035 · 9판 · D-66 · 2026-11-03 사용자) — 관계 유형 · 알게 된 경로의 선택지를 더하고, 끌어 차례를 바꾸고, 숨긴다.
///
/// - 바꾸는 즉시 저장한다(`상세 화면 칸` 과 같은 손맛). 내 iCloud 로 아이폰 · 아이패드가 같다(`ChoiceList`).
/// - 사람에게 이미 적힌 값은 그대로다 — 숨겨도 그 사람의 칸은 지워지지 않는다(수정 화면에서 직접 입력 칸에 보인다).
/// - 알게 된 경로의 `소개` 는 숨길 수 없다(소개한 사람 칸이 여기에 달려 있다 · FR-043).
/// - 셈은 `Core.ChoiceEditing`, 저장은 `ChoiceStore` 하나다.
struct ChoiceEditorView: View {
    let kind: ChoiceKind

    @Environment(\.modelContext) private var context
    @State private var items: [String] = []
    @State private var hiddenItems: [String] = []
    @State private var newValue = ""
    @State private var loaded = false
    @State private var confirmingReset = false
    @State private var failure: String?

    /// 보이는 선택지의 최대 수 — 칩이 화면을 덮지 않게.
    static let limit = 40

    private var maxLength: Int {
        kind == .relationshipType ? Limits.relationshipType : Limits.metThrough
    }

    private var canAdd: Bool {
        let value = TextNormalization.normalized(newValue)
        return !value.isEmpty && !items.contains(value) && items.count < Self.limit
    }

    /// 더하기 칸 아래 한 줄 — 왜 더할 수 없는지, 더하면 무엇이 되는지.
    private var addHint: String? {
        let value = TextNormalization.normalized(newValue)
        guard !value.isEmpty else { return nil }
        if items.contains(value) { return "이미 보이는 선택지입니다." }
        if hiddenItems.contains(value) { return "숨긴 선택지입니다. 더하면 다시 보입니다." }
        if items.count >= Self.limit { return "선택지는 \(Self.limit)개까지 둡니다. 하나를 숨기면 더할 수 있습니다." }
        return nil
    }

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 12) {
                        Text(item)
                            .font(.scaled(16))
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 8)
                        if kind.fixed.contains(item) {
                            Text("늘 보임")
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                        } else {
                            Button {
                                apply(ChoiceEditing.hiding(item, in: items, hidden: hiddenItems, fixed: kind.fixed))
                            } label: {
                                Label("숨기기", systemImage: "eye.slash")
                                    .labelStyle(.iconOnly)
                                    .font(.scaled(16))
                                    .foregroundStyle(Color.muted)
                                    .tapTarget()
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(item) 숨기기")
                        }
                    }
                }
                .onMove { source, destination in
                    var moved = items
                    moved.move(fromOffsets: source, toOffset: destination)
                    apply((moved, hiddenItems))
                }
                HStack(spacing: 12) {
                    TextField("새 선택지", text: $newValue)
                        .font(.scaled(16))
                        .limited($newValue, to: maxLength)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("더하기", action: add)
                        .buttonStyle(.borderless)
                        .disabled(!canAdd)
                }
                if let addHint {
                    Text(addHint)
                        .font(.scaled(13))
                        .foregroundStyle(Color.muted)
                }
            } header: {
                Text("보이는 선택지")
            } footer: {
                FootnoteText("오른쪽 손잡이를 끌어 차례를 바꾸고, 눈 단추로 숨깁니다. 사람 수정 화면의 \(kind.title) 칩이 이 차례로 나옵니다. 숨겨도 이미 적어 둔 사람의 값은 지워지지 않습니다.")
            }

            if !hiddenItems.isEmpty {
                Section {
                    ForEach(hiddenItems, id: \.self) { item in
                        HStack(spacing: 12) {
                            Text(item)
                                .font(.scaled(16))
                                .foregroundStyle(Color.muted)
                            Spacer(minLength: 8)
                            Button("다시 보이기") {
                                apply(ChoiceEditing.showing(item, in: items, hidden: hiddenItems))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("숨긴 선택지")
                }
            }

            Section {
                Button("처음 선택지로") { confirmingReset = true }
            } footer: {
                Text("내 iCloud 로 같은 Apple 계정의 아이폰 · 아이패드에 함께 적용됩니다.")
            }
        }
        // 손잡이가 늘 보이게 — 편집 단추를 따로 누르지 않는다. 지우기 단추는 없다(`onDelete` 를 두지 않음).
        .environment(\.editMode, .constant(.active))
        .listStyle(.insetGrouped)
        // 키보드가 가린 만큼 끝에 여백 — 키보드가 올라와도 마지막 칸까지 내려간다 (이슈 80).
        .keyboardScrollRoom()
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("\(kind.title) 선택지")
        // 이름을 적는 창이 뜨는 화면 — 열린 동안 아이패드 화면 나누기로 폭이 바뀌어도 뼈대를 그대로 (이슈 77).
        .holdsLayout()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            loaded = true
            load()
        }
        .confirmationDialog("처음 선택지로 돌릴까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("처음 선택지로") { reset() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("더한 선택지 · 바꾼 차례 · 숨긴 것을 모두 처음대로 돌립니다. 사람에게 적어 둔 값은 그대로입니다.")
        }
        .alert("저장하지 못했습니다", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    /// 화면을 열 때 한 번 — 내가 정한 것 + 사람들에게 직접 입력해 쓴 값.
    private func load() {
        let people = (try? PersonStore(context: context).allPeople()) ?? []
        let used = people.compactMap { kind == .relationshipType ? $0.relationshipType : $0.metThrough }
        let setting = ChoiceStore.setting(kind, in: context)
        items = ChoiceEditing.choices(kind, setting: setting, used: used)
        hiddenItems = ChoiceEditing.hidden(fixed: kind.fixed, setting: setting)
    }

    private func add() {
        guard canAdd else { return }
        apply(ChoiceEditing.adding(newValue, to: items, hidden: hiddenItems))
        newValue = ""
    }

    /// 바꾼 것을 곧바로 저장한다. 실패하면 저장된 것으로 다시 읽는다.
    private func apply(_ change: (items: [String], hidden: [String])) {
        guard change.items != items || change.hidden != hiddenItems else { return }
        items = change.items
        hiddenItems = change.hidden
        do {
            try ChoiceStore.save(kind, items: items, hidden: hiddenItems, in: context)
        } catch {
            failure = error.localizedDescription
            load()
        }
    }

    private func reset() {
        do {
            try ChoiceStore.reset(kind, in: context)
        } catch {
            failure = error.localizedDescription
        }
        load()
    }
}
