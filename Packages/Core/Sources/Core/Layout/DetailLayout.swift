import Foundation

/// 사람 상세에서 차례를 바꾸거나 숨길 수 있는 칸 (D-56 · 2026-10-27 사용자).
/// 맨 위 칸(사진 · 이름 · 소속 · 연락 수단 · 생일)은 늘 맨 위라 여기에 들지 않는다.
public enum DetailSection: String, CaseIterable, Sendable, Identifiable {
    case card
    case firstEncounter
    case review
    case introduced
    case acquaintances
    case timeline

    public var id: String { rawValue }

    /// 설정 · 상세에 보이는 이름 — 상세의 칸 머리와 같은 말.
    public var label: String {
        switch self {
        case .card: return "명함"
        case .firstEncounter: return "첫 인연"
        case .review: return "관계 돌아보기"
        case .introduced: return "소개한 인연"
        case .acquaintances: return "아는 사이"
        case .timeline: return "타임라인"
        }
    }
}

/// **사람 상세의 칸 차례 · 보이기** (D-56).
///
/// - 이 기기에만 둔다 — `UserDefaults` 의 글 하나(`stored`). 칸 이름을 쉼표로 잇고, 숨긴 칸은 앞에 `-`.
/// - 읽을 때 모르는 이름 · 겹친 이름은 버리고, 빠진 칸(앞으로 더해질 칸)은 보이게 처음 차례대로 끝에 붙인다.
/// - 숨겨도 자료는 그대로다 — 화면에만 안 보인다. 정답표 `detailLayout` · `detailMove` 가 대조한다.
public struct DetailLayout: Equatable, Sendable {
    public private(set) var order: [DetailSection]
    public private(set) var hidden: Set<DetailSection>

    public static let standard = DetailLayout(stored: nil)

    public init(stored: String?) {
        var order: [DetailSection] = []
        var hidden: Set<DetailSection> = []
        for raw in (stored ?? "").split(separator: ",", omittingEmptySubsequences: true) {
            var token = raw.trimmingCharacters(in: .whitespaces)
            let hide = token.hasPrefix("-")
            if hide { token = String(token.dropFirst()).trimmingCharacters(in: .whitespaces) }
            guard let section = DetailSection(rawValue: token), !order.contains(section) else { continue }
            order.append(section)
            if hide { hidden.insert(section) }
        }
        for section in DetailSection.allCases where !order.contains(section) {
            order.append(section)
        }
        self.order = order
        self.hidden = hidden
    }

    /// 저장할 글.
    public var stored: String {
        order.map { hidden.contains($0) ? "-" + $0.rawValue : $0.rawValue }.joined(separator: ",")
    }

    /// 상세에 그릴 차례 — 숨긴 칸을 뺀다.
    public var visible: [DetailSection] { order.filter { !hidden.contains($0) } }

    public func isHidden(_ section: DetailSection) -> Bool { hidden.contains(section) }

    public mutating func setHidden(_ section: DetailSection, _ hide: Bool) {
        if hide { hidden.insert(section) } else { hidden.remove(section) }
    }

    /// 목록에서 끌어 옮긴 것 — `source` 의 칸들을 빼서 `destination`(옮기기 전 자리 번호) 앞에 넣는다.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().compactMap { order.indices.contains($0) ? order[$0] : nil }
        var remaining = order.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: max(0, min(insertAt, remaining.count)))
        order = remaining
    }
}
