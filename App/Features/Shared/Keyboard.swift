import UIKit

/// 떠 있는 키보드를 내린다 (빌드 40 · 1.1 · 이슈 61).
///
/// 입력 칸에 초점이 남은 채 날짜 말풍선을 열고 닫으면, 화면이 그 입력 칸을 다시 보이려고 위아래로 튀었다.
/// 날짜 · 시각을 고르기 **전에** 초점을 놓아 화면이 제자리에 머물게 한다. 어느 칸에 초점이 있는지 몰라도 된다.
enum Keyboard {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
