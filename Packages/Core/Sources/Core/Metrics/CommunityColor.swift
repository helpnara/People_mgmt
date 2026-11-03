import Foundation

/// **관계도 모임 색 고르기** (이슈 75 · 2026-11-03 사용자) — 모임 이름이 같으면 늘 같은 색.
///
/// 앱을 다시 켜도, 시점 막대로 지난 해를 봐도 같은 이름의 모임은 같은 색이다(사용자 결정 — 그릴 때마다 겹치지 않게 고르는 대신).
/// 이름을 NFC 로 맞춘 UTF-8 글자에 FNV-1a(32비트)를 걸어 색 수로 나눈 나머지. `hashValue` 는 켤 때마다 달라서 쓰지 않는다.
/// 이웃한 두 모임이 같은 색이 될 수는 있다 — 테두리 · 이름 알약으로 여전히 갈린다.
/// 파이썬 정답표(`Tools/golden` 의 `communityColor`)와 같은 셈이다.
public enum CommunityColor {
    public static let count = 8

    public static func index(for name: String, count: Int = count) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt32 = 0x811C9DC5
        for byte in name.precomposedStringWithCanonicalMapping.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return Int(hash % UInt32(count))
    }
}
