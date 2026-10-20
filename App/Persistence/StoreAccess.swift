import SwiftUI
import UIKit

/// **지금 저장소를 읽어도 되는가** (이슈 31). 화면 쪽 셈(정렬 · 요약 · 색인 · 알림)은 앱이 앞에 있고 기기가 잠겨 있지 않을 때만 한다.
///
/// 앱은 잠긴 동안에도 iCloud 조용한 푸시로 깨어난다. 그때 들어온 변경으로 셈을 돌리면 아무도 보지 않는 화면을 위해 저장소를 읽는다 —
/// 빌드 21 에서는 그 읽기가 잠긴 파일에 걸려 앱이 꺼졌다. 이제는 표시만 해 두고 앱이 앞으로 나올 때 한 번에 센다.
///
/// **견본 자료(인메모리 저장소)는 늘 읽는다.** 파일이 없으니 잠길 것도 없다. 빌드 24 부터 CI 시뮬레이터에서는 이 문이 닫힌 채로
/// 남아 목록 맨 위의 입력 상태 줄이 스크린샷에서 사라졌고, 빌드 27 의 최근 기록도 보이지 않았다 (견본은 인메모리에만 채운다 · CLAUDE.md §2).
enum StoreAccess {
    @MainActor
    static func isReadable(_ phase: ScenePhase) -> Bool {
        if LaunchArguments.current.seedSampleData { return true }
        return phase == .active && UIApplication.shared.isProtectedDataAvailable
    }
}
