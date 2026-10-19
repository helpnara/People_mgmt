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
        // 리눅스의 `concurrentPerform` 은 넘기는 묶음에 `@Sendable` 을 요구한다. 덩어리마다 자기 자리에만 쓴다는 약속은
        // 부르는 쪽이 지키므로(위 설명), 묶음을 상자에 담아 넘긴다. 상자는 이 함수가 끝나기 전에만 쓰인다.
        withoutActuallyEscaping(body) { escapable in
            let box = Unchecked(work: escapable)
            DispatchQueue.concurrentPerform(iterations: pieces) { k in
                box.work((count * k / pieces)..<(count * (k + 1) / pieces))
            }
        }
    }

    private struct Unchecked: @unchecked Sendable {
        let work: (Range<Int>) -> Void
    }
}
