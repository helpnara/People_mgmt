import Foundation

/// 지표가 보는 기록 하나 — 날(달력의 날 번호)과 유형만. SwiftData 를 모른다.
///
/// **날 번호**는 사용자 달력에서 어느 기준일부터 센 날 수다. 지표는 날 수로만 셈한다 — 시각 · 시간대 · 달 길이를
/// 들이지 않아야 파이썬 정답표와 같은 답이 나온다 (요구사항 5.5 · ADR-0004).
public struct MetricRecord: Sendable, Equatable {
    public let id: UUID
    public let day: Int
    public let type: String

    public init(id: UUID, day: Int, type: String) {
        self.id = id
        self.day = day
        self.type = type
    }
}

/// 나 ↔ 한 사람의 **관계 돌아보기** (FR-044 · 요구사항 5.5 이인 지표).
///
/// "이 사람이 얼마나 중요한가" 가 아니라 **"내가 이 인연을 어떻게 돌보고 있는가"** 에 답한다 (ADR-0004).
/// 점수 · 순위가 없다. 모든 값은 근거 기록(`…IDs`)을 함께 낸다 — 화면이 눌러서 보여 준다.
/// 오늘보다 뒤의 기록(미래 날짜, D-11)은 셈하지 않는다 — 아직 일어나지 않았다.
public struct DyadMetrics: Sendable, Equatable {
    public enum Trend: String, Sendable { case rising, steady, falling }
    public enum Diversity: String, Sendable { case mostlyOne, several, even }

    public struct TypeCount: Sendable, Equatable {
        public let type: String
        public let count: Int
    }

    /// 지난 기록 수 (오늘까지).
    public var total: Int
    /// 최근 12개월(365일) 안의 기록 수.
    public var lastYear: Int
    /// 마지막 기록에서 오늘까지 날 수.
    public var daysSinceLast: Int?
    /// 인연 기간 — 처음 만난 날(없으면 첫 기록일)부터 마지막 기록일까지 날 수.
    public var spanDays: Int?
    /// 인연 기간이 처음 만난 날에서 시작하는가 (아니면 첫 기록일).
    public var spanFromFirstMeeting: Bool
    /// 한 달(30.4375일)에 몇 번 — 기록 3건부터.
    public var perMonth: Double?
    /// 최근 6개월 대 그 전 6개월 — 기록 4건부터.
    public var trend: Trend?
    public var recentHalf: Int
    public var previousHalf: Int
    /// 기록 유형 분포의 정규화 엔트로피(0~1) — 기록 3건부터.
    public var diversity: Double?
    public var diversityClass: Diversity?
    /// 유형별 건수, 많은 것부터.
    public var typeCounts: [TypeCount]

    // 근거 — 최근 것부터.
    public var pastIDs: [UUID]
    public var lastYearIDs: [UUID]
    public var recentHalfIDs: [UUID]
    public var previousHalfIDs: [UUID]
    public var firstID: UUID?
    public var lastID: UUID?
}

public enum DyadMetricsCalculator {
    public static let frequencyMinimum = 3
    public static let trendMinimum = 4
    public static let diversityMinimum = 3
    /// 한 달의 날 수 (그레고리력 평균).
    public static let daysPerMonth = 30.4375

    /// - Parameters:
    ///   - typeCount: 기록 유형의 가짓수. 다양성을 0~1 로 맞추는 분모다 (요구사항 6.4 의 9가지).
    public static func compute(records: [MetricRecord], firstMetDay: Int?, today: Int, typeCount: Int = 9) -> DyadMetrics {
        // 최근 것부터. 같은 날이면 id 글자 순 — 차례가 늘 같게.
        let past = records.filter { $0.day <= today }
            .sorted { $0.day != $1.day ? $0.day > $1.day : $0.id.uuidString < $1.id.uuidString }
        let lastYear = past.filter { today - $0.day <= 364 }
        let recent = past.filter { today - $0.day <= 181 }
        let previous = past.filter { today - $0.day >= 182 && today - $0.day <= 364 }

        var metrics = DyadMetrics(
            total: past.count, lastYear: lastYear.count, daysSinceLast: nil, spanDays: nil,
            spanFromFirstMeeting: firstMetDay != nil, perMonth: nil, trend: nil,
            recentHalf: recent.count, previousHalf: previous.count, diversity: nil, diversityClass: nil,
            typeCounts: [], pastIDs: past.map(\.id), lastYearIDs: lastYear.map(\.id),
            recentHalfIDs: recent.map(\.id), previousHalfIDs: previous.map(\.id),
            firstID: past.last?.id, lastID: past.first?.id)

        guard let last = past.first, let first = past.last else { return metrics }
        metrics.daysSinceLast = today - last.day
        metrics.spanDays = max(0, last.day - (firstMetDay ?? first.day))

        if past.count >= frequencyMinimum {
            let days = max(Double(today - first.day), daysPerMonth)
            metrics.perMonth = Double(past.count) * daysPerMonth / days
        }
        if past.count >= trendMinimum {
            let diff = recent.count - previous.count
            metrics.trend = diff >= 2 ? .rising : (diff <= -2 ? .falling : .steady)
        }

        var counts: [String: Int] = [:]
        for record in past { counts[record.type, default: 0] += 1 }
        metrics.typeCounts = counts
            .map { DyadMetrics.TypeCount(type: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.type < $1.type }
        if past.count >= diversityMinimum, typeCount > 1 {
            let n = Double(past.count)
            var entropy = 0.0
            for item in metrics.typeCounts {
                let p = Double(item.count) / n
                entropy -= p * log(p)
            }
            let normalized = entropy / log(Double(typeCount))
            metrics.diversity = normalized
            metrics.diversityClass = normalized < 0.25 ? .mostlyOne : (normalized < 0.6 ? .several : .even)
        }
        return metrics
    }
}

/// 지표를 사람이 읽는 말로 (요구사항 5.5 원칙 5 — 중립적 언어). 규칙은 정답표가 대조한다.
public enum MetricText {
    /// 인연 기간 — `12일` · `5개월` · `2년` · `3년 4개월`. 1년 = 365일, 1개월 = 30일로 센다.
    public static func span(days: Int) -> String {
        let days = max(0, days)
        if days < 30 { return "\(days)일" }
        let years = days / 365
        let months = min((days % 365) / 30, 11)
        if years > 0 && months > 0 { return "\(years)년 \(months)개월" }
        if years > 0 { return "\(years)년" }
        return "\(months)개월"
    }

    /// 만남 빈도 — `한 달에 약 2번` · `한 달에 약 1.5번` · `1년에 약 4번` · `1년에 1번 미만`.
    public static func frequency(perMonth: Double) -> String {
        let tenths = Int((perMonth * 10).rounded(.toNearestOrAwayFromZero))
        if tenths >= 10 {
            if tenths % 10 == 0 { return "한 달에 약 \(tenths / 10)번" }
            return "한 달에 약 \(tenths / 10).\(tenths % 10)번"
        }
        let perYear = Int((perMonth * 12).rounded(.toNearestOrAwayFromZero))
        if perYear >= 1 { return "1년에 약 \(perYear)번" }
        return "1년에 1번 미만"
    }

    public static func trend(_ trend: DyadMetrics.Trend) -> String {
        switch trend {
        case .rising: return "늘었습니다"
        case .steady: return "비슷합니다"
        case .falling: return "줄었습니다"
        }
    }

    public static func diversity(_ diversity: DyadMetrics.Diversity) -> String {
        switch diversity {
        case .mostlyOne: return "주로 한 가지"
        case .several: return "몇 가지"
        case .even: return "고르게 여러 가지"
        }
    }
}
