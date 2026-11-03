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

    // 관계도 모임 색 (이슈 75 → 76 · 2026-11-03 사용자) — 또렷한 여덟(색상환에 고르게 · 색약에도 갈리는 쪽).
    // …Edge 는 모임 테두리 · 둘레 선, …Ink · …Soft 는 모임 이름 알약의 글자 · 바탕(대비 4.5 넘게 · `Tools/contrast.py`).
    // 차례는 `Core.CommunityColor.assign` 이 정한다(이름 색 기본 · 겹치면 빈 색).
    static let clusterBlueEdge = Color(light: 0x2F6FD6, dark: 0x598CDE)   // 파랑
    static let clusterBlueInk = Color(light: 0x2A64C1, dark: 0x78A1E4)
    static let clusterBlueSoft = Color(light: 0xE2EBF9, dark: 0x0D1F3C)
    static let clusterOrangeEdge = Color(light: 0xE07A10, dark: 0xE69540)   // 주황
    static let clusterOrangeInk = Color(light: 0x9D550B, dark: 0xEBA964)
    static let clusterOrangeSoft = Color(light: 0xFBECDE, dark: 0x3F2204)
    static let clusterGreenEdge = Color(light: 0x2E9A57, dark: 0x58AE79)   // 초록
    static let clusterGreenInk = Color(light: 0x227441, dark: 0x77BD92)
    static let clusterGreenSoft = Color(light: 0xE2F1E7, dark: 0x0D2B18)
    static let clusterMagentaEdge = Color(light: 0xC23A8E, dark: 0xCE61A5)   // 자주
    static let clusterMagentaInk = Color(light: 0xAF3480, dark: 0xD77FB6)
    static let clusterMagentaSoft = Color(light: 0xF6E3EF, dark: 0x361028)
    static let clusterTealEdge = Color(light: 0x0E95A3, dark: 0x3EAAB5)   // 청록
    static let clusterTealInk = Color(light: 0x0A707A, dark: 0x62BAC3)
    static let clusterTealSoft = Color(light: 0xDDF0F2, dark: 0x042A2E)
    static let clusterVermilionEdge = Color(light: 0xD5482F, dark: 0xDD6D59)   // 다홍
    static let clusterVermilionInk = Color(light: 0xB53D28, dark: 0xE48878)
    static let clusterVermilionSoft = Color(light: 0xF9E5E2, dark: 0x3C140D)
    static let clusterPurpleEdge = Color(light: 0x7650CF, dark: 0x9173D9)   // 보라
    static let clusterPurpleInk = Color(light: 0x704CC5, dark: 0xA68DE0)
    static let clusterPurpleSoft = Color(light: 0xECE6F8, dark: 0x21163A)
    static let clusterMustardEdge = Color(light: 0xB08A00, dark: 0xC0A133)   // 겨자
    static let clusterMustardInk = Color(light: 0x7B6100, dark: 0xCCB359)
    static let clusterMustardSoft = Color(light: 0xF4EFDB, dark: 0x312700)
    static let clusterEdges: [Color] = [clusterBlueEdge, clusterOrangeEdge, clusterGreenEdge, clusterMagentaEdge, clusterTealEdge, clusterVermilionEdge, clusterPurpleEdge, clusterMustardEdge]
    static let clusterInks: [Color] = [clusterBlueInk, clusterOrangeInk, clusterGreenInk, clusterMagentaInk, clusterTealInk, clusterVermilionInk, clusterPurpleInk, clusterMustardInk]
    static let clusterSofts: [Color] = [clusterBlueSoft, clusterOrangeSoft, clusterGreenSoft, clusterMagentaSoft, clusterTealSoft, clusterVermilionSoft, clusterPurpleSoft, clusterMustardSoft]

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
