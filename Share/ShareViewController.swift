import Core
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// **공유 시트로 기록 초안** (1.1.9 · 빌드 63 · 이슈 101 · FR-076 · D-79).
///
/// 다른 앱의 글 · 주소 · 사진(4장까지)을 받아 App Group 에 초안 폴더로 남긴다. 저장소는 열지 않는다 —
/// 앱이 다음에 앞으로 나오면 홈 맨 위 `공유로 받은 초안` 에 보이고, 누구와의 기록인지 골라 기록 추가로 잇는다.
/// 통신하지 않는다. 사진은 여기서 긴 변 2,048px 로 줄여 둔다(확장의 메모리 한도).
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareDraftView(model: model,
                                  onCancel: { [weak self] in self?.finish(cancelled: true) },
                                  onSave: { [weak self] in self?.save() })
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        Task { await model.load(providers) }
    }

    private func save() {
        if model.write() {
            finish(cancelled: false)
        }
    }

    private func finish(cancelled: Bool) {
        if cancelled {
            extensionContext?.cancelRequest(withError: NSError(domain: "SlowConnectionShare", code: 0))
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

/// 받은 것 — 글 · 주소 · 줄인 사진.
@MainActor
@Observable
final class ShareModel {
    var text = ""
    var photos: [Data] = []
    /// 화면에 보일 작은 그림 — 본문에서 사진을 풀지 않는다(이슈 10).
    var previews: [UIImage] = []
    var loading = true
    var failed = false

    func load(_ providers: [NSItemProvider]) async {
        var parts: [String] = []
        var images: [Data] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
               let url = await Self.loadURL(provider) {
                parts.append(url)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                guard images.count < SharedFiles.draftPhotoLimit else { continue }
                if let data = await Self.loadImage(provider) { images.append(data) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let text = await Self.loadText(provider) {
                parts.append(text)
            }
        }
        text = SharedDraft.joinedText(parts, limit: Limits.recordNote)
        photos = images
        previews = images.compactMap { Self.thumbnail($0, maxPixel: 216) }
        loading = false
    }

    /// App Group 에 초안 폴더를 쓴다. 실패하면 거짓 — 화면이 알린다.
    func write() -> Bool {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedFiles.appGroup) else {
            failed = true
            return false
        }
        var draft = SharedDraft(text: String(text.prefix(Limits.recordNote)), photoFiles: [])
        let folder = base.appendingPathComponent(SharedFiles.shareDrafts, isDirectory: true)
            .appendingPathComponent(draft.id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, photo) in photos.enumerated() {
                let name = "photo-\(index).jpg"
                try photo.write(to: folder.appendingPathComponent(name), options: [.atomic])
                draft.photoFiles.append(name)
            }
            // 초안 파일은 마지막에 — 앱은 이 파일이 있는 폴더만 읽는다(사진을 쓰다 멈춘 폴더는 보이지 않는다).
            try JSONEncoder().encode(draft).write(to: folder.appendingPathComponent(SharedFiles.draftFile), options: [.atomic])
            return true
        } catch {
            try? FileManager.default.removeItem(at: folder)
            failed = true
            return false
        }
    }

    private static func loadURL(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url?.absoluteString)
            }
        }
    }

    private static func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }

    private static func thumbnail(_ data: Data, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }

    /// 원본을 통째로 풀지 않고 ImageIO 로 줄여 JPEG 로 (이슈 10 · 확장의 메모리 한도).
    private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        let raw: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let raw, let source = CGImageSourceCreateWithData(raw as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_048,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }
}

/// 공유 시트 화면 — 받은 것을 보이고, 메모를 고칠 수 있게. `담기` 로 초안을 남긴다.
struct ShareDraftView: View {
    @Bindable var model: ShareModel
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if model.loading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("받은 것을 읽는 중…").font(.scaled(15)).foregroundStyle(Color.muted)
                    }
                } else {
                    Section {
                        TextField("메모", text: $model.text, axis: .vertical)
                            .font(.scaled(16))
                            .lineLimit(3...10)
                    } header: {
                        Text("메모")
                    } footer: {
                        Text("글 · 주소는 기록의 메모로 들어갑니다. 지금 고쳐도 되고 앱에서 고쳐도 됩니다.")
                    }
                    if !model.photos.isEmpty {
                        Section("사진 \(model.photos.count)장") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(model.previews.enumerated()), id: \.offset) { _, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: Font.scaledLength(72), height: Font.scaledLength(72))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Text("앱을 열면 홈 맨 위 **공유로 받은 초안** 에 보입니다. 누르면 누구와의 기록인지 고르고 기록 추가로 이어집니다. 이 초안은 이 기기에만 남습니다.")
                            .font(.scaled(14))
                            .foregroundStyle(Color.muted)
                    }
                    if model.failed {
                        Text("초안을 남기지 못했습니다. 다시 시도해 주세요.")
                            .font(.scaled(14))
                            .foregroundStyle(Color.danger)
                    }
                }
            }
            .navigationTitle("느린 인연에 담기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("담기", action: onSave)
                        .disabled(model.loading || (model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.photos.isEmpty))
                }
            }
        }
    }
}
