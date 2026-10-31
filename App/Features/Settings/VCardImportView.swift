import Core
import SwiftData
import SwiftUI

/// **vCard 가져오기 미리보기** (빌드 18 · D-41) — 넣기 전에 새 사람 · 같은 사람 후보 · 이미 있는 사람을 나눠 보인다.
///
/// 새 사람은 넣기로, 같은 사람 후보는 빼기로 시작한다 — 섞이면 되돌리기 어렵다. 이미 있는 사람은 넣지 않는다.
/// 저장은 `PersonStore.createMany` 한 번 — 하나라도 실패하면 아무것도 들어가지 않는다.
struct VCardImportView: View {
    let items: [VCardTransfer.Item]
    let onDone: (Int) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<Int> = []
    @State private var errorMessage: String?

    init(items: [VCardTransfer.Item], onDone: @escaping (Int) -> Void) {
        self.items = items
        self.onDone = onDone
        _chosen = State(initialValue: Set(items.filter { $0.verdict == .new }.map(\.id)))
    }

    private var newItems: [VCardTransfer.Item] { items.filter { $0.verdict == .new } }
    private var possibleItems: [VCardTransfer.Item] { items.filter { $0.verdict == .possibleSame } }
    private var duplicateItems: [VCardTransfer.Item] { items.filter { $0.verdict == .duplicate } }

    var body: some View {
        NavigationStack {
            List {
                if !newItems.isEmpty {
                    Section {
                        ForEach(newItems) { item in toggleRow(item, note: nil) }
                    } header: {
                        Text("새 사람 \(newItems.count)명")
                    }
                }
                if !possibleItems.isEmpty {
                    Section {
                        ForEach(possibleItems) { item in
                            toggleRow(item, note: item.existingName.map { "이미 있는 \($0) 님과 이름이나 번호 · 메일이 겹칩니다" })
                        }
                    } header: {
                        Text("같은 사람 후보 \(possibleItems.count)명")
                    } footer: {
                        Text("같은 사람일 수 있어 빼 두었습니다. 다른 사람이면 켜서 새로 넣으세요.")
                    }
                }
                if !duplicateItems.isEmpty {
                    Section {
                        ForEach(duplicateItems) { item in
                            row(item, note: "이미 있습니다 — 넣지 않습니다")
                                .foregroundStyle(Color.muted)
                        }
                    } header: {
                        Text("이미 있는 사람 \(duplicateItems.count)명")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("vCard 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(chosen.count)명 넣기", action: save)
                        .disabled(chosen.isEmpty)
                }
            }
            .alert("넣지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func toggleRow(_ item: VCardTransfer.Item, note: String?) -> some View {
        Button {
            if chosen.contains(item.id) { chosen.remove(item.id) } else { chosen.insert(item.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: chosen.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.scaled(20))
                    .foregroundStyle(chosen.contains(item.id) ? Color.accent : Color.muted)
                row(item, note: note)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen.contains(item.id) ? .isSelected : [])
    }

    private func row(_ item: VCardTransfer.Item, note: String?) -> some View {
        let person = item.person
        let detail = [[person.organization, person.role].filter { !$0.isEmpty }.joined(separator: " · "),
                      person.fields.mobile.isEmpty ? person.fields.email : person.fields.mobile]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 3) {
            Text(person.name).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink)
            if !detail.isEmpty {
                Text(detail).font(.scaled(13)).foregroundStyle(Color.muted).readableLineLimit(1)
            }
            if let note {
                Text(note).font(.scaled(12)).foregroundStyle(Color.muted)
            }
        }
    }

    private func save() {
        let drafts = items.filter { chosen.contains($0.id) && $0.verdict != .duplicate }.map { VCardTransfer.draft($0.person) }
        do {
            try PersonStore(context: context).createMany(drafts)
            dismiss()
            onDone(drafts.count)
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}
