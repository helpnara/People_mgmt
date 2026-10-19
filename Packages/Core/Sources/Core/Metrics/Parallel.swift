import Dispatch
import Foundation

/// **여러 코어로 나눠 돌기** (D-47). 서로 기대지 않는 일을 덩어리로 나눠 함께 센다 — 자리마다 쓰는 곳이 달라 결과는 차례로 돌 때와 같다.
enum Parallel {
    /// `0..<count` 를 덩어리로 나눠 부른다. 덩어리가 하나뿐이면(작은 일 · 코어 하나) 이 스레드에서 바로 돈다.
    /// `body` 는 자기 덩어리의 자리에만 써야 한다.
    static func chunks(_ count: Int, minimumChunk: Int, _ body: (Range<Int>) -> Void) {
        guard count > 0 else { return }
        let pieces = min(ProcessInfo.processInfo.activeProcessorCount, max(1, count / max(1, minimumChunk)))
        guard pieces > 1 else {
            body(0..<count)
            return
        }
        DispatchQueue.concurrentPerform(iterations: pieces) { k in
            body((count * k / pieces)..<(count * (k + 1) / pieces))
        }
    }
}
