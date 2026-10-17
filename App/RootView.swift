import SwiftUI

/// 앱의 뿌리. 탭바 없이 스택 하나다 (요구사항 4.1). 화면 깊이는 목록 → 사람 상세 → 기록 상세 셋을 넘지 않는다.
struct RootView: View {
    let arguments: LaunchArguments
    let isSampleData: Bool

    var body: some View {
        PeopleListView(arguments: arguments, isSampleData: isSampleData)
    }
}
