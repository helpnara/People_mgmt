import Foundation

/// **입력 상태 · 준비도** (D-31 · docs/input-readiness-review.md).
///
/// 앱이 알려 줄 수 있는 것은 전부 입력에서 나온다. 기능마다 "뜻을 갖는 최소 조건" 을 두고, 지금 입력이 거기까지
/// 얼마나 왔는지(준비됨 · 거의 · 아직)와 **무엇을 얼마나 더 적으면 되는지**를 말한다.
/// 점수를 매기는 대상은 **사람이 아니라 내 입력**이다 — 종합 점수 하나로 묶지 않는다 (ADR-0004).
public struct ReadinessInput: Sendable, Equatable {
    public var people: Int
    public var withFirstMet: Int
    public var withRelationshipType: Int
    public var withMetThrough: Int
    public var withRecords: Int
    public var strongEdges: Int
    public var linkedPeople: Int

    public init(people: Int, withFirstMet: Int, withRelationshipType: Int, withMetThrough: Int,
                withRecords: Int, strongEdges: Int, linkedPeople: Int) {
        self.people = people
        self.withFirstMet = withFirstMet
        self.withRelationshipType = withRelationshipType
        self.withMetThrough = withMetThrough
        self.withRecords = withRecords
        self.strongEdges = strongEdges
        self.linkedPeople = linkedPeople
    }
}

public struct ReadinessItem: Sendable, Equatable, Identifiable {
    public enum Feature: String, Sendable, CaseIterable {
        case traits, firstMet, review, graph, groups
    }
    public enum Level: String, Sendable {
        case ready, almost, notYet
    }

    public let feature: Feature
    public let level: Level
    /// 0~1 — 조건까지 얼마나 왔는가 (막대).
    public let progress: Double
    /// 지금 상태 한 줄.
    public let current: String
    /// 무엇을 얼마나 더 하면 되는가 — 다 되면 무엇이 보이는가.
    public let hint: String

    public var id: String { feature.rawValue }
}

public enum InputReadiness {
    // 조건 (D-31 — 제안 그대로 시작, 쓰면서 조정).
    // 비율은 **정수 퍼센트**로 둔다 — `10 × 0.3` 을 올림하면 4 가 된다(0.3 이 이진수로 딱 떨어지지 않는다).
    public static let traitsMinimumPeople = 20
    public static let traitsCoverage = 80
    public static let firstMetCoverage = 50
    public static let reviewCoverage = 50
    public static let graphLinkedShare = 30
    public static let groupsMinimumStrongEdges = 20
    public static let groupsMinimumLinkedPeople = 10
    /// 거의 — 조건의 이만큼은 왔다.
    public static let almostAt = 0.6

    public static func title(_ feature: ReadinessItem.Feature) -> String {
        switch feature {
        case .traits: return "특성 분포"
        case .firstMet: return "올해 처음 만남"
        case .review: return "돌아보기"
        case .graph: return "관계도"
        case .groups: return "모임 찾기"
        }
    }

