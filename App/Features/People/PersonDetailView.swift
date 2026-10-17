import Core
import SwiftData
import SwiftUI

/// 사람 상세 (요구사항 4.2.3) — 그 사람과의 인연을 이해하는 중심 화면.
struct PersonDetailView: View {
    let person: Person

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var store: PersonStore { PersonStore(context: context) }

    var body: some View {
        Group {
            // 지워진 객체를 다시 그리지 않는다 (CLAUDE.md · 느린 부자 189번).
            if person.isGone {
                ContentUnavailableView("삭제된 사람입니다", systemImage: "person.slash")
            } else {
                content
            }
        }
    }

    private var content: some View {
        List {
            headerSection
            firstEncounterSection
            if let introduced = person.introduced, !introduced.isEmpty {
                introducedSection(introduced)
            }
            timelineSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle(person.name)
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
            PersonEditView(mode: .edit(person)) { _ in }
        }
        .confirmationDialog("삭제", isPresented: $confirmingDelete, titleVisibility: .hidden) {
            Button("삭제", role: .destructive) { deletePerson() }
            Button("취소", role: .cancel) {}
        } message: {
            Text(store.deletionMessage(for: person))
        }
        .alert("삭제하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: 구역

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(person.name)
                    .font(.scaled(26, weight: .bold))
                    .foregroundStyle(Color.ink)
                if let nickname = person.nickname, !nickname.isEmpty {
                    Text(nickname).font(.scaled(15)).foregroundStyle(Color.muted)
                }
                if let subtitle = person.subtitle, subtitle != person.relationshipType {
                    Text(subtitle).font(.scaled(16)).foregroundStyle(Color.bodyText)
                }
                WrapLayout(spacing: 8) {
                    if let type = person.relationshipType, !type.isEmpty {
                        Chip(text: type, selected: true)
                    }
                    if let path = person.metThrough, !path.isEmpty {
                        Chip(text: path)
                    }
                    ForEach(person.tags, id: \.self) { tag in
                        Chip(text: "#\(tag)")
                    }
                }
                if let introducer = person.introducedBy, !introducer.isGone {
                    NavigationLink(value: introducer) {
                        Label("\(introducer.name)의 소개로", systemImage: "arrow.turn.down.right")
                            .font(.scaled(15))
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var firstEncounterSection: some View {
        Section("첫 인연") {
            if person.hasFirstEncounter {
                VStack(alignment: .leading, spacing: 6) {
                    Text(firstMetText)
                        .font(.scaled(14, weight: .medium))
                        .foregroundStyle(Color.muted)
                    if let note = person.firstNote, !note.isEmpty {
                        Text(note)
                            .font(.scaled(16))
                            .foregroundStyle(Color.bodyText)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    editing = true
                } label: {
                    Label("첫 인연을 기록해 보세요 — 어떤 계기로 알게 되었나요?", systemImage: "sparkles")
                        .font(.scaled(15))
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    private func introducedSection(_ introduced: [Person]) -> some View {
        Section("소개한 인연 \(introduced.count)명") {
            ForEach(introduced.sorted {
                NameSort.areInIncreasingOrder((name: $0.name, createdAt: $0.createdAt),
                                              (name: $1.name, createdAt: $1.createdAt))
            }) { other in
                NavigationLink(value: other) {
                    PersonRow(person: other, evidence: nil)
                }
            }
        }
    }

    /// 타임라인 (4.2.3). 기록 추가 · 상세는 3단계에서 들어온다 — 지금은 시작점과 빈 상태만 그린다.
    private var timelineSection: some View {
        Section("타임라인") {
            if (person.records ?? []).isEmpty {
                Text("아직 기록이 없습니다. 함께한 일을 남겨 보세요.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            } else {
                Text("기록 \(person.records?.count ?? 0)건 — 타임라인은 3단계에서 보입니다.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            }
            if person.hasFirstEncounter {
                Button {
                    editing = true
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "flag")
                            .font(.scaled(15))
                            .foregroundStyle(Color.accent)
                            .frame(width: Font.scaledLength(22))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(firstMetText)
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                            Text("시작점 — 처음 만남")
                                .font(.scaled(16, weight: .medium))
                                .foregroundStyle(Color.ink)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var firstMetText: String {
        if let date = person.firstMetDate {
            return date.formatted(date: .long, time: .omitted)
        }
        return "날짜 미상"
    }

    private func deletePerson() {
        do {
            try store.delete(person)
            dismiss()
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}
