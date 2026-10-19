import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 목록 위 설정 단추가 여는 길 (D-34). 목적지는 뿌리(`PeopleListView`) 한 곳에 둔다 (이슈 16).
struct SettingsRoute: Hashable {}

/// **설정** (FR-030 · D-34) — 백업 · 복원, 개인정보 안내, 앱 버전.
///
/// 백업은 파일 하나(.json, 명함 사진 포함)를 만들어 파일 앱 · iCloud Drive 에 저장한다. 복원은 **앱이 비어 있을 때만**.
/// 만들기 · 읽기 · 복원은 모두 주 스레드 밖에서 한다 (`Backup`).
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var working: String?
    @State private var exportDocument: BackupDocument?
    @State private var exportName = Backup.fileName()
    @State private var showingExporter = false
    @State private var showingImporter = false
    /// 파일 내보내기 · 가져오기는 하나씩만 건다 — 같은 화면에 둘을 걸면 SwiftUI 가 하나만 띄운다. 무엇을 하는지는 이것으로.
    @State private var fileKind: FileKind = .backup
    /// vCard 가져오기 미리보기 (D-41).
    @State private var importItems: [VCardTransfer.Item]?
    @State private var pendingRestore: BackupFile?
    @State private var message: (title: String, body: String)?
    /// 모임 짝짓기 문턱 (D-39). 기본 0.3.
    @AppStorage(GroupMatchSetting.key) private var groupMatch: GroupMatchSetting = .standard
    // 알림 (D-40) — 모두 기본은 꺼짐, 시각은 오전 9시.
    @AppStorage(ReminderSettings.birthdaysKey) private var remindBirthdays = false
    @AppStorage(ReminderSettings.anniversariesKey) private var remindAnniversaries = false
    @AppStorage(ReminderSettings.cadenceKey) private var remindCadence = false
    @AppStorage(ReminderSettings.hourKey) private var remindHour = ReminderSettings.defaultHour
    @AppStorage(ReminderSettings.minuteKey) private var remindMinute = 0
    /// iCloud 동기화 (D-42 — 기본 켬). 바꾸면 앱을 다시 열 때 적용된다.
    @AppStorage(CloudSync.enabledKey) private var syncWanted = true
    private let syncMonitor = CloudSyncMonitor.shared

    var body: some View {
        List {
            syncSection

            Section {
                Button {
                    makeBackup()
                } label: {
                    Label("백업 파일 만들기", systemImage: "square.and.arrow.up")
                }
                .disabled(working != nil)
            } header: {
                Text("백업")
            } footer: {
                Text("사람 · 기록 · 아는 사이 · 명함 사진을 파일 하나(.json)로 만듭니다. 파일 앱이나 iCloud Drive 에 저장해 두면 기기를 바꾸거나 앱을 다시 설치해도 되살릴 수 있습니다. 이 파일에는 인연의 기록이 그대로 들어 있으니 믿을 수 있는 곳에만 두세요.")
            }

            Section {
                Button {
                    fileKind = .backup
                    showingImporter = true
                } label: {
                    Label("백업에서 복원", systemImage: "square.and.arrow.down")
                }
                // 동기화 중에는 복원하지 않는다 (D-44).
                .disabled(working != nil || CloudSync.isActive)
            } header: {
                Text("복원")
            } footer: {
                Text(CloudSync.isActive
                     ? "iCloud 동기화가 켜져 있으면 복원하지 않습니다 — 복원한 사람과 iCloud 의 사람이 둘씩 생길 수 있습니다. 위에서 동기화를 끄고 앱을 다시 연 뒤 복원하세요."
                     : "앱에 사람이나 기록이 하나도 없을 때만 복원합니다 — 지금 자료와 섞이지 않게. 새 기기나 다시 설치한 뒤에 쓰세요.")
            }

            if let working {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(working).font(.scaled(15)).foregroundStyle(Color.muted)
                    }
                }
            }

            Section {
                Button {
                    exportVCard()
                } label: {
                    Label("vCard 파일로 내보내기", systemImage: "person.crop.rectangle.stack")
                }
                .disabled(working != nil)
                Button {
                    fileKind = .vcard
                    showingImporter = true
                } label: {
                    Label("vCard 파일 가져오기", systemImage: "person.badge.plus")
                }
                .disabled(working != nil)
            } header: {
                Text("연락처 파일 (vCard)")
            } footer: {
                Text("내보내기는 나를 뺀 사람의 이름 · 별명 · 소속 · 직무 · 연락 수단 · 생일을 .vcf 파일 하나로 만듭니다. 기록 · 첫 인연 · 태그 · 명함 사진은 들어가지 않습니다 — 그것은 백업 파일이 맡습니다. 가져오기는 넣기 전에 새 사람 · 같은 사람 후보 · 이미 있는 사람을 나눠 보여 주고, 고른 사람만 넣습니다.")
            }

            Section {
                Toggle("생일 당일", isOn: $remindBirthdays)
                Toggle("알게 된 지 n주년", isOn: $remindAnniversaries)
                Toggle("연락 주기 (고른 사람만)", isOn: $remindCadence)
                if remindBirthdays || remindAnniversaries || remindCadence {
                    DatePicker("알림 시각", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("알림")
            } footer: {
                Text("기본은 모두 꺼져 있습니다. 생일은 생일을 적은 사람, n주년은 처음 만난 날을 적은 사람, 연락 주기는 사람 수정에서 주기를 고른 사람만 그날 알립니다. 밀린 알림을 쌓지 않고 앱 아이콘에 숫자를 달지 않습니다. 알림은 이 기기 안에서만 만들어집니다.")
            }
            .onChange(of: remindBirthdays) { _, on in reminderChanged(turnedOn: on) }
            .onChange(of: remindAnniversaries) { _, on in reminderChanged(turnedOn: on) }
            .onChange(of: remindCadence) { _, on in reminderChanged(turnedOn: on) }
            .onChange(of: remindHour) { _, _ in refreshReminders() }
            .onChange(of: remindMinute) { _, _ in refreshReminders() }

            Section {
                Picker(selection: $groupMatch) {
                    ForEach(GroupMatchSetting.allCases) { option in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.scaled(16))
                                .foregroundStyle(Color.ink)
                            Text(option.detail)
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                        }
                        .tag(option)
                    }
                } label: {
                    Text("같은 모임으로 볼 겹침")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("모임의 변화")
            } footer: {
                Text("분기마다 모임을 다시 찾고, 앞 분기 모임과 사람이 얼마나 겹치는지로 같은 모임인지 가립니다. 작은 쪽 모임의 절반 이상이 겹치면 이 설정과 상관없이 같은 모임입니다. 같은 모임이면 그대로 · 사람이 늘었습니다 · 사람이 줄었습니다로, 다른 모임이면 새로 생긴 모임과 최근 기록 없음 두 줄로 보입니다. 내 인맥 → 돌아보기 → 모임의 변화와 관계도 시점 막대의 설명에 반영되고, 내 인맥을 다시 열 때 바뀝니다.")
            }

            Section {
                Label(CloudSync.isActive
                      ? "자료는 이 기기와 내 iCloud 의 비공개 영역에 저장됩니다. 앱은 자기 서버로 아무것도 보내지 않고, 개발자는 볼 수 없습니다."
                      : "자료는 이 기기에만 저장됩니다. 앱은 인터넷으로 아무것도 보내지 않습니다.", systemImage: "lock")
                Label("기기의 iCloud 백업을 켜 두었다면 이 앱의 자료도 그 백업에 함께 들어갑니다.", systemImage: "icloud")
                Label("전화 · 메일 단추는 기기의 전화 · 메일 앱으로 넘겨 줄 뿐입니다.", systemImage: "phone")
            } header: {
                Text("개인정보")
            }
            .font(.scaled(14))
            .foregroundStyle(Color.bodyText)

            Section {
                LabeledContent("버전", value: Self.version)
            } header: {
                Text("앱")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $showingExporter, document: exportDocument,
                      contentType: fileKind == .vcard ? .vCard : .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result {
                message = (fileKind == .vcard ? "vCard 파일을 저장하지 못했습니다" : "백업 파일을 저장하지 못했습니다",
                           error.localizedDescription)
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: fileKind == .vcard ? [.vCard] : [.json]) { result in
            switch result {
            case .success(let url):
                if fileKind == .vcard { readVCard(url) } else { readBackup(url) }
            case .failure(let error): message = ("파일을 열지 못했습니다", error.localizedDescription)
            }
        }
        .sheet(isPresented: Binding(get: { importItems != nil }, set: { if !$0 { importItems = nil } })) {
            VCardImportView(items: importItems ?? []) { added in
                importItems = nil
                // 시트가 내려간 뒤에 알린다 — 내려가는 중에 띄우면 알림이 묻힌다.
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    message = ("가져왔습니다", "사람 \(added)명을 넣었습니다.")
                }
            }
        }
        .confirmationDialog("복원", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .hidden, presenting: pendingRestore) { file in
            Button("복원") { restore(file) }
            Button("취소", role: .cancel) { pendingRestore = nil }
        } message: { file in
            let summary = Backup.summary(of: file)
            Text("\(file.exportedAt.formatted(date: .long, time: .shortened))에 만든 백업입니다. 사람 \(summary.people)명 · 기록 \(summary.records)건 · 아는 사이 \(summary.ties)줄 · 명함 \(summary.cards)장을 복원할까요?")
        }
        .alert(message?.title ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(message?.body ?? "")
        }
    }

    /// 시 · 분 두 칸을 시각 고르기 하나로.
    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: remindHour, minute: remindMinute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            remindHour = parts.hour ?? ReminderSettings.defaultHour
            remindMinute = parts.minute ?? 0
        })
    }

    /// 알림을 켜면 그때 한 번 허락을 묻는다. 거절돼 있으면 되돌리고 설정 앱으로 안내한다.
    private func reminderChanged(turnedOn: Bool) {
        guard turnedOn else {
            refreshReminders()
            return
        }
        Task {
            if await ReminderScheduler.requestPermission() {
                refreshReminders()
            } else {
                remindBirthdays = false
                remindAnniversaries = false
                remindCadence = false
                message = ("알림이 꺼져 있습니다", "기기의 설정 앱 → 알림 → 느린 인연에서 알림을 허용한 뒤 다시 켜 주세요.")
            }
        }
    }

    private func refreshReminders() {
        let container = context.container
        Task { await ReminderScheduler.refresh(container: container) }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (빌드 \(build))"
    }

    /// **iCloud 동기화** (D-42). 켜고 끄기와 마지막으로 주고받은 때. 동기화를 쓸 수 없는 판에서는 안내만.
    @ViewBuilder
    private var syncSection: some View {
        Section {
            if CloudSync.mainStoreSyncAvailable {
                Toggle("iCloud 동기화", isOn: $syncWanted)
                if syncWanted != CloudSync.isActive {
                    Label("앱을 완전히 닫았다가 다시 열면 적용됩니다.", systemImage: "arrow.clockwise")
                        .font(.scaled(14))
                        .foregroundStyle(Color.accent)
                }
                if CloudSync.isActive {
                    LabeledContent("마지막 동기화") {
                        Text(syncStatus)
                            .foregroundStyle(syncMonitor.lastError == nil ? Color.muted : Color.danger)
                    }
                    if let failure = syncMonitor.lastError {
                        Text(failure)
                            .font(.scaled(13))
                            .foregroundStyle(Color.muted)
                    }
                }
            } else {
                Text("다음 판에서 켜집니다.")
                    .foregroundStyle(Color.muted)
            }
        } header: {
            Text("iCloud 동기화")
        } footer: {
            Text(CloudSync.mainStoreSyncAvailable
                 ? "같은 Apple 계정으로 로그인한 아이폰 · 아이패드가 같은 사람 · 기록을 봅니다. 자료는 내 iCloud 의 비공개 영역에 저장되고 개발자는 볼 수 없습니다. 끄면 이 기기 안에만 둡니다."
                 : "같은 Apple 계정의 아이폰 · 아이패드가 같은 사람 · 기록을 보게 하는 기능입니다. 지금은 이 기기 안에만 저장합니다.")
        }
    }

    private var syncStatus: String {
        if syncMonitor.isWorking { return "주고받는 중…" }
        if syncMonitor.lastError != nil { return "실패" }
        guard let last = syncMonitor.lastSuccess else { return "아직 없음" }
        return last.formatted(date: .abbreviated, time: .shortened)
    }

    enum FileKind {
        case backup, vcard
    }

    private func exportVCard() {
        working = "vCard 파일을 만드는 중…"
        let container = context.container
        Task {
            let made = await VCardTransfer.export(container: container)
            working = nil
            guard made.count > 0 else {
                message = ("내보낼 사람이 없습니다", "사람을 적은 뒤 다시 시도해 주세요.")
                return
            }
            fileKind = .vcard
            exportName = VCardTransfer.fileName()
            exportDocument = BackupDocument(data: made.data)
            showingExporter = true
        }
    }

    private func readVCard(_ url: URL) {
        working = "vCard 파일을 읽는 중…"
        let container = context.container
        Task {
            do {
                let items = try await VCardTransfer.preview(url: url, container: container)
                working = nil
                if items.isEmpty {
                    message = ("가져올 사람이 없습니다", "이 파일에서 이름이 있는 연락처를 찾지 못했습니다.")
                } else {
                    importItems = items
                }
            } catch {
                working = nil
                message = ("파일을 열지 못했습니다", error.localizedDescription)
            }
        }
    }

    private func makeBackup() {
        working = "백업 파일을 만드는 중…"
        let container = context.container
        Task {
            do {
                let made = try await Backup.export(container: container)
                fileKind = .backup
                exportName = Backup.fileName()
                exportDocument = BackupDocument(data: made.data)
                working = nil
                showingExporter = true
            } catch {
                working = nil
                message = ("백업 파일을 만들지 못했습니다", error.localizedDescription)
            }
        }
    }

    private func readBackup(_ url: URL) {
        working = "백업 파일을 읽는 중…"
        Task {
            do {
                let file = try await Task.detached(priority: .userInitiated) { () throws -> BackupFile in
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    return try Backup.decode(Data(contentsOf: url))
                }.value
                working = nil
                pendingRestore = file
            } catch {
                working = nil
                message = ("복원하지 못했습니다", error.localizedDescription)
            }
        }
    }

    private func restore(_ file: BackupFile) {
        pendingRestore = nil
        working = "복원하는 중…"
        let container = context.container
        Task {
            do {
                let summary = try await Backup.restore(file, container: container)
                working = nil
                message = ("복원했습니다", "사람 \(summary.people)명 · 기록 \(summary.records)건 · 아는 사이 \(summary.ties)줄 · 명함 \(summary.cards)장을 되살렸습니다.")
            } catch {
                working = nil
                message = ("복원하지 못했습니다", error.localizedDescription)
            }
        }
    }
}
