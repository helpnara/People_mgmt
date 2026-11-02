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
    /// 삭제 확인 문구 — 단추를 누를 때 만든다 (이슈 19).
    @State private var deleteMessage = ""
    @State private var errorMessage: String?
    @State private var errorTitle = "삭제하지 못했습니다"
    /// 예정이던 만남을 안 만났을 때 — 날짜 바꾸기 · 기록 지우기 (D-62).
    @State private var confirmingNoShow = false
    /// 크게 볼 사진 (9판 · FR-058).
    @State private var viewingPhoto: RecordPhoto?

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
            // 예정된 만남 (D-62) — 날이 왔는데 결과를 적지 않았으면 띠, 아직 오지 않았으면 한 줄.
            if record.isAwaitingResult {
                Section { awaitingBanner }
            } else if record.isUpcoming {
                Section {
                    Label("예정된 만남 · \(record.upcomingPhrase)", systemImage: "calendar")
                        .font(.scaled(15, weight: .medium))
                        .foregroundStyle(Color.accent)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: record.type.symbol).foregroundStyle(Color.accent)
                        Text(record.type.label).foregroundStyle(Color.accent)
                        Text("·").foregroundStyle(Color.faint)
                        Text(record.whenText(style: .long)).foregroundStyle(Color.muted)
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
            photoSection
            Section("함께한 사람") {
                ForEach(record.participants ?? []) { person in
                    NavigationLink(value: person) {
                        PersonRow(person: person, evidence: nil)
                    }
                    .accessibilityIdentifier("recordParticipantRow")
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
                    .foregroundStyle(Color.muted)
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
                        deleteMessage = record.deletionMessage(viewer: nil)
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
        .fullScreenCover(item: $viewingPhoto) { photo in
            RecordPhotoViewer(photos: record.isGone ? [] : record.sortedPhotos, selection: photo.uuid)
        }
        .confirmationDialog("삭제", isPresented: $confirmingDelete, titleVisibility: .hidden) {
            Button("삭제", role: .destructive) { deleteRecord() }
            Button("취소", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .confirmationDialog("안 만난 약속", isPresented: $confirmingNoShow, titleVisibility: .visible) {
            Button("날짜 바꾸기") { editing = true }
            Button("기록 지우기", role: .destructive) {
                deleteMessage = record.deletionMessage(viewer: nil)
                // 이 창이 내려간 뒤에 삭제 확인을 띄운다 — 내려가는 중에 띄우면 묻힌다.
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    confirmingDelete = true
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("날짜를 바꿔 다시 예정으로 두거나, 기록을 지울 수 있습니다.")
        }
        .alert(errorTitle, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// 기록 사진 (9판 · FR-058) — 두 줄 격자, 누르면 크게. 사진이 없으면 칸이 없다.
    @ViewBuilder
    private var photoSection: some View {
        let photos = record.sortedPhotos
        if !photos.isEmpty {
            Section("사진") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(photos, id: \.uuid) { photo in
                        Button {
                            viewingPhoto = photo
                        } label: {
                            RecordPhotoTile(draft: DraftPhoto(existing: photo), record: record, fills: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("사진 크게 보기")
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    /// 결과를 적을 만남의 띠 (D-62) — 결과 적기(편집) · 그대로 만났어요 · 안 만났어요.
    /// 한 줄에 단추가 여럿이라 저마다 테두리 모양을 준다 — 꾸밈 없는 단추는 줄 전체를 눌러 모두 실행된다.
    private var awaitingBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("예정이던 만남입니다", systemImage: "calendar.badge.clock")
                .font(.scaled(16, weight: .semibold))
                .foregroundStyle(Color.accent)
            Text("만난 결과를 메모 · 함께한 사람 · 장소에 적어 두세요. 고칠 것이 없으면 그대로 만났어요를 누르면 됩니다.")
                .font(.scaled(14))
                .foregroundStyle(Color.bodyText)
            HStack(spacing: 10) {
                Button {
                    editing = true
                } label: {
                    Text("결과 적기").font(.scaled(15, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .accessibilityIdentifier("plannedWriteResult")
                Button {
                    confirmMet()
                } label: {
                    Text("그대로 만났어요").font(.scaled(15, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(Color.accent)
                .accessibilityIdentifier("plannedMet")
            }
            Button {
                confirmingNoShow = true
            } label: {
                Text("안 만났어요").font(.scaled(14))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.muted)
            .accessibilityIdentifier("plannedNoShow")
        }
        .padding(.vertical, 6)
    }

    private func confirmMet() {
        do {
            try RecordStore(context: context).confirmMet(record)
        } catch {
            errorTitle = "저장하지 못했습니다"
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }

    private func deleteRecord() {
        do {
            try DeletionUndo.shared.delete(record, in: context)
            dismiss()
        } catch {
            errorTitle = "삭제하지 못했습니다"
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}
