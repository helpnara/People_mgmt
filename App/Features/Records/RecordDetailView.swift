import Core
import SwiftData
import SwiftUI

/// 기록 상세 (요구사항 4.2.5). 긴 메모를 끊김 없이 읽는 곳.
struct RecordDetailView: View {
    let record: Record

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if record.isGone {
                ContentUnavailableView("삭제된 기록입니다", systemImage: "doc.text.magnifyingglass")
            } else {
                content
            }
        }
    }

    private var content: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: record.type.symbol).foregroundStyle(Color.accent)
                        Text(record.type.label).foregroundStyle(Color.accent)
                        Text("·").foregroundStyle(Color.faint)
                        Text(record.occurredAt.formatted(date: .long, time: .omitted)).foregroundStyle(Color.muted)
                    }
                    .font(.scaled(14, weight: .medium))
                    Text(record.displayTitle)
                        .font(.scaled(22, weight: .bold))
                        .foregroundStyle(Color.ink)
                    if let location = record.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.scaled(15))
                            .foregroundStyle(Color.bodyText)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("함께한 사람") {
                ForEach(record.participants ?? []) { person in
                    NavigationLink(value: person) {
                        PersonRow(person: person, evidence: nil)
                    }
                }
            }
            if let note = record.note, !note.isEmpty {
                Section("메모") {
                    Text(note)
                        .font(.scaled(16))
                        .foregroundStyle(Color.bodyText)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            }
            if !record.tags.isEmpty {
                Section("태그") {
                    WrapLayout(spacing: 8) {
                        ForEach(record.tags, id: \.self) { Chip(text: "#\($0)") }
                    }
                }
            }
            Section {
                Text("만든 날 \(record.createdAt.formatted(date: .abbreviated, time: .shortened)) · 고친 날 \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.scaled(12))
                    .foregroundStyle(Color.faint)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(record.type.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editing = true
                    } label: {
                        Label("편집", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Label("더보기", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) {
            RecordEditView(mode: .edit(record)) { _ in }
        }
        .confirmationDialog("삭제", isPresented: $confirmingDelete, titleVisibility: .hidden) {
            Button("삭제", role: .destructive) { deleteRecord() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(record.displayTitle)' 기록을 삭제하시겠습니까? 되돌릴 수 없습니다.")
        }
        .alert("삭제하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteRecord() {
        do {
            try RecordStore(context: context).delete(record)
            dismiss()
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}
