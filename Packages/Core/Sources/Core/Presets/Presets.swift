import Foundation

/// 관계 유형 · 알게 된 경로 선택지 (요구사항 6.3).
///
/// 저장은 **표시 라벨 문자열**로 한다 — 선택지와 직접 입력을 구분하지 않는다.
/// 그래야 P2 사용자 정의 유형으로 갈 때 마이그레이션이 없다.
///
/// **`기타` 는 두지 않는다 (이슈 13).** 대신 `직접 입력` 으로 쓴 값이 다음 입력부터 선택지로 붙는다 — `choices`.
/// 빌드 6 까지 `기타` 로 저장된 사람은 그 값이 직접 입력처럼 선택지에 붙어 그대로 보인다.
public enum RelationshipPresets {
    public static let relationshipTypes = [
        "동료", "상사", "후배", "고객", "협력사", "멘토", "멘티", "친구", "가족", "지인",
    ]
    public static let metThroughOptions = [
        "직장", "프로젝트", "소개", "행사·교육", "학교", "온라인", "가족·친척", "동호회·모임",
    ]

    /// 선택지 = 기본값 + 이미 직접 입력해 쓴 값. 쓴 값은 **많이 쓴 것부터**, 같으면 이름 열쇠 순, 그다음 글자 순.
    /// 기본값과 같은 값 · 빈 값은 붙이지 않는다. 화면 본문이 아니라 화면을 열 때 한 번 부른다.
    public static func choices(presets: [String], used: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for raw in used {
            let value = TextNormalization.normalized(raw)
            guard !value.isEmpty, !presets.contains(value) else { continue }
            counts[value, default: 0] += 1
        }
        let extras = counts
            .map { (value: $0.key, count: $0.value, key: NameSort.key($0.key)) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.key != rhs.key { return lhs.key < rhs.key }
                return lhs.value < rhs.value
            }
            .map(\.value)
        return presets + extras
    }
    /// 이 값을 고르면 **소개한 사람** 선택이 나타난다 (FR-043).
    public static let introducedLabel = "소개"
}

/// 기록 유형 (요구사항 6.4). 키는 영문 고정값으로 저장하고 라벨은 화면에서 쓴다.
/// 모르는 키를 읽으면 `other` 로 보인다.
public struct RecordType: Equatable, Hashable, Sendable, Identifiable {
    public let key: String
    public let label: String
    public let symbol: String

    public var id: String { key }

    public static let all: [RecordType] = [
        RecordType(key: "conversation", label: "대화", symbol: "bubble.left.and.bubble.right"),
        RecordType(key: "meal", label: "식사", symbol: "fork.knife"),
        RecordType(key: "meeting", label: "회의", symbol: "person.3"),
        RecordType(key: "collaboration", label: "프로젝트·협업", symbol: "briefcase"),
        RecordType(key: "trip", label: "출장", symbol: "airplane"),
        RecordType(key: "event", label: "교육·행사", symbol: "graduationcap"),
        RecordType(key: "help", label: "도움 주고받음", symbol: "hand.raised"),
        RecordType(key: "contact", label: "연락", symbol: "phone"),
        RecordType(key: "other", label: "기타", symbol: "ellipsis.circle"),
    ]

    public static let defaultKey = "conversation"

    public static func named(_ key: String) -> RecordType {
        all.first { $0.key == key } ?? all.last!
    }
}
