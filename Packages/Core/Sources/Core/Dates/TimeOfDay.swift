import Foundation

/// 기록의 **시각** (8판 · 빌드 39 · D-63) — 자정부터 센 분(0 ~ 1439). 날짜 칸과 따로 두어 시차에 흔들리지 않는다.
///
/// 시각은 고른 그 시계 숫자 그대로다(오후 2시 30분 = 870). 비어 있으면 시각이 없는 기록이고, 같은 날 안의 차례에서는
/// **그날의 끝**(`noTime` = 1440)으로 본다 (2026-11-01 사용자). 파이썬 정답표(`Tools/golden` 의 `timeOfDay`)와 같은 셈이다.
public enum TimeOfDay {
    public static let minutesPerDay = 24 * 60
    /// 시각 없는 기록이 차례에서 서는 자리 — 그날의 어느 시각보다도 뒤.
    public static let noTime = minutesPerDay

    /// 저장 전에 0 ~ 1439 로 자른다.
    public static func clamped(_ minute: Int?) -> Int? {
        minute.map { min(max($0, 0), minutesPerDay - 1) }
    }

    /// 차례에 쓰는 값 — 없으면 `noTime`.
    public static func sortKey(_ minute: Int?) -> Int {
        clamped(minute) ?? noTime
    }

    /// `오전 9:05` · `오후 2:30` · `오후 12:00`(정오) · `오전 12:00`(자정).
    public static func text(_ minute: Int) -> String {
        let m = min(max(minute, 0), minutesPerDay - 1)
        let hour = m / 60
        let half = hour < 12 ? "오전" : "오후"
        let shown = hour % 12 == 0 ? 12 : hour % 12
        return "\(half) \(shown):" + String(format: "%02d", m % 60)
    }
}
