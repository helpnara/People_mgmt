import Foundation
import SwiftData

enum Persistence {
    /// 저장소 파일 이름. **바꾸지 않는다** — 바꾸면 빈 저장소를 새로 열어 사용자에게는 기록이 사라진 것으로 보인다.
    static let storeName = "SlowConnection"

    struct Opened {
        let container: ModelContainer
        let isInMemory: Bool
        /// 저장소를 끝내 못 열었으면 그 이유. 그때는 안내 화면만 그리고 **진짜 저장소 파일은 건드리지 않는다**
        /// (느린 부자 docs/18 5-4 · R3). 예전 앱은 여기서 죽었다 — 켤 때마다 죽으니 이유도 못 봤다.
        let failure: String?
    }

    /// 지금 판(4판) 저장소를 연다. 옛 판 저장소면 `SlowConnectionMigrationPlan` 으로 옮긴다.
    /// `url` 은 시험용 — 앱은 이름(`storeName`)으로 기본 자리를 쓴다.
    static func makeContainer(inMemory: Bool, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV5.self)
        // 동기화는 켜지 않는다 (D-1). 켤 때는 `.private("iCloud.com.helpnara.slow.connection")` 과
        // CloudKit 스키마 배포 절차가 함께 온다 (docs/06-ci.md).
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(storeName, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SlowConnectionMigrationPlan.self,
            configurations: [configuration]
        )
        if !inMemory { protectStoreFiles(at: configuration.url) }
        return container
    }

    /// 저장 파일에 **완전 보호** 등급을 건다 (요구사항 8.4). 잠금 중에는 파일을 읽을 수 없다 —
    /// 이 앱은 백그라운드 작업이 없어 제약이 없다. SQLite 의 `-wal` · `-shm` 도 함께.
    /// 실패해도 앱은 돈다 — 보호 등급은 덤이지 저장의 조건이 아니다.
    private static func protectStoreFiles(at url: URL) {
        let manager = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] where manager.fileExists(atPath: path) {
            do {
                try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
            } catch {
                print("⚠️ 파일 보호 등급을 못 걸었습니다: \(path) — \(error)")
            }
        }
    }

    @MainActor
    static func open(arguments: LaunchArguments) -> Opened {
        if arguments.simulateStoreFailure {
            return fallback(reason: "실행 인자로 일부러 실패시켰습니다 (-simulateStoreFailure)")
        }
        if arguments.seedSampleData {
            // 견본 자료는 **메모리에만** (느린 부자 교훈 4 — 진짜 저장소에 섞이면 되돌릴 수 없다).
            do {
                return Opened(container: try makeContainer(inMemory: true), isInMemory: true, failure: nil)
            } catch {
                return fallback(reason: "인메모리 저장소를 열지 못했습니다: \(error)")
            }
        }
        do {
            let container = try makeContainer(inMemory: false)
            // 날짜 칸을 UTC 정오로 한 번 옮긴다 (이슈 20) — 진짜 저장소에만. 깃발이 이 저장소를 가리키게.
            DateConvention.migrateIfNeeded(container.mainContext)
            return Opened(container: container, isInMemory: false, failure: nil)
        } catch {
            return fallback(reason: "\(error)")
        }
    }

    private static func fallback(reason: String) -> Opened {
        do {
            return Opened(container: try makeContainer(inMemory: true), isInMemory: true, failure: reason)
        } catch {
            // 인메모리마저 못 열면 더 할 수 있는 것이 없다 — 스키마가 깨진 것이고 CI 가 먼저 잡는다.
            fatalError("인메모리 저장소도 열지 못했습니다: \(error)")
        }
    }
}

/// **저장 실패 모사** (AC-29 · 전수조사 이슈 19). `-failSaves` 로 켜면 `PersonStore` · `RecordStore` 의 모든 저장이
/// 실패하고, 실패한 저장은 되돌린다 — 저장 실패 알림 · 입력 유지 · `다시 시도` 를 실기기 · 시험에서 본다.
/// 앱 시험은 `isOn` 을 직접 켜고 끈다.
@MainActor
enum SaveFailure {
    static var isOn = LaunchArguments.current.failSaves

    struct Simulated: LocalizedError {
        var errorDescription: String? { "저장 실패 시험 중입니다." }
    }

    /// 켜져 있으면 저장 전에 실패를 던진다.
    static func check() throws {
        if isOn { throw Simulated() }
    }
}
