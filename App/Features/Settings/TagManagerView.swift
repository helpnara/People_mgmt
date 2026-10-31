import Core
import SwiftData
import SwiftUI

/// **태그 관리** (FR-026) — 앱에 있는 태그와 쓰인 수. 누르면 이름을 바꾸고, 이미 있는 태그 이름을 적으면 확인한 뒤 합친다.
/// 바꾸기는 `TagStore` 하나로, 규칙은 `Core.TagCatalog.renamed` 하나로.
struct TagManagerView: View {
    @Environment(\.modelContext) private var context

    /// 합칠 두 태그 — 확인 창이 든다.
    private struct MergePlan {
        let from: TagCatalog.Entry
        let into: TagCatalog.Entry
    }

    @State private var catalog: TagCatalog?
    /// 바꿀 때마다 하나씩 오른다 — 모음을 다시 만든다.
    @State private var version = 0
    @State private var editing: TagCatalog.Entry?
    @State private var newName = ""
    @State private var pendingMerge: MergePlan?
    @State private var message: String?

    var body: some View {
        Group {
            if let catalog {
                if catalog.entries.isEmpty {
                    ContentUnavailableView("태그가 없습니다", systemImage: "number",
                                           description: Text("사람이나 기록에 태그를 붙이면 여기에 모입니다."))
                } else {
                    list(catalog)
                }
            } else {
                ProgressView()
            }
        }
        .background(Color.ground)
        .navigationTitle("태그 관리")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: version) {
            catalog = await TagCatalogBuilder.build(container: context.container)
        }
        .alert("태그 이름 바꾸기", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }),
               presenting: editing) { entry in
            TextField("새 이름", text: $newName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("바꾸기") { submit(entry) }
            Button("취소", role: .cancel) {}
        } message: { entry in
            Text("#\(entry.tag) — 사람 \(entry.people)명 · 기록 \(entry.records)건. 이미 있는 태그 이름을 적으면 두 태그를 하나로 합칩니다.")
        }
        .confirmationDialog("태그 합치기", isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } }),
                            titleVisibility: .visible, presenting: pendingMerge) { plan in
            Button("합치기", role: .destructive) { apply(plan.from.tag, to: plan.into.tag) }
            Button("취소", role: .cancel) {}
        } message: { plan in
            Text("#\(plan.from.tag) 태그(사람 \(plan.from.people)명 · 기록 \(plan.from.records)건)를 #\(plan.into.tag) 태그로 합칩니다. 합친 뒤에는 따로 되돌릴 수 없습니다.")
        }
        .alert("태그", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func list(_ catalog: TagCatalog) -> some View {
        List {
            Section {
                ForEach(catalog.entries) { entry in
                    Button {
                        newName = entry.tag
                        editing = entry
                    } label: {
                        HStack {
                            Text("#\(entry.tag)")
                                .font(.scaled(16))
                                .foregroundStyle(Color.ink)
                            Spacer(minLength: 8)
                            Text(countText(entry))
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("이름을 바꾸거나 다른 태그와 합칩니다")
                }
            } header: {
                Text("태그 \(catalog.entries.count)개 · 많이 쓴 순")
            } footer: {
                Text("태그를 누르면 이름을 바꿉니다. 이미 있는 태그 이름을 적으면 두 태그를 하나로 합칩니다. 사람과 기록에 붙은 태그가 함께 바뀝니다.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func countText(_ entry: TagCatalog.Entry) -> String {
        var parts: [String] = []
        if entry.people > 0 { parts.append("사람 \(entry.people)") }
        if entry.records > 0 { parts.append("기록 \(entry.records)") }
        return parts.joined(separator: " · ")
    }

    private func submit(_ entry: TagCatalog.Entry) {
        guard let target = TagNormalizer.normalize(newName) else {
            show("태그 이름은 1~\(TagNormalizer.maxLength)자로 적어 주세요.")
            return
        }
        guard target != entry.tag else { return }
        if let existing = catalog?.entry(for: target), existing.id != entry.id {
            // 알림 창이 닫히는 동안 다음 창을 띄우면 뜨지 않는다 — 잠깐 쉬었다가.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                pendingMerge = MergePlan(from: entry, into: existing)
            }
            return
        }
        apply(entry.tag, to: target)
    }

    private func apply(_ from: String, to: String) {
        do {
            try TagStore(context: context).rename(from, to: to)
            version += 1
        } catch {
            show("\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요.")
        }
    }

    private func show(_ text: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            message = text
        }
    }
}
