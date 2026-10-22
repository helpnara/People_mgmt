import SwiftUI

/// 앱의 뿌리. 탭바 없이 스택 하나다 (요구사항 4.1). 화면 깊이는 목록 → 사람 상세 → 기록 상세 셋을 넘지 않는다.
struct RootView: View {
    let arguments: LaunchArguments
    let isSampleData: Bool
    /// 견본 둘러보기 중 (D-55) — 위에 띠, 알림은 다시 걸지 않는다.
    var isDemo = false

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    private let lock = AppLock.shared
    private let deletionUndo = DeletionUndo.shared

    var body: some View {
        PeopleListView(arguments: arguments, isSampleData: isSampleData, isDemo: isDemo)
            .safeAreaInset(edge: .top, spacing: 0) {
                if isDemo { DemoBanner(demo: DemoMode.shared) }
            }
            // 삭제 실행취소 (FR-031) — 지운 직후 5초 동안 아래에 `되돌리기`.
            .overlay(alignment: .bottom) {
                DeletionUndoBanner(undo: deletionUndo)
                    .animation(.easeOut(duration: 0.2), value: deletionUndo.pending)
            }
            // 앱 잠금 (FR-029) — 가리개 창이 뜨기 전 첫 장면도 가린다.
            .overlay {
                if lock.isLocked { LockScreen(lock: lock) }
            }
            .task { lock.launch(isActive: scenePhase == .active) }
            // 앱이 앞으로 나올 때 알림을 다시 건다 — 날이 바뀌었을 수 있다 (D-40).
            .onChange(of: scenePhase) { _, phase in
                lock.phaseChanged(phase)
                // 잠긴 채 앞으로 나오는 일은 없지만, 저장소를 읽는 곳은 같은 문을 지난다 (이슈 31).
                guard StoreAccess.isReadable(phase) else { return }
                let container = context.container
                Task { await ReminderScheduler.refresh(container: container) }
            }
    }
}
