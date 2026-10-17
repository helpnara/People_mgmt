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

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            // 동기화는 켜지 않는다 (D-1). 켤 때는 `.private("iCloud.com.helpnara.slow.connection")` 과
            // CloudKit 스키마 배포 절차가 함께 온다 (docs/06-ci.md).
            cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: SlowConnectionMigrationPlan.self,
            configurations: [configuration]
        )
    }

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
            return Opened(container: try makeContainer(inMemory: false), isInMemory: false, failure: nil)
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
