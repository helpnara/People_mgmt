import SwiftData
import SwiftUI

/// **견본으로 둘러보기** (D-55 · 2026-10-22 사용자 — 심사와 처음 쓰는 사람을 위해).
///
/// - 사람이 하나도 없을 때 첫 화면에서 연다. 지어낸 사람 · 기록 · 모임을 **메모리 저장소에만** 채운다 —
///   진짜 저장소 · iCloud 와 섞이지 않고, 끝내거나 앱을 닫으면 사라진다 (CLAUDE.md §2 · 견본은 인메모리에만).
/// - 둘러보는 동안 사람 목록 첫 칸에 띠가 있고, 띠의 `끝내기` 로 내 자료로 돌아간다(아이패드는 목록 칸).
/// - 둘러보는 동안에는 알림을 다시 걸지 않고(견본 사람의 생일로 내 알림을 덮지 않게), 지난 유형 · 장소도 기억하지 않는다.
@MainActor
@Observable
final class DemoMode {
    static let shared = DemoMode()

    /// 둘러보는 동안의 메모리 저장소. `nil` 이면 내 자료.
    private(set) var container: ModelContainer?

    var isActive: Bool { container != nil }

    private init() {}

    func start() {
        guard container == nil else { return }
        do {
            let demo = try Persistence.makeContainer(inMemory: true)
            SampleData.seed(into: demo.mainContext, communities: true)
            container = demo
        } catch {
            // 메모리 저장소를 못 여는 일은 스키마가 깨졌을 때뿐이다 — CI 가 먼저 잡는다. 둘러보기만 열리지 않는다.
            container = nil
        }
    }

    func end() {
        // 되돌리기 띠가 견본 저장소를 붙잡고 있으면 먼저 끝낸다.
        DeletionUndo.shared.finish()
        container = nil
    }
}

/// 둘러보는 동안 사람 목록 첫 칸에 — 견본이라는 것과 끝내는 단추.
struct DemoBanner: View {
    let demo: DemoMode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("견본 둘러보기 중")
                    .font(.scaled(14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text("지어낸 사람들입니다. 여기서 고친 것은 저장되지 않습니다.")
                    .font(.scaled(12))
                    .foregroundStyle(Color.muted)
            }
            Spacer(minLength: 8)
            Button("끝내기") { demo.end() }
                .font(.scaled(14, weight: .semibold))
                .buttonStyle(.bordered)
                .tint(Color.accent)
                .accessibilityHint("견본을 닫고 내 자료로 돌아갑니다")
        }
        .padding(.vertical, 4)
    }
}
