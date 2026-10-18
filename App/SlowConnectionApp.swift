import SwiftData
import SwiftUI

@main
struct SlowConnectionApp: App {
    private let opened: Persistence.Opened
    private let arguments = LaunchArguments.current

    init() {
        _ = LaunchTiming.start
        let opened = Persistence.open(arguments: LaunchArguments.current)
        self.opened = opened
        if LaunchArguments.current.seedSampleData, opened.failure == nil {
            SampleData.seed(into: opened.container.mainContext)
            LaunchTiming.mark("저장소 열기 · 견본 채우기")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let failure = opened.failure {
                    // 저장소 · 모델을 하나도 안 쓰는 화면. 지우기 단추도 없다.
                    StoreFailureView(reason: failure)
                } else {
                    RootView(arguments: arguments, isSampleData: opened.isInMemory)
                }
            }
        }
        .modelContainer(opened.container)
    }
}
