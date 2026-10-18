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
    @State private var pendingRestore: BackupFile?
    @State private var message: (title: String, body: String)?

    var body: some View {
        List {
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
                    showingImporter = true
                } label: {
                    Label("백업에서 복원", systemImage: "square.and.arrow.down")
                }
                .disabled(working != nil)
            } header: {
                Text("복원")
            } footer: {
                Text("앱에 사람이나 기록이 하나도 없을 때만 복원합니다 — 지금 자료와 섞이지 않게. 새 기기나 다시 설치한 뒤에 쓰세요.")
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
                Label("자료는 이 기기에만 저장됩니다. 앱은 인터넷으로 아무것도 보내지 않습니다.", systemImage: "lock")
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
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json,
                      defaultFilename: exportName) { result in
            if case .failure(let error) = result {
                message = ("백업 파일을 저장하지 못했습니다", error.localizedDescription)
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): readBackup(url)
            case .failure(let error): message = ("파일을 열지 못했습니다", error.localizedDescription)
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

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (빌드 \(build))"
    }

    private func makeBackup() {
        working = "백업 파일을 만드는 중…"
        let container = context.container
        Task {
            do {
                let made = try await Backup.export(container: container)
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
