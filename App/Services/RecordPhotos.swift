import Core
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// **기록 사진** (FR-058 · 9판 · D-65 · 2026-11-03 사용자) — 기록 하나에 최대 4장. 사람 사진과 같이 긴 변 1,024px JPEG 로 줄여 담는다.
///
/// - 사진은 기록의 칸이 아니라 장마다 `RecordPhoto` 객체다(저장소 밖 파일 · 목록을 읽을 때 함께 올라오지 않게).
/// - 기록 상세에 두 줄 격자, 누르면 크게. 타임라인 · 최근 기록 줄 오른쪽에 첫 사진 작은 그림.
/// - **본문에서 사진을 풀지 않는다** (CLAUDE.md · 이슈 10) — 모두 `.task` 에서 ImageIO 로 줄여 한 번, `PhotoThumbnails` 에 기억.
enum RecordPhotos {
    static let limit = 4

    /// 주 스레드 밖에서 줄인다 — 사람 사진과 같은 길(`PersonPhoto.normalized`).
    static func normalized(from data: Data) async -> Data? {
        await PersonPhoto.normalized(from: data)
    }

    /// 사진 한 장의 작은 그림 — 사진 번호 · 크기로 기억한다. 사진은 고치지 않고 바꿀 때 새 번호로 넣으므로 번호가 열쇠로 충분하다.
    @MainActor
    static func thumbnail(of photo: RecordPhoto, pixel: CGFloat) -> UIImage? {
        let key = "record-photo-\(photo.uuid.uuidString)-\(Int(pixel))"
        if let hit = PhotoThumbnails.shared.cached(key) { return hit }
        guard !PhotoThumbnails.shared.isKnownEmpty(key), !photo.isGone else { return nil }
        return PhotoThumbnails.shared.load(key, data: photo.data, pixel: pixel)
    }
}

/// 기록 수정 화면이 들고 있는 사진 한 장 — 이미 저장된 사진은 번호만(`data` 없음), 새로 고른 사진은 줄인 JPEG.
/// 저장된 사진의 파일을 초안에 읽어 두지 않는다 — 화면을 열 때마다 사진 넉 장을 읽지 않게.
struct DraftPhoto: Equatable, Identifiable {
    let id: UUID
    let data: Data?

    /// 새로 고른 사진.
    init(data: Data) {
        self.id = UUID()
        self.data = data
    }

    /// 이미 저장된 사진.
    init(existing photo: RecordPhoto) {
        self.id = photo.uuid
        self.data = nil
    }
}

extension SchemaV12.Record {
    /// 사진이 있는가 — 목록 줄이 작은 그림 자리를 둘지 정한다. 사진 파일은 읽지 않는다.
    var hasPhotos: Bool {
        (photos ?? []).contains { !$0.isGone }
    }

    /// 차례대로 · 지운 사진은 빼고.
    var sortedPhotos: [RecordPhoto] {
        (photos ?? []).filter { !$0.isGone }.sorted { ($0.position, $0.createdAt) < ($1.position, $1.createdAt) }
    }
}

/// 네모난 사진 한 칸 — 수정 화면(아직 저장 안 한 사진 포함) · 기록 상세가 같은 모양을 쓴다.
struct RecordPhotoTile: View {
    let draft: DraftPhoto
    /// 저장된 사진을 찾을 기록 — 새 기록이면 nil.
    let record: Record?
    var side: CGFloat = 72
    /// 칸 폭을 다 채우는 정사각형(기록 상세 격자). 끄면 `side` 크기.
    var fills = false

    @State private var image: UIImage?

    var body: some View {
        let length = Font.scaledLength(side)
        Color.accentSoft
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.scaled(24))
                        .foregroundStyle(Color.faint)
                }
            }
            .frame(width: fills ? nil : length, height: fills ? nil : length)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.rule, lineWidth: 1))
            .task(id: draft.id) {
                // 격자 칸은 폭이 정해지지 않아(채우기) 넉넉히 — 화면 폭의 절반 × 3배.
                let pixel = fills ? Font.scaledLength(220) * 3 : length * 3
                if let data = draft.data {
                    image = CardImaging.thumbnail(data, maxPixel: pixel).map { UIImage(cgImage: $0) }
                } else if let record, !record.isGone,
                          let photo = record.sortedPhotos.first(where: { $0.uuid == draft.id }) {
                    image = RecordPhotos.thumbnail(of: photo, pixel: pixel)
                }
            }
    }
}

/// 타임라인 · 최근 기록 줄 오른쪽의 첫 사진 작은 그림. 사진이 없으면 아무것도 그리지 않는다.
/// 사진을 찾는 일(관계 읽기)도 본문이 아니라 `.task` 에서 — 줄이 그려질 때마다 읽지 않게.
struct RecordRowThumbnail: View {
    let record: Record
    var side: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        // `Group` 은 안이 비면 수식어(.task)가 붙을 자리가 없다 — 비어도 하나인 `ZStack` 에 붙인다.
        ZStack {
            if let image {
                let length = min(Font.scaledLength(side), side * 1.5)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: length, height: length)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("사진 있음")
            }
        }
        .task(id: "\(record.uuid.uuidString)-\(record.updatedAt.timeIntervalSince1970)") {
            guard !record.isGone, let first = record.sortedPhotos.first else {
                image = nil
                return
            }
            image = RecordPhotos.thumbnail(of: first, pixel: Font.scaledLength(side) * 3)
        }
    }
}

/// 사진 크게 보기 — 넘겨 가며 본다. 화면 두 배 크기로만 푼다(이슈 10).
struct RecordPhotoViewer: View {
    let photos: [RecordPhoto]
    @State var selection: UUID
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        guard photos.count > 1 else { return "사진" }
        let index = (photos.firstIndex { $0.uuid == selection } ?? 0) + 1
        return "사진 " + String(index) + " / " + String(photos.count)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(photos, id: \.uuid) { photo in
                    LargeRecordPhoto(photo: photo)
                        .tag(photo.uuid)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            // 밝은 바탕에서 흰 점이 보이지 않는다 — 점 뒤에 바탕을 깐다.
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct LargeRecordPhoto: View {
    let photo: RecordPhoto
    @State private var image: UIImage?
    @State private var failed = false
    /// 두 손가락으로 키우기 · 두 번 눌러 2배 — 명함 크게 보기와 같은 손맛.
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 4) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        scale = scale > 1 ? 1 : 2
                        lastScale = scale
                    }
                    .padding()
                    .accessibilityLabel("기록 사진")
            } else if failed {
                ContentUnavailableView("사진을 열지 못했습니다", systemImage: "photo",
                                       description: Text("기록 수정에서 사진을 다시 골라 주세요."))
            } else {
                ProgressView()
            }
        }
        .task(id: photo.uuid) {
            guard !photo.isGone, let data = photo.data else {
                failed = true
                return
            }
            let decoded = CardImaging.thumbnail(data, maxPixel: 2_400).map { UIImage(cgImage: $0) }
            image = decoded
            failed = decoded == nil
        }
    }
}
