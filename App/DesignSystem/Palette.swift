import SwiftUI
import UIKit

/// 색 토큰. **화면에서 직접 색을 적지 않는다** — 다크 모드에서 그 화면만 톤이 어긋난다 (느린 부자 1번).
/// `Color.white` · `Color.black` 도 쓰지 않는다.
///
/// 값을 에셋 카탈로그가 아니라 코드에 두는 이유: 이 저장소는 맥 없이 원격에서 고치므로
/// 색이 코드에 보여야 한다.
extension Color {
    /// 목록 화면의 유일한 바탕.
    static let ground = Color(uiColor: .systemGroupedBackground)
    /// 바탕 위에 얹는 카드 · 행.
    static let raised = Color(uiColor: .secondarySystemGroupedBackground)

    static let ink = Color(light: 0x14181D, dark: 0xF2F4F6)        // 제목 · 이름
    static let bodyText = Color(light: 0x33414F, dark: 0xC5CED6)   // 본문
    static let muted = Color(light: 0x5F6B76, dark: 0x939EA9)      // 보조 · 라벨
    static let faint = Color(light: 0x98A3AC, dark: 0x6F7A85)      // 희미함
    static let rule = Color(light: 0xE3E8EB, dark: 0x272E35)       // 괘선

    /// 앱의 강조색 — 느린 톤의 청록. 선택된 칩 · 근거 문구 · 주요 단추.
    static let accent = Color(light: 0x2F6B5E, dark: 0x7CC4B2)
    static let accentSoft = Color(light: 0xE4F0EC, dark: 0x1B2E29)
    /// 태그 칩.
    static let chip = Color(light: 0xEDF1F3, dark: 0x252C33)
    static let chipInk = Color(light: 0x4E5E6B, dark: 0xB7C2CC)
    /// 파괴적 동작.
    static let danger = Color(light: 0x9A3F47, dark: 0xE08C95)

    // 관계도 모임 색 (이슈 75 · 2026-11-03 사용자) — 파스텔 여덟. 모임 이름 알약 바탕(…Soft)과 글자 · 테두리(…Ink).
    // 차례는 `Core.CommunityColor.index` 가 모임 이름으로 고른다. 대비는 `Tools/contrast.py` 가 잰다(글자/알약 4.5 넘게).
    static let clusterSageInk = Color(light: 0x2F6B5E, dark: 0x7CC4B2)   // 세이지
    static let clusterSageSoft = Color(light: 0xE4F0EC, dark: 0x1B2E29)
    static let clusterSkyInk = Color(light: 0x2B5C8A, dark: 0x8DB8E6)   // 하늘
    static let clusterSkySoft = Color(light: 0xE2EDF8, dark: 0x18263A)
    static let clusterLavenderInk = Color(light: 0x5A4791, dark: 0xB8A6E8)   // 라벤더
    static let clusterLavenderSoft = Color(light: 0xEDE7F8, dark: 0x241D36)
    static let clusterApricotInk = Color(light: 0x964626, dark: 0xF0AE8C)   // 살구
    static let clusterApricotSoft = Color(light: 0xFBE8DE, dark: 0x36211A)
    static let clusterButterInk = Color(light: 0x735A0E, dark: 0xE2C66E)   // 버터
    static let clusterButterSoft = Color(light: 0xF6EED2, dark: 0x2F2814)
    static let clusterRoseInk = Color(light: 0x8C3757, dark: 0xEBA0BC)   // 장미
    static let clusterRoseSoft = Color(light: 0xF9E4EB, dark: 0x351C26)
    static let clusterMintInk = Color(light: 0x1F6563, dark: 0x79CFCB)   // 민트
    static let clusterMintSoft = Color(light: 0xDDF2F0, dark: 0x152D2C)
    static let clusterOliveInk = Color(light: 0x56602A, dark: 0xBFCB86)   // 올리브
    static let clusterOliveSoft = Color(light: 0xECEFDC, dark: 0x262A18)
    static let clusterInks: [Color] = [clusterSageInk, clusterSkyInk, clusterLavenderInk, clusterApricotInk, clusterButterInk, clusterRoseInk, clusterMintInk, clusterOliveInk]
    static let clusterSofts: [Color] = [clusterSageSoft, clusterSkySoft, clusterLavenderSoft, clusterApricotSoft, clusterButterSoft, clusterRoseSoft, clusterMintSoft, clusterOliveSoft]

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 시스템 설정을 따라 갈아 끼워지는 색.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