    public static func evaluate(_ input: ReadinessInput) -> [ReadinessItem] {
        let n = input.people
        /// 조건 비율(정수 %)까지 얼마나 왔나 — 0~1 로 자른다.
        func toward(_ count: Int, _ percentTarget: Int) -> Double {
            n > 0 ? min(Double(count * 100) / Double(n * percentTarget), 1) : 0
        }
        func percent(_ count: Int) -> Int { n > 0 ? (count * 200 + n) / (2 * n) : 0 }   // 반올림 정수 %
        /// 비율에 닿으려면 몇 명이 더 필요한가 — 정수 올림.
        func need(_ count: Int, _ percentTarget: Int) -> Int { max((n * percentTarget + 99) / 100 - count, 0) }
        func level(_ progress: Double) -> ReadinessItem.Level {
            progress >= 1 ? .ready : (progress >= almostAt ? .almost : .notYet)
        }
        var items: [ReadinessItem] = []
        let empty = "사람을 적으면 시작합니다."

        // 특성 분포 — 사람 수와, 관계 유형 · 알게 된 경로 중 덜 채운 쪽.
        let typed = min(input.withRelationshipType, input.withMetThrough)
        let traitsProgress = min(min(Double(n) / Double(traitsMinimumPeople), toward(typed, traitsCoverage)), 1)
        let traitsHint: String
        if n < traitsMinimumPeople {
            traitsHint = "사람을 \(traitsMinimumPeople - n)명 더 적으면 분포가 뜻을 갖습니다."
        } else if need(typed, traitsCoverage) > 0 {
            traitsHint = "관계 유형 · 알게 된 경로를 \(need(typed, traitsCoverage))명 더 채우면 분포가 정확해집니다."
        } else {
            traitsHint = "내 인연의 구성이 믿을 만하게 보입니다."
        }
        items.append(ReadinessItem(feature: .traits, level: level(traitsProgress), progress: traitsProgress,
                                   current: "사람 \(n)명 · 관계 유형과 경로를 적은 사람 \(percent(typed))%",
                                   hint: traitsHint))

        // 올해 처음 만남 — 처음 만난 날.
        let firstMetProgress = toward(input.withFirstMet, firstMetCoverage)
        let firstMetNeed = need(input.withFirstMet, firstMetCoverage)
        items.append(ReadinessItem(feature: .firstMet, level: level(firstMetProgress), progress: firstMetProgress,
                                   current: "처음 만난 날을 적은 사람 \(input.withFirstMet)명 / \(n)명",
                                   hint: n == 0 ? empty : firstMetNeed > 0 ? "처음 만난 날을 \(firstMetNeed)명 더 적으면 올해 처음 만남과 인연 기간이 정확해집니다."
                                                          : "올해 처음 만난 사람과 인연 기간이 정확하게 보입니다."))

        // 돌아보기 — 기록이 있는 사람.
        let reviewProgress = toward(input.withRecords, reviewCoverage)
        let reviewNeed = need(input.withRecords, reviewCoverage)
        items.append(ReadinessItem(feature: .review, level: level(reviewProgress), progress: reviewProgress,
                                   current: "기록이 있는 사람 \(input.withRecords)명 / \(n)명",
                                   hint: n == 0 ? empty : reviewNeed > 0 ? "\(reviewNeed)명과의 기록을 더 남기면 최근 기록 없음 · 관계 돌아보기가 뜻을 갖습니다."
                                                        : "오래 기록이 없는 인연과 사람마다의 흐름이 보입니다."))

        // 관계도 — 서로 이어진 사람.
        let graphProgress = toward(input.linkedPeople, graphLinkedShare)
        let graphNeed = need(input.linkedPeople, graphLinkedShare)
        items.append(ReadinessItem(feature: .graph, level: level(graphProgress), progress: graphProgress,
                                   current: "서로 이어진 사람 \(input.linkedPeople)명 / \(n)명 (\(percent(input.linkedPeople))%)",
                                   hint: n == 0 ? empty : graphNeed > 0 ? "\(graphNeed)명을 더 이으면 관계도에 모양이 드러납니다 — 아는 사이를 고르거나, 기록에 함께한 사람을 두 명 이상 넣으세요."
                                                       : "사람들 사이의 연결이 관계도에 드러납니다."))

        // 모임 찾기 — 진한 선 · 이어진 사람.
        let groupsProgress = min(min(Double(input.strongEdges) / Double(groupsMinimumStrongEdges),
                                     Double(input.linkedPeople) / Double(groupsMinimumLinkedPeople)), 1)
        let edgesShort = max(groupsMinimumStrongEdges - input.strongEdges, 0)
        let linkedShort = max(groupsMinimumLinkedPeople - input.linkedPeople, 0)
        let groupsHint: String
        if edgesShort > 0 || linkedShort > 0 {
            var parts: [String] = []
            if edgesShort > 0 { parts.append("진한 선 \(edgesShort)개") }
            if linkedShort > 0 { parts.append("이어진 사람 \(linkedShort)명") }
            groupsHint = parts.joined(separator: " · ") + " 더 있으면 모임(그룹)을 찾아 관계도에 묶어 보여 줍니다."
        } else {
            groupsHint = "모임(그룹)을 찾을 만큼 연결이 쌓였습니다."
        }
        items.append(ReadinessItem(feature: .groups, level: level(groupsProgress), progress: groupsProgress,
                                   current: "진한 선 \(input.strongEdges)개 · 이어진 사람 \(input.linkedPeople)명",
                                   hint: groupsHint))
        return items
    }

    /// 목록 맨 위 한 줄 — `5가지 중 2가지 준비됨 · 다음: …`. 다음은 아직인 것 중 앞의 것 (특성 → 처음 만난 날 → 돌아보기 → 관계도 → 모임).
    public static func summary(_ items: [ReadinessItem]) -> String {
        let ready = items.filter { $0.level == .ready }.count
        let head = "\(items.count)가지 중 \(ready)가지 준비됨"
        guard let next = items.first(where: { $0.level != .ready }) else { return head + " · 모두 준비됨" }
        return head + " · 다음: " + title(next.feature)
    }
}
