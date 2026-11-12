import SwiftData
import SwiftUI

@main
struct SlowConnectionApp: App {
    private let opened: Persistence.Opened
    private let arguments = LaunchArguments.current

    init() {
        _ = LaunchTiming.start
        // 알림을 누르면 그 기록 · 그 사람 (1.1.10 · 이슈 107) — 꺼진 앱을 알림으로 깨웠을 때도 받게 맨 먼저 단다.
        NotificationRouter.install()
        let opened = Persistence.open(arguments: LaunchArguments.current)
        self.opened = opened
        if LaunchArguments.current.seedSampleData, opened.failure == nil {
            SampleData.seed(into: opened.container.mainContext)
            LaunchTiming.mark("저장소 열기 · 견본 채우기")
            LaunchTiming.storeReady = Date()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let failure = opened.failure {
                    // 저장소 · 모델을 하나도 안 쓰는 화면. 지우기 단추도 없다.
                    StoreFailureView(reason: failure)
                } else {
                    DemoSwitch(arguments: arguments, isSampleData: opened.isInMemory)
                }
            }
            // 앱 전체 강조색 (1.1.11 · 이슈 111) — `AccentColor` 자산만으로는 빌드 69 스크린샷에서 단추 · 링크가 여전히
            // 기본 파랑이었다. 맨 바깥에서 직접 건다(안쪽 화면 · 시트가 이어받는다). 삭제처럼 따로 건 색은 그대로다.
            .tint(Color.accent)
        }
        .modelContainer(opened.container)
    }
}

/// 내 자료와 견본 둘러보기(D-55) 사이를 바꾼다. 갈래가 다르면 화면이 통째로 새로 만들어져, 둘러본 화면 상태가 내 자료에 남지 않는다.
private struct DemoSwitch: View {
    let arguments: LaunchArguments
    let isSampleData: Bool
    private let demo = DemoMode.shared

    var body: some View {
        if let container = demo.container {
            RootView(arguments: arguments, isSampleData: true, isDemo: true)
                .modelContainer(container)
        } else {
            RootView(arguments: arguments, isSampleData: isSampleData, isDemo: false)
                // CI 스크린샷: 빈 진짜 저장소에서 둘러보기를 바로 연다 (-startDemo).
                .task { if arguments.startDemo { demo.start() } }
        }
    }
}
