import Foundation

/// 화면이 처음 서기까지의 시간을 로그에만 남긴다 (요구사항 8.5). 막는 검사가 아니라 숫자를 모으는 자리다.
/// CI 가 큰 견본(`-seedLargeSample`)으로 띄워 `⏱` 줄을 긁어 간다 (ios.yml).
enum LaunchTiming {
    /// 프로세스 시작 기준. 앱 `init` 첫 줄에서 건드려 고정한다.
    static let start = Date()

    static func mark(_ label: String) {
        guard LaunchArguments.current.largeSample else { return }
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        print("⏱ \(label) \(elapsed)ms")
    }

    /// `started` 부터 지금까지.
    static func log(_ label: String, since started: Date) {
        guard LaunchArguments.current.largeSample else { return }
        print("⏱ \(label) \(Int(Date().timeIntervalSince(started) * 1000))ms")
    }

    /// 저장소를 열고 견본을 다 채운 때 — 그 뒤 목록이 뜨기까지를 따로 잰다(요구사항 8.5 콜드 실행).
    /// 앱 시작부터 잰 값에는 견본 채우기(수십 초)가 들어 있어 실기기의 첫 실행과 견줄 수 없다. 한 번 쓰면 비운다.
    @MainActor static var storeReady: Date?
    /// `begin` 에서 `end` 까지 — 상세 열기처럼 화면을 넘나드는 일.
    @MainActor private static var begun: [String: Date] = [:]

    @MainActor static func begin(_ key: String) {
        guard LaunchArguments.current.largeSample else { return }
        begun[key] = Date()
    }

    @MainActor static func end(_ key: String, label: () -> String) {
        guard LaunchArguments.current.largeSample, let started = begun.removeValue(forKey: key) else { return }
        log(label(), since: started)
    }

    /// 한 작업에 걸린 시간.
    static func measure<T>(_ label: String, _ work: () -> T) -> T {
        guard LaunchArguments.current.largeSample else { return work() }
        let started = Date()
        let result = work()
        print("⏱ \(label) \(Int(Date().timeIntervalSince(started) * 1000))ms")
        return result
    }
}
