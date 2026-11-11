import Core
import Foundation
import UserNotifications

/// **알림을 누르면 그 기록 · 그 사람** (1.1.10 · 이슈 107).
///
/// 알림을 걸 때 `userInfo` 에 위젯과 같은 앱 URL(`Core.AppLink`)을 담아 둔다 — 약속 당일 · 결과 적기는 그 기록,
/// 생일 · n주년 · 기념일 · 연락 주기는 그 사람. 누르면 이 대리자가 URL 을 풀어 위젯과 같은 길(`ShortcutRequests`)로 넘기고,
/// 사람 목록이 연다(잠겨 있으면 풀린 뒤 · 지운 사람이면 홈 그대로). 달마다 돌아보기는 URL 이 없어 홈이 열린다.
/// 앱이 앞에 있을 때 알림을 띄우는 방식은 그대로 둔다(`willPresent` 를 두지 않는다).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationRouter()
    /// `userInfo` 에 담는 앱 URL 의 열쇠.
    static let linkKey = "link"

    /// 앱이 뜰 때 한 번 — 꺼진 앱을 알림으로 깨웠을 때도 누른 알림이 여기로 오게 앱 시작 때 단다.
    @MainActor
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo[Self.linkKey] as? String
        let isTap = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        completionHandler()
        guard isTap, let link, let url = URL(string: link), let target = AppLink.parse(url) else { return }
        Task { @MainActor in
            ShortcutRequests.shared.ask(.open(target))
        }
    }
}
