import Foundation

/// 사람 목록의 정렬 (요구사항 6.7).
///
/// 이름 열쇠(NFC · 소문자)로 먼저, 같으면 만든 시각으로. **정렬 규칙은 여기 한 곳**이고
/// 목록 · 검색 결과 · 선택기가 전부 이것을 부른다 — 같은 것을 재는 곳이 둘이면 갈린다.
///
/// 한글 음절은 유니코드 순서가 곧 가나다순이라 열쇠 비교로 충분하다. 영문 이름은
/// 한글 앞에 온다. 로케일 비교(`localizedStandardCompare`)를 안 쓰는 이유는 리눅스
/// 러너의 파이썬 정답표와 **같은 답**이 나와야 하기 때문이다.
public enum NameSort {

    public static func key(_ name: String) -> String {
        TextNormalization.folded(name)
    }

    /// 열쇠를 이미 만든 두 항목의 차례. 규칙은 이 함수 하나다.
    static func precedes(_ lhs: (key: String, createdAt: Date), _ rhs: (key: String, createdAt: Date)) -> Bool {
        if lhs.key != rhs.key { return lhs.key < rhs.key }
        return lhs.createdAt < rhs.createdAt
    }

    public static func areInIncreasingOrder(
        _ lhs: (name: String, createdAt: Date),
        _ rhs: (name: String, createdAt: Date)
    ) -> Bool {
        precedes((key(lhs.name), lhs.createdAt), (key(rhs.name), rhs.createdAt))
    }

    /// 많은 항목을 정렬할 때 — 열쇠를 **항목마다 한 번만** 만든다 (이슈 6). 비교마다 만들면 5,000명에서 0.6초가 넘었다.
    public static func sorted<T>(_ items: [T], name: (T) -> String, createdAt: (T) -> Date) -> [T] {
        items.map { (key: key(name($0)), createdAt: createdAt($0), item: $0) }
            .sorted { precedes(($0.key, $0.createdAt), ($1.key, $1.createdAt)) }
            .map(\.item)
    }
}
