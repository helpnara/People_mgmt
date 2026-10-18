import Foundation

/// 사람 목록의 **최근 기록순** (FR-027). 마지막 기록이 최근인 사람이 먼저, 기록이 없는 사람은 뒤에 이름순.
public enum RecencySort {

    static func precedes(
        _ lhs: (last: Date?, key: String, createdAt: Date),
        _ rhs: (last: Date?, key: String, createdAt: Date)
    ) -> Bool {
        switch (lhs.last, rhs.last) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return NameSort.precedes((lhs.key, lhs.createdAt), (rhs.key, rhs.createdAt))
        }
    }

    public static func areInIncreasingOrder(
        _ lhs: (lastRecordAt: Date?, name: String, createdAt: Date),
        _ rhs: (lastRecordAt: Date?, name: String, createdAt: Date)
    ) -> Bool {
        precedes((lhs.lastRecordAt, NameSort.key(lhs.name), lhs.createdAt),
                 (rhs.lastRecordAt, NameSort.key(rhs.name), rhs.createdAt))
    }

    /// 마지막 기록일과 이름 열쇠를 **항목마다 한 번만** 구해 정렬한다 (이슈 6).
    public static func sorted<T>(_ items: [T], lastRecordAt: (T) -> Date?, name: (T) -> String, createdAt: (T) -> Date) -> [T] {
        items.map { (last: lastRecordAt($0), key: NameSort.key(name($0)), createdAt: createdAt($0), item: $0) }
            .sorted { precedes(($0.last, $0.key, $0.createdAt), ($1.last, $1.key, $1.createdAt)) }
            .map(\.item)
    }
}
