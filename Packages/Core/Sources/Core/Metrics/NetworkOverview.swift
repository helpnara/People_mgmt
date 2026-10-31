import Foundation

/// 전체 보기가 보는 사람 하나 (FR-045). 나는 넣지 않는다.
public struct OverviewPerson: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let firstMetDay: Int?
    /// 오늘까지의 마지막 기록일. 기록이 없으면 nil.
    public let lastDay: Int?

    public init(id: UUID, name: String, firstMetDay: Int?, lastDay: Int?) {
        self.id = id
        self.name = name
        self.firstMetDay = firstMetDay
        self.lastDay = lastDay
    }
}

/// **내 인연 전체** (FR-045 · 요구사항 5.5 전체 지표). 사람을 줄 세우지 않는다 — 목록은 날 순 · 이름 순이다.
public struct NetworkOverview: Sendable, Equatable {
    public var total: Int
    /// 최근 12개월(365일) 안에 기록이 있는 사람 수.
    public var activeCount: Int
    /// 처음 만난 날이 올해인 사람 — 처음 만난 날 최근 것부터.
    public var newThisYearIDs: [UUID]
    /// 마지막 기록이 `neglectDays` 이상 지난 사람 — 오래된 것부터. 화면 이름은 `최근 기록 없음`.
    public var quietIDs: [UUID]
    /// 아직 기록이 없는 사람 — 이름 순.
    public var noRecordIDs: [UUID]

    public static func compute(people: [OverviewPerson], today: Int, yearStart: Int, yearEnd: Int, neglectDays: Int) -> NetworkOverview {
        func nameKey(_ p: OverviewPerson) -> String { NameSort.key(p.name) }
        func byName(_ a: OverviewPerson, _ b: OverviewPerson) -> Bool {
            let ka = nameKey(a), kb = nameKey(b)
            return ka != kb ? ka < kb : a.id.uuidString < b.id.uuidString
        }
        let active = people.filter { p in p.lastDay.map { today - $0 <= 364 } ?? false }
        let newThisYear = people
            .filter { p in p.firstMetDay.map { $0 >= yearStart && $0 <= yearEnd } ?? false }
            .sorted { a, b in
                let da = a.firstMetDay ?? 0, db = b.firstMetDay ?? 0
                return da != db ? da > db : byName(a, b)
            }
        let quiet = people
            .filter { p in p.lastDay.map { today - $0 >= neglectDays } ?? false }
            .sorted { a, b in
                let da = a.lastDay ?? 0, db = b.lastDay ?? 0
                return da != db ? da < db : byName(a, b)
            }
        let noRecord = people.filter { $0.lastDay == nil }.sorted(by: byName)
        return NetworkOverview(total: people.count, activeCount: active.count,
                               newThisYearIDs: newThisYear.map(\.id), quietIDs: quiet.map(\.id),
                               noRecordIDs: noRecord.map(\.id))
    }
}

/// **특성 분포** (사용자 요청 · 6번째 묶음) — 관계 유형 · 알게 된 경로 · 소속 · 태그가 어떻게 나뉘는가.
/// 칸마다 그 사람들(근거)을 함께 낸다.
public struct TraitBucket: Sendable, Equatable {
    public let label: String
    /// 이 칸에 든 사람 수 (한 사람은 한 칸에 한 번).
    public let count: Int
    /// 이 칸의 사람들 — 들어온 차례.
    public let ids: [UUID]
    /// 값이 없는 사람들의 칸.
    public let isUnspecified: Bool
    /// 줄 수를 넘어 하나로 묶은 칸.
    public let isRest: Bool
}

public enum TraitDistribution {
    public static let unspecifiedLabel = "미지정"

    /// - Parameters:
    ///   - items: 사람마다 값들 (태그처럼 여럿일 수 있다). 빈 값은 버린다. 같은 값(대소문자 · 공백 무시)은 한 칸.
    ///   - limit: 보여 줄 칸 수. 넘으면 앞의 `limit - 1` 칸을 두고 나머지를 `그 밖에 N가지` 로 묶는다.
    public static func buckets(_ items: [(id: UUID, values: [String])], limit: Int = 8) -> [TraitBucket] {
        var labels: [String: String] = [:]       // 열쇠 → 처음 본 글자
        var members: [String: [UUID]] = [:]
        var order: [String] = []
        var unspecified: [UUID] = []
        for item in items {
            var seen = Set<String>()
            for raw in item.values {
                let value = TextNormalization.normalized(raw)
                guard !value.isEmpty else { continue }
                let key = NameSort.key(value)
                guard seen.insert(key).inserted else { continue }
                if labels[key] == nil {
                    labels[key] = value
                    order.append(key)
                }
                members[key, default: []].append(item.id)
            }
            if seen.isEmpty { unspecified.append(item.id) }
        }
        let sorted = order.sorted { a, b in
            let ca = members[a]?.count ?? 0, cb = members[b]?.count ?? 0
            return ca != cb ? ca > cb : a < b
        }
        var result: [TraitBucket] = []
        let keep = sorted.count > limit ? max(limit - 1, 0) : sorted.count
        for key in sorted.prefix(keep) {
            let ids = members[key] ?? []
            result.append(TraitBucket(label: labels[key] ?? key, count: ids.count, ids: ids, isUnspecified: false, isRest: false))
        }
        if sorted.count > keep {
            let restKeys = Set(sorted.dropFirst(keep))
            var ids: [UUID] = []
            var seen = Set<UUID>()
            for item in items {
                let keys = item.values.map { NameSort.key(TextNormalization.normalized($0)) }
                if keys.contains(where: restKeys.contains), seen.insert(item.id).inserted { ids.append(item.id) }
            }
            result.append(TraitBucket(label: "그 밖에 \(restKeys.count)가지", count: ids.count, ids: ids, isUnspecified: false, isRest: true))
        }
        if !unspecified.isEmpty {
            result.append(TraitBucket(label: unspecifiedLabel, count: unspecified.count, ids: unspecified, isUnspecified: true, isRest: false))
        }
        return result
    }
}
