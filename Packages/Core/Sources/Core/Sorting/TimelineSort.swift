import Foundation

/// 타임라인의 정렬 (요구사항 6.7): 발생 날짜 최신순, 같은 날짜는 만든 시각 역순.
/// 정렬 규칙은 여기 한 곳이다 — 사람 상세 · 검색 근거 · 스크린샷 인자가 전부 이것을 부른다.
public enum TimelineSort {
    public static func areInIncreasingOrder(
        _ lhs: (occurredAt: Date, createdAt: Date),
        _ rhs: (occurredAt: Date, createdAt: Date)
    ) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return lhs.createdAt > rhs.createdAt
    }

    /// 시각까지 (8판 · D-63): 같은 날짜 안에서는 **시각이 늦은 것 먼저**, 시각이 없는 기록은 그날의 끝이라 그날 맨 위.
    /// 그다음은 만든 시각 역순. 시각이 둘 다 없으면 위의 두 칸짜리와 같다.
    public static func areInIncreasingOrder(
        _ lhs: (occurredAt: Date, minute: Int?, createdAt: Date),
        _ rhs: (occurredAt: Date, minute: Int?, createdAt: Date)
    ) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        let l = TimeOfDay.sortKey(lhs.minute), r = TimeOfDay.sortKey(rhs.minute)
        if l != r { return l > r }
        return lhs.createdAt > rhs.createdAt
    }
}
