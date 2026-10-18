import Foundation

/// 사람 목록의 **최근 기록순** (FR-027). 마지막 기록이 최근인 사람이 먼저, 기록이 없는 사람은 뒤에 이름순.
public enum RecencySort {
    public static func areInIncreasingOrder(
        _ lhs: (lastRecordAt: Date?, name: String, createdAt: Date),
        _ rhs: (lastRecordAt: Date?, name: String, createdAt: Date)
    ) -> Bool {
        switch (lhs.lastRecordAt, rhs.lastRecordAt) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return NameSort.areInIncreasingOrder((name: lhs.name, createdAt: lhs.createdAt),
                                                 (name: rhs.name, createdAt: rhs.createdAt))
        }
    }
}
