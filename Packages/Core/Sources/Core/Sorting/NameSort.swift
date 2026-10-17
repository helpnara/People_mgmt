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

    public static func areInIncreasingOrder(
        _ lhs: (name: String, createdAt: Date),
        _ rhs: (name: String, createdAt: Date)
    ) -> Bool {
        let left = key(lhs.name)
        let right = key(rhs.name)
        if left != right { return left < right }
        return lhs.createdAt < rhs.createdAt
    }
}
