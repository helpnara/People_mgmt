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
}
