import CoreData
import Foundation
import Observation
import SwiftData

/// **iCloud 동기화** (D-42 · ADR-0005) — 같은 Apple 계정의 아이폰 · 아이패드가 같은 사람 · 기록을 본다.
///
/// 내 iCloud 의 **비공개 영역**에만 저장된다 — 개발자 서버는 없고 개발자도 볼 수 없다. 앱은 여전히 자기 서버로 아무것도 보내지 않는다.
///
/// **저장 형태(스키마)는 앱이 만들지 않는다** (ADR-0005 · 느린 부자 방식). TestFlight · App Store 판은 늘 iCloud **배포 환경**
/// (Production)에 붙는데, 배포 환경에서는 앱이 스키마를 만들 수 없다. 그래서 `Tools/cloudkit/generate-ckdb.py` 가 모델에서
/// 스키마 파일을 만들고, CI(`cloudkit-schema.yml`)가 개발 환경에 적용하고, 사람이 CloudKit 콘솔에서 배포 환경으로 올린다.
/// 그 뒤에 `mainStoreSyncAvailable` 를 켠 판을 낸다 — 진짜 저장소가 처음 iCloud 와 이어지며 이 기기의 자료가 빠짐없이 올라간다.
enum CloudSync {
    static let containerID = "iCloud.com.helpnara.slow.connection"

    /// 이 판에서 진짜 저장소를 iCloud 와 잇는가. **스키마가 배포 환경에 올라간 뒤에만 참으로** 바꾼다.
    /// 2026-10-19 개발 환경 적용(스키마 워크플로 실행 3) · 사용자가 Production 배포 → 빌드 21 부터 켬.
    static let mainStoreSyncAvailable = true

    /// 설정의 켜고 끄기 (D-42 — 기본 켬). 바꾸면 앱을 다시 열 때 적용된다 — 저장소를 연 뒤에는 바꿀 수 없다.
    static let enabledKey = "sync.enabled"

    static var userWantsSync: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// 이 실행에서 CloudKit 을 써도 되는가. **시뮬레이터 · 앱 시험에서는 쓰지 않는다** — CI 의 시뮬레이터 판은 서명하지 않아
    /// iCloud 권한(엔타이틀먼트)이 없고, 권한 없이 CloudKit 을 부르면 CloudKit 이 앱을 끈다 (빌드 20 첫 CI · 앱 시험이 멈춤).
    static var canUseCloudKit: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        #endif
    }

    /// 이번에 연 저장소가 iCloud 와 이어졌는가 — 앱을 켤 때 한 번 정해진다.
    @MainActor static private(set) var isActive = false

    @MainActor static func markOpened(active: Bool) {
        isActive = active
    }
}

/// **동기화 상태** (설정에 보인다) — iCloud 와 마지막으로 주고받은 때와 실패. 사람 · 기록 내용은 보지 않는다.
///
/// 저장소를 열기 **전에** `start` 한다 — 여는 순간의 준비(setup) 결과부터 받으려고.
@MainActor
@Observable
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()

    /// 마지막으로 성공한 가져오기 · 내보내기가 끝난 때.
    private(set) var lastSuccess: Date?
    /// 마지막 실패의 설명 — 다음 성공이 지운다.
    private(set) var lastError: String?
    /// 주고받는 중인가.
    private(set) var isWorking = false
    /// **방향별** 마지막 성공과 실패 (빌드 30 · 이슈 43). 한쪽 실패를 다른 쪽 성공이 지우지 않는다 —
    /// 빌드 29 까지는 올리기(내보내기)가 실패해도 곧 이어진 받기(가져오기) 성공이 실패를 지워, 설정에는 늘 성공으로 보였다.
    private(set) var lastUpload: Date?
    private(set) var lastDownload: Date?
    private(set) var uploadError: String?
    private(set) var downloadError: String?

    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let finished = event.endDate
            let succeeded = event.succeeded
            let failure = event.error?.localizedDescription
            let isSetup = event.type == .setup
            let isExport = event.type == .export
            let isImport = event.type == .import
            MainActor.assumeIsolated {
                self?.record(finished: finished, succeeded: succeeded, failure: failure, isSetup: isSetup)
                self?.recordDirection(finished: finished, succeeded: succeeded, failure: failure,
                                      isExport: isExport, isImport: isImport)
            }
        }
    }

    private func recordDirection(finished: Date?, succeeded: Bool, failure: String?, isExport: Bool, isImport: Bool) {
        guard let finished, isExport || isImport else { return }
        if isExport {
            if succeeded {
                lastUpload = finished
                uploadError = nil
            } else {
                uploadError = failure ?? "iCloud 에 올리지 못했습니다"
            }
        } else {
            if succeeded {
                lastDownload = finished
                downloadError = nil
            } else {
                downloadError = failure ?? "iCloud 에서 받지 못했습니다"
            }
        }
    }

    private func record(finished: Date?, succeeded: Bool, failure: String?, isSetup: Bool) {
        guard let finished else {
            isWorking = true
            return
        }
        isWorking = false
        if succeeded {
            // 준비(setup)만 끝난 것은 주고받은 것이 아니다 — 실패만 지운다.
            if !isSetup { lastSuccess = finished }
            lastError = nil
        } else {
            lastError = failure ?? "iCloud 와 주고받지 못했습니다"
        }
    }
}
