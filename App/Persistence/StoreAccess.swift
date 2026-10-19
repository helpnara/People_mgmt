import SwiftUI
import UIKit

/// **지금 저장소를 읽어도 되는가** (이슈 31). 화면 쪽 셈(정렬 · 요약 · 색인 · 알림)은 앱이 앞에 있고 기기가 잠겨 있지 않을 때만 한다.
///
/// 앱은 잠긴 동안에도 iCloud 조용한 푸시로 깨어난다. 그때 들어온 변경으로 셈을 돌리면 아무도 보지 않는 화면을 위해 저장소를 읽는다 —
/// 빌드 21 에서는 그 읽기가 잠긴 파일에 걸려 앱이 꺼졌다. 이제는 표시만 해 두고 앱이 앞으로 나올 때 한 번에 센다.
enum StoreAccess {
    @MainActor
    static func isReadable(_ phase: ScenePhase) -> Bool {
        phase == .active && UIApplication.shared.isProtectedDataAvailable
    }
}
