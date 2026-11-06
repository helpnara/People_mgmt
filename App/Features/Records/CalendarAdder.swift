import Core
import EventKit
import EventKitUI
import SwiftUI

/// **기기 캘린더에 넣기** (1.1.8 · 이슈 90 · FR-065 · D-78 · 2026-11-06 사용자) — 앞날짜 기록을 시스템의 일정 편집 창으로.
///
/// iOS 17 부터 `EKEventEditViewController` 는 **앱 밖에서 열리는 창**이라 캘린더 권한을 묻지 않는다 — 앱은 캘린더를 읽지도
/// 쓰지도 않고, 채운 일정을 넘길 뿐이다. 넣을지 · 어느 캘린더에 넣을지는 사용자가 그 창에서 정한다.
/// 제목은 기록 제목(함께할 사람 · 나 빼고), 날짜 · 시각(시각이 없으면 하루 종일), 장소, 메모.
@MainActor
final class CalendarAdder: NSObject, EKEventEditViewDelegate {
    static let shared = CalendarAdder()

    private weak var presented: UIViewController?

    /// 시스템 일정 창을 띄운다. 넣든 취소하든 창만 닫는다 — 결과를 앱이 읽지 않는다.
    func add(_ draft: CalendarDraft) {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.isAllDay
        event.location = draft.location
        event.notes = draft.notes
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = self
        presented = controller
        TopPresenter.present(controller)
    }

    private func finish() {
        presented?.dismiss(animated: true)
        presented = nil
    }

    // 대리자 메서드는 `nonisolated` 로 두고 주 스레드로 넘긴다 — 프로토콜이 주 스레드 고정이든 아니든 같은 코드로 서게
    // (Swift 6 · `DocumentScanner` 와 같은 꼴).
    nonisolated func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        Task { @MainActor [weak self] in self?.finish() }
    }
}

/// 일정 창에 채울 값 — 기록에서 한 번 만든다.
struct CalendarDraft {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?

    /// 시각이 있으면 그 시각부터 한 시간, 없으면 그날 하루 종일.
    @MainActor
    init(record: Record, calendar: Calendar = .current) {
        let others = (record.participants ?? []).filter { !$0.isGone && !$0.isMe }
        let names = NameSort.sorted(others, name: \.name, createdAt: \.createdAt).map(\.name)
        let who = names.isEmpty ? "" : " · " + (names.count > 3 ? names.prefix(3).joined(separator: ", ") + " 외 \(names.count - 3)명"
                                                                  : names.joined(separator: ", "))
        title = record.displayTitle + who
        let day = calendar.startOfDay(for: record.occurredAt)
        if let minute = record.occurredMinute, DatePrecision.of(record.occurredPrecision) == .day {
            let begin = calendar.date(byAdding: .minute, value: minute, to: day) ?? day
            start = begin
            end = calendar.date(byAdding: .hour, value: 1, to: begin) ?? begin
            isAllDay = false
        } else {
            start = day
            end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            isAllDay = true
        }
        location = record.location.flatMap { $0.isEmpty ? nil : $0 }
        notes = record.note.flatMap { $0.isEmpty ? nil : $0 }
    }
}
