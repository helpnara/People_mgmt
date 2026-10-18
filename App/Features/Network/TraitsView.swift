import Core
import SwiftUI

/// **특성 분포** (6번째 묶음) — 관계 유형 · 알게 된 경로 · 소속 · 태그가 어떻게 나뉘는가.
/// 한 색 막대에 이름과 사람 수를 적는다. 칸을 누르면 그 사람들.
struct TraitsView: View {
    let snapshot: NetworkSnapshot

    fileprivate struct Trait: Identifiable {
        let title: String
        let field: FillField
        let buckets: [TraitBucket]
        var id: String { title }
    }

    @State private var traits: [Trait] = []

    var body: some View {
        List {
            ForEach(traits) { trait in
                Section {
                    let maximum = max(trait.buckets.map(\.count).max() ?? 1, 1)
                    ForEach(Array(trait.buckets.enumerated()), id: \.offset) { _, bucket in
                        // 값으로 연다 (이슈 16). 미지정 칸은 누르면 바로 편집 — 채울 것 목록이다.
                        NavigationLink(value: PeopleListRoute(
                            title: "\(trait.title) · \(bucket.label)",
                            ids: snapshot.peopleByName(bucket.ids).map(\.id),
                            fill: bucket.isUnspecified ? trait.field : nil)) {
                            BucketRow(bucket: bucket, maximum: maximum, total: snapshot.people.count)
                        }
                    }
                } header: {
                    Text(trait.title)
                } footer: {
                    Text(coverage(trait))
                }
            }
            Section {
                RecordedScopeNotice()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 나누기는 자료가 바뀔 때 한 번 — 본문에서 사람 전원을 훑지 않는다 (CLAUDE.md).
        .task(id: snapshot.generation) {
            let people = snapshot.people
            traits = [
                Trait(title: "관계 유형", field: .relationshipType, buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.relationshipType ?? ""]) })),
                Trait(title: "알게 된 경로", field: .metThrough, buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.metThrough ?? ""]) })),
                Trait(title: "소속", field: .organization, buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.organization ?? ""]) })),
                Trait(title: "태그", field: .tags, buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: $0.tags) })),
            ]
        }
    }
}

private extension TraitsView {
    /// 이 칸을 적은 사람이 몇 명인가 — 분포가 얼마나 믿을 만한지의 조건 (사용자 요청 · 2026-10-18).
    func coverage(_ trait: Trait) -> String {
        let total = snapshot.people.count
        let missing = trait.buckets.first(where: \.isUnspecified)?.count ?? 0
        let filled = total - missing
        if missing == 0 { return "\(total)명 모두 적었습니다." }
        return "적은 사람 \(filled)명 / \(total)명. 미지정 \(missing)명을 사람 편집에서 채우면 분포가 정확해집니다."
    }
}

private struct BucketRow: View {
    let bucket: TraitBucket
    let maximum: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(bucket.label)
                    .font(.scaled(15, weight: bucket.isUnspecified || bucket.isRest ? .regular : .medium))
                    .foregroundStyle(bucket.isUnspecified || bucket.isRest ? Color.muted : Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(bucket.count)명 · \(percent)%")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.rule.opacity(0.5))
                    Capsule()
                        .fill(bucket.isUnspecified || bucket.isRest ? Color.faint : Color.accent)
                        .frame(width: max(proxy.size.width * CGFloat(bucket.count) / CGFloat(maximum), 4))
                }
            }
            .frame(height: Font.scaledLength(6))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(bucket.count) * 100 / Double(total)).rounded())
    }
}
