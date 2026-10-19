import CoreData
import Foundation
import SwiftData

/// **iCloud 동기화** (D-42 · ADR-0005) — 같은 Apple 계정의 아이폰 · 아이패드가 같은 사람 · 기록을 본다.
///
/// 내 iCloud 의 **비공개 영역**에만 저장된다 — 개발자 서버는 없고 개발자도 볼 수 없다. 앱은 여전히 자기 서버로 아무것도 보내지 않는다.
///
/// **두 단계로 켠다** (Apple 의 절차):
/// 1. 준비 판(빌드 20): `CloudSchema.prepare` 가 **버리는 임시 저장소**로 iCloud 개발 환경에 저장 형태(스키마)만 만든다.
///    사람 · 기록은 올리지 않는다. 사용자가 CloudKit 콘솔에서 그 스키마를 배포 환경(Production)으로 올린다.
/// 2. 동기화 판(빌드 21): `mainStoreSyncAvailable` 를 켜면 진짜 저장소가 iCloud 와 이어진다 — 이 기기의 자료가 처음으로 올라가고
///    다른 기기는 내려받는다. 처음 잇는 저장소라 자료가 빠짐없이 올라간다(준비 판에서 진짜 저장소를 잇지 않은 까닭).
enum CloudSync {
    static let containerID = "iCloud.com.helpnara.slow.connection"

    /// 이 판에서 진짜 저장소를 iCloud 와 잇는가. **준비 판(빌드 20)은 거짓** — 동기화 판에서 켠다.
    static let mainStoreSyncAvailable = false

    /// 설정의 켜고 끄기 (D-42 — 기본 켬). 바꾸면 앱을 다시 열 때 적용된다 — 저장소를 연 뒤에는 바꿀 수 없다.
    static let enabledKey = "sync.enabled"

    static var userWantsSync: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// 이번에 연 저장소가 iCloud 와 이어졌는가 — 앱을 켤 때 한 번 정해진다.
    @MainActor static private(set) var isActive = false

    @MainActor static func markOpened(active: Bool) {
        isActive = active
    }
}

/// **iCloud 저장 형태 준비** (준비 판 · D-42). 버리는 임시 저장소를 iCloud **개발 환경**에 잇고 스키마를 만든 뒤 지운다.
/// Apple 의 SwiftData 동기화 안내와 같은 길이다(`NSPersistentCloudKitContainer.initializeCloudKitSchema`).
///
/// 실패해도 앱은 그대로 돈다 — 결과(언제 · 무엇)를 설정에 보여 주고 `다시 준비` 로 되풀이한다.
/// iCloud 에 로그인하지 않았거나 네트워크가 없으면 실패로 남는다.
enum CloudSchema {
    static let doneKey = "cloud.schema.done"
    static let messageKey = "cloud.schema.message"

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }
    static var message: String? { UserDefaults.standard.string(forKey: messageKey) }

    /// 끝났으면 다시 하지 않는다 (`force` 면 다시).
    static func prepare(force: Bool = false) async {
        if isDone && !force { return }
        let result = await Task.detached(priority: .utility) { () -> (Bool, String) in
            run()
        }.value
        UserDefaults.standard.set(result.0, forKey: doneKey)
        UserDefaults.standard.set(result.1, forKey: messageKey)
    }

    nonisolated private static func run() -> (Bool, String) {
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [Person.self, Record.self, Tie.self]) else {
            return (false, "\(stamp) — 저장 형태를 읽지 못했습니다")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-schema-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("schema.store"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudSync.containerID)
        description.shouldAddStoreAsynchronously = false
        let container = NSPersistentCloudKitContainer(name: "SlowConnectionSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        // 저장소를 바로 여는 설정이라(`shouldAddStoreAsynchronously = false`) 완료 처리는 돌아오기 전에 불린다.
        final class Outcome: @unchecked Sendable { var error: Error? }
        let outcome = Outcome()
        container.loadPersistentStores { _, error in outcome.error = error }
        if let loadError = outcome.error {
            return (false, "\(stamp) — 임시 저장소를 열지 못했습니다: \(loadError.localizedDescription)")
        }
        do {
            try container.initializeCloudKitSchema(options: [])
        } catch {
            return (false, "\(stamp) — iCloud 에 저장 형태를 만들지 못했습니다: \(error.localizedDescription)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        return (true, "\(stamp) — iCloud 에 저장 형태를 만들었습니다")
    }
}
