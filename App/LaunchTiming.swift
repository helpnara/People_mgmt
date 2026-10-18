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

    /// 한 작업에 걸린 시간.
    static func measure<T>(_ label: String, _ work: () -> T) -> T {
        guard LaunchArguments.current.largeSample else { return work() }
        let started = Date()
        let result = work()
        print("⏱ \(label) \(Int(Date().timeIntervalSince(started) * 1000))ms")
        return result
    }
}
