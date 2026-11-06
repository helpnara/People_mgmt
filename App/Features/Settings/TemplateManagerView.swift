import Core
import SwiftData
import SwiftUI

/// **설정 → 기록 틀** (12판 · 이슈 95 · FR-070 · D-79) — 이름 바꾸기 · 빼기(확인). 틀은 기록 수정의 `이 기록을 틀로 저장` 으로 만든다.
struct TemplateManagerView: View {
    @Environment(\.modelContext) private var context
    @State private var templates: [RecordTemplate] = []
    @State private var renaming: RecordTemplate?
    @State private var newName = ""
    @State private var removing: RecordTemplate?
    @State private var errorMessage: String?

    private var store: TemplateStore { TemplateStore(context: context) }

    var body: some View {
        List {
            if templates.isEmpty {
                Text("아직 틀이 없습니다. 기록을 적거나 고칠 때 맨 아래 이 기록을 틀로 저장을 누르면 여기에 생깁니다.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            }
            Section {
                ForEach(templates) { template in
                    if !template.isGone {
                        Button {
                            newName = template.name
                            renaming = template
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name)
                                    .font(.scaled(16, weight: .medium))
                                    .foregroundStyle(Color.ink)
                                Text(summary(template))
                                    .font(.scaled(13))
                                    .foregroundStyle(Color.muted)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // 역할 없는 단추 — 확인 전에 줄을 접지 않게 (느린 부자 178~182).
                            Button {
                                removing = template
                            } label: {
                                Label("빼기", systemImage: "trash")
                            }
                            .tint(Color.danger)
                        }
                    }
                }
            } footer: {
                if !templates.isEmpty {
                    Text("누르면 이름을 바꾸고, 왼쪽으로 밀면 뺍니다. 틀을 빼도 이미 적은 기록은 그대로입니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("기록 틀")
        .navigationBarTitleDisplayMode(.inline)
        .task { templates = store.templates() }
        .alert("틀 이름 바꾸기", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("이름", text: $newName)
            Button("저장") {
                if let template = renaming { perform { try store.rename(template, to: newName) } }
                renaming = nil
            }
            Button("취소", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("이 틀을 뺄까요?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { template in
            Button("빼기", role: .destructive) {
                perform { try store.delete(template) }
                removing = nil
            }
            Button("취소", role: .cancel) { removing = nil }
        } message: { template in
            Text(template.isGone ? "" : "\(template.name) — 이미 적은 기록은 그대로입니다.")
        }
        .alert("저장하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
        templates = store.templates()
    }

    /// `회의 · 분기 회의 · 본사 3층 · 함께 2명`.
    private func summary(_ template: RecordTemplate) -> String {
        var parts = [RecordType.named(template.recordType).label]
        if let title = template.title, !title.isEmpty { parts.append(title) }
        if let location = template.location, !location.isEmpty { parts.append(location) }
        if !template.participantIDs.isEmpty { parts.append("함께 \(template.participantIDs.count)명") }
        return parts.joined(separator: " · ")
    }
}
