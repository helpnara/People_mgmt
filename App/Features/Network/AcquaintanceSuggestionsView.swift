import Core
import SwiftData
import SwiftUI

/// 아는 사이 후보 목록을 여는 길 (빌드 16 · 조사 보고서 지금 5). 목적지는 뿌리(`PeopleListView`) 한 곳에 둔다 (이슈 16).
struct AcquaintanceSuggestionRoute: Hashable {
    struct Item: Hashable, Sendable, Identifiable {
        let a: UUID
        let b: UUID
        let aName: String
        let bName: String
        /// `함께한 기록 3건` · `둘 다 바다 님이 소개` — 사실만, 점수 없이.
        let evidence: String
        var id: String { AcquaintanceSuggestions.pairKey(a, b) }
    }

    let items: [Item]

    static func evidence(together: Int, introducer: String?) -> String {
        var parts: [String] = []
        if together > 0 { parts.append("함께한 기록 \(together)건") }
        if let introducer { parts.append("둘 다 \(introducer) 님이 소개") }
        return parts.joined(separator: " · ")
    }
}

/// `아니요` 한 쌍 — 다시 묻지 않는다. 이 기기에만 둔다 (백업에는 넣지 않는다 · 사람 · 기록이 아니라 앱의 기억).
enum DeclinedPairs {
    private static let key = "declinedAcquaintancePairs"

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ a: UUID, _ b: UUID) {
        var stored = load()
        let pair = AcquaintanceSuggestions.pairKey(a, b)
        guard !stored.contains(pair) else { return }
        stored.append(pair)
        UserDefaults.standard.set(stored, forKey: key)
    }
}

/// **아는 사이 후보** — 같은 기록에 함께 나온 사람 · 같은 사람이 소개한 사람끼리 "아는 사이로 이을까요?".
///
/// 자동으로 잇지 않는다. `잇기` 를 누른 쌍만 잇고, `아니요` 한 쌍은 다시 묻지 않는다. 누가 더 가까운지 점수를 보이지 않는다.
struct AcquaintanceSuggestionsView: View {
    let route: AcquaintanceSuggestionRoute

    @Environment(\.modelContext) private var context
    /// 이 화면에서 잇거나 아니요 한 쌍 — 줄은 남겨 두고 결과만 적는다 (줄이 갑자기 사라지면 다음 줄을 잘못 누른다).
    @State private var done: [String: String] = [:]
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(route.items) { item in
                    row(item)
                }
            } footer: {
                Text("같은 기록에 함께 나온 사람, 같은 사람이 소개한 사람끼리 모았습니다. 잇기를 누르면 두 사람이 아는 사이가 되어 관계도에 진한 선이 생기고, 아니요는 다시 묻지 않습니다. 자동으로 잇지는 않습니다.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("아는 사이 후보")
        .navigationBarTitleDisplayMode(.inline)
        .alert("잇지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(_ item: AcquaintanceSuggestionRoute.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.aName) · \(item.bName)")
                .font(.scaled(16, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(item.evidence)
                .font(.scaled(13))
                .foregroundStyle(Color.muted)
            if let result = done[item.id] {
                Text(result)
                    .font(.scaled(14, weight: .medium))
                    .foregroundStyle(Color.accent)
            } else {
                AdaptiveStack(spacing: 12) {
                    Button {
                        link(item)
                    } label: {
                        Text("잇기").font(.scaled(15, weight: .semibold)).tapTarget()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accent)
                    Button {
                        DeclinedPairs.add(item.a, item.b)
                        done[item.id] = "다시 묻지 않습니다"
                    } label: {
                        Text("아니요").font(.scaled(15)).tapTarget()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.muted)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 누를 때 그 두 사람만 찾는다 — 본문에서 저장소를 읽지 않는다 (CLAUDE.md).
    private func link(_ item: AcquaintanceSuggestionRoute.Item) {
        let first = item.a, second = item.b
        do {
            let a = try context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.uuid == first })).first
            let b = try context.fetch(FetchDescriptor<Person>(predicate: #Predicate<Person> { $0.uuid == second })).first
            guard let a, let b else {
                done[item.id] = "찾을 수 없는 사람입니다"
                return
            }
            try PersonStore(context: context).link(a, b)
            done[item.id] = "아는 사이로 이었습니다"
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}
