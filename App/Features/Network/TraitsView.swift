import Core
import SwiftUI

/// **특성 분포** (6번째 묶음) — 관계 유형 · 알게 된 경로 · 소속 · 태그가 어떻게 나뉘는가.
/// 한 색 막대에 이름과 사람 수를 적는다. 칸을 누르면 그 사람들.
struct TraitsView: View {
    let snapshot: NetworkSnapshot

    private struct Trait: Identifiable {
        let title: String
        let buckets: [TraitBucket]
        var id: String { title }
    }

    @State private var traits: [Trait] = []

    var body: some View {
        List {
            ForEach(traits) { trait in
                Section(trait.title) {
                    let maximum = max(trait.buckets.map(\.count).max() ?? 1, 1)
                    ForEach(Array(trait.buckets.enumerated()), id: \.offset) { _, bucket in
                        NavigationLink {
                            PeopleByIDsView(title: "\(trait.title) · \(bucket.label)", people: snapshot.peopleByName(bucket.ids))
                        } label: {
                            BucketRow(bucket: bucket, maximum: maximum, total: snapshot.people.count)
                        }
                    }
                }
            }
            Section {
                RecordedScopeNotice()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 나누기는 자료가 바뀔 때 한 번 — 본문에서 사람 전원을 훑지 않는다 (CLAUDE.md).
        .task(id: snapshot.people.count) {
            let people = snapshot.people
            traits = [
                Trait(title: "관계 유형", buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.relationshipType ?? ""]) })),
                Trait(title: "알게 된 경로", buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.metThrough ?? ""]) })),
                Trait(title: "소속", buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: [$0.organization ?? ""]) })),
                Trait(title: "태그", buckets: TraitDistribution.buckets(people.map { (id: $0.id, values: $0.tags) })),
            ]
        }
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
