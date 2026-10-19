import SwiftUI

/// 앱의 뿌리. 탭바 없이 스택 하나다 (요구사항 4.1). 화면 깊이는 목록 → 사람 상세 → 기록 상세 셋을 넘지 않는다.
struct RootView: View {
    let arguments: LaunchArguments
    let isSampleData: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        PeopleListView(arguments: arguments, isSampleData: isSampleData)
            // 앱이 앞으로 나올 때 알림을 다시 건다 — 날이 바뀌었을 수 있다 (D-40).
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let container = context.container
                Task { await ReminderScheduler.refresh(container: container) }
            }
    }
}
