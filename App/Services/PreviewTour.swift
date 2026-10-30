import Foundation

/// **스토어 미리보기 영상** (2026-10-30 사용자 — 아이폰 · 아이패드 앱 미리보기).
///
/// `-previewTour` 로 열면 목록이 정해진 차례로 화면을 넘긴다(`PeopleListView.runPreviewTour`). CI 가 그동안 시뮬레이터 화면을
/// 녹화해 15~30초 영상으로 다듬는다. 견본(`-seedSampleData`)만 쓰고 진짜 저장소는 열지 않는다.
/// 관계도 칸 안의 일(점 고르기 · 시점 막대)은 알림으로 넘긴다 — 관계도의 상태는 관계도가 쥐고 있다.
enum PreviewTour {
    /// 관계도에서 이 이름(`object: String`)의 점을 고른다 — 아이패드의 떠 있는 카드.
    static let selectPerson = Notification.Name("PreviewTour.selectPerson")
    /// 시점 막대를 이 해(`object: Int`)로, 없으면 지금으로.
    static let timeSlice = Notification.Name("PreviewTour.timeSlice")
}
