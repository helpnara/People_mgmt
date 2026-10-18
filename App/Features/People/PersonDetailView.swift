import Core
import SwiftData
import SwiftUI

/// 사람 상세 (요구사항 4.2.3) — 그 사람과의 인연을 이해하는 중심 화면.
struct PersonDetailView: View {
    let person: Person

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var addingRecord = false
    @State private var confirmingDelete = false
    @State private var pendingRecordDelete: Record?
    @State private var errorMessage: String?
    @State private var appliedArguments = false
    @State private var viewingCard = false

    private var store: PersonStore { PersonStore(context: context) }
    private var timeline: [Record] { RecordStore.timeline(of: person) }

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
        ScrollViewReader { proxy in
        List {
            headerSection
            if let card = person.businessCard {
                Section("명함") {
                    Button {
                        viewingCard = true
                    } label: {
                        BusinessCardThumbnail(data: card, maxHeight: 160)
                    }
                    .buttonStyle(.plain)
                }
            }
            // 나는 첫 인연 · 소개 · 기록이 없다 — 모든 기록에 나는 늘 있다 (이슈 12).
            if !person.isMe {
                firstEncounterSection
                RelationshipReviewSection(person: person)
                if let introduced = person.introduced, !introduced.isEmpty {
                    introducedSection(introduced)
                }
                timelineSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .task {
            // CI 스크린샷: 관계 돌아보기 구역까지 내린다.
            guard LaunchArguments.current.scrollToReview, !person.isMe else { return }
            try? await Task.sleep(for: .milliseconds(500))
            proxy.scrollTo(RelationshipReviewSection.anchor, anchor: .top)
        }
        }
        // 자주 쓰는 `기록 추가` 는 한 손이 닿는 아래에 — 키보드 툴바가 아니라 화면 안의 띠로 (CLAUDE.md).
        .safeAreaInset(edge: .bottom) {
            if !person.isMe {
            HStack {
                Spacer()
                Button {
                    addingRecord = true
                } label: {
                    Label("기록 추가", systemImage: "plus")
                        .font(.scaled(16, weight: .semibold))
                        .padding(.horizontal, Font.scaledLength(18))
                        .padding(.vertical, Font.scaledLength(12))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
            }
        }
        .navigationTitle(person.isMe ? "나" : person.name)
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
        .sheet(isPresented: $addingRecord) {
            RecordEditView(mode: .create(anchor: person)) { _ in }
        }
        .fullScreenCover(isPresented: $viewingCard) {
            if let card = person.businessCard { BusinessCardViewer(data: card) }
        }
        .confirmationDialog("삭제", isPresented: $confirmingDelete, titleVisibility: .hidden) {
            Button("삭제", role: .destructive) { deletePerson() }
            Button("취소", role: .cancel) {}
        } message: {
            Text(store.deletionMessage(for: person))
        }
        .confirmationDialog(
            "기록 삭제",
            isPresented: Binding(get: { pendingRecordDelete != nil }, set: { if !$0 { pendingRecordDelete = nil } }),
            titleVisibility: .hidden,
            presenting: pendingRecordDelete
        ) { record in
            Button("삭제", role: .destructive) { deleteRecord(record) }
            Button("취소", role: .cancel) { pendingRecordDelete = nil }
        } message: { record in
            Text("'\(record.displayTitle)' 기록을 삭제하시겠습니까? 되돌릴 수 없습니다.")
        }
        .alert("삭제하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            // CI 스크린샷: -addRecord 면 기록 추가 시트를 바로 연다 (한 번만).
            if !appliedArguments {
                appliedArguments = true
                if LaunchArguments.current.addRecord { addingRecord = true }
                if LaunchArguments.current.editPerson { editing = true }
                if LaunchArguments.current.viewCard, person.businessCard != nil { viewingCard = true }
            }
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
                ContactRows(person: person)
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

    /// 타임라인 (4.2.3). 최신순, 맨 아래에 첫 인연 시작점. 기록 행을 밀면 삭제(확인 뒤).
    private var timelineSection: some View {
        Section {
            if timeline.isEmpty {
                Text("아직 기록이 없습니다. 함께한 일을 남겨 보세요.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            }
            ForEach(timeline) { record in
                NavigationLink(value: record) {
                    TimelineRow(record: record, viewer: person)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        pendingRecordDelete = record
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .tint(Color.danger)
                }
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
                            .padding(.top, 2)
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
        } header: {
            Text(timeline.isEmpty ? "타임라인" : "타임라인 · 기록 \(timeline.count)건")
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

    private func deleteRecord(_ record: Record) {
        do {
            try RecordStore(context: context).delete(record)
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
        pendingRecordDelete = nil
    }
}
