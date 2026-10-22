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
    /// 기록 삭제 확인 문구 — 밀어서 `삭제` 를 누를 때 만든다. 확인 창이 닫히는 동안 지운 기록을 다시 읽지 않게 (이슈 19).
    @State private var pendingRecordDeleteMessage = ""
    @State private var errorMessage: String?
    @State private var appliedArguments = false
    @State private var viewingCard = false
    /// 타임라인 거르기 (FR-013) — 기록 유형(열쇠) · 태그. 둘 다 고르면 둘 다 맞는 기록.
    /// 내보내기 확인 (FR-014) — 개인정보가 담긴 파일임을 먼저 알린다.
    @State private var confirmingExport = false
    @State private var exportFailed = false
    @State private var timelineType: String?
    @State private var timelineTag: String?

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
                acquaintanceSection
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
                    Button {
                        confirmingExport = true
                    } label: {
                        Label("내보내기", systemImage: "square.and.arrow.up")
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
        .confirmationDialog("내보내기", isPresented: $confirmingExport, titleVisibility: .visible) {
            Button("Markdown 파일") { export(.markdown) }
            Button("PDF 파일") { export(.pdf) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(person.name) 님의 정보와 기록 \(RecordStore.timeline(of: person).count)건이 그대로 담긴 파일을 만듭니다. 이 파일은 앱 밖으로 나가면 보호되지 않습니다 — 믿을 수 있는 곳에만 보내세요.")
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
        } message: { _ in
            Text(pendingRecordDeleteMessage)
        }
        .alert("내보내지 못했습니다", isPresented: $exportFailed) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text("파일을 만들지 못했습니다. 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요.")
        }
        .alert("삭제하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            // CI 큰 견본: 목록에서 연 뒤 상세가 뜨기까지 (요구사항 8.5 · 기록 500건 0.5초).
            LaunchTiming.end("상세") { "상세 첫 표시 (기록 \(RecordStore.timeline(of: person).count)건)" }
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
                HStack(spacing: 14) {
                    // 사진 (FR-012) — 없으면 이름 첫 글자.
                    PersonAvatar(person: person, size: 60)
                    Text(person.name)
                        .font(.scaled(26, weight: .bold))
                        .foregroundStyle(Color.ink)
                }
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
                // 생일 · 연락 주기 (5판 · D-40) — 적은 사람만.
                if let month = person.birthMonth, let day = person.birthDay {
                    Label("생일 " + BirthdayRule.text(month: month, day: day, year: person.birthYear), systemImage: "gift")
                        .font(.scaled(15))
                        .foregroundStyle(Color.bodyText)
                }
                if let months = person.contactCadenceMonths, !person.isMe {
                    Label("연락 주기 \(months)개월", systemImage: "bell")
                        .font(.scaled(15))
                        .foregroundStyle(Color.bodyText)
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

    /// 아는 사이 (D-30). 없으면 그리지 않는다 — 편집에서 고른다.
    @ViewBuilder
    private var acquaintanceSection: some View {
        let known = person.acquaintances
        if !known.isEmpty {
            Section("아는 사이 \(known.count)명") {
                ForEach(NameSort.sorted(known, name: \.name, createdAt: \.createdAt)) { other in
                    NavigationLink(value: other) {
                        PersonRow(person: other, evidence: nil)
                    }
                }
            }
        }
    }

    private func introducedSection(_ introduced: [Person]) -> some View {
        Section("소개한 인연 \(introduced.count)명") {
            ForEach(NameSort.sorted(introduced, name: \.name, createdAt: \.createdAt)) { other in
                NavigationLink(value: other) {
                    PersonRow(person: other, evidence: nil)
                }
            }
        }
    }

    /// 타임라인 (4.2.3). 최신순, 맨 아래에 첫 인연 시작점. 기록 행을 밀면 삭제(확인 뒤).
    /// 정렬은 한 번 그릴 때 한 번 (빌드 11 까지는 세 번 셌다 · 이슈 18).
    private var timelineSection: some View {
        let all = RecordStore.timeline(of: person)
        let filtering = timelineType != nil || timelineTag != nil
        let timeline = filtering
            ? all.filter { ListFilter.matches(type: $0.recordType, tags: $0.tags, wantedType: timelineType, wantedTag: timelineTag) }
            : all
        return Section {
            if all.isEmpty {
                Text("아직 기록이 없습니다. 함께한 일을 남겨 보세요.")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            } else if all.count >= 2 {
                timelineFilter(all)
            }
            if filtering && timeline.isEmpty {
                Text("조건에 맞는 기록이 없습니다")
                    .font(.scaled(15))
                    .foregroundStyle(Color.muted)
            }
            ForEach(timeline) { record in
                NavigationLink(value: record) {
                    TimelineRow(record: record, viewer: person)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        pendingRecordDeleteMessage = record.deletionMessage(viewer: person)
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
            Text(all.isEmpty ? "타임라인" : (filtering ? "타임라인 · 기록 \(timeline.count) / \(all.count)건" : "타임라인 · 기록 \(all.count)건"))
        }
    }

    /// 타임라인 거르기 칩 (FR-013) — 이 사람의 기록에 쓰인 유형 · 태그만. 고를 것이 하나뿐이면 두지 않는다.
    @ViewBuilder
    private func timelineFilter(_ records: [Record]) -> some View {
        let usedTypes = Set(records.map(\.recordType))
        let types = RecordType.all.filter { usedTypes.contains($0.key) }
        let tags = TagCatalog(personTags: [], recordTags: records.map(\.tags)).entries.map(\.tag)
        if types.count >= 2 || !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("전체", selected: timelineType == nil && timelineTag == nil) {
                        timelineType = nil
                        timelineTag = nil
                    }
                    if types.count >= 2 {
                        ForEach(types) { type in
                            filterChip(type.label, selected: timelineType == type.key) {
                                timelineType = timelineType == type.key ? nil : type.key
                            }
                        }
                    }
                    ForEach(tags, id: \.self) { tag in
                        filterChip("#\(tag)", selected: timelineTag == tag) {
                            timelineTag = timelineTag == tag ? nil : tag
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    private func filterChip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: text, selected: selected)
                .tapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var firstMetText: String {
        if let date = person.firstMetDate {
            return date.shown(precision: person.firstMetPrecision, style: .long)
        }
        return "날짜 미상"
    }

    private func export(_ format: PersonExporter.Format) {
        // 확인 창이 닫히는 동안 공유 시트를 띄우면 뜨지 않는다 — 잠깐 쉬었다가.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !PersonExporter.share(person, as: format) { exportFailed = true }
        }
    }

    private func deletePerson() {
        do {
            try DeletionUndo.shared.delete(person, in: context)
            dismiss()
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }

    private func deleteRecord(_ record: Record) {
        do {
            try DeletionUndo.shared.delete(record, in: context)
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
        pendingRecordDelete = nil
    }
}
