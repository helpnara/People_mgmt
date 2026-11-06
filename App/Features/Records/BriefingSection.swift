import Core
import SwiftData
import SwiftUI

/// **만나기 전에** (1.1.8 · 이슈 86 · FR-061 · D-78 · 2026-11-06 사용자) — 앞날짜 · 오늘 기록의 상세에서 함께할 사람마다 한 칸.
///
/// 기억할 것 · 처음 만난 계기 · 30일 안의 생일 · 기념일 · 지난 기록 셋. 다음에 이야기할 것은 이 칸 바로 아래
/// `TalkItemsSection` 이 따로 든다(더하고 끝낼 수 있게). 사람 줄을 누르면 사람 상세.
/// 한 사람의 관계(기록)만 읽는다 — 저장소를 묻거나 전원을 훑지 않는다 (CLAUDE.md · 이슈 10).
struct BriefingSection: View {
    let person: Person
    /// 지금 보는 예정 기록 — 지난 기록에서 뺀다.
    let record: Record

    /// 지난 기록은 셋까지.
    static let pastShown = 3

    var body: some View {
        if person.isGone {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let today = DayIndex.of(Date())
        let past = RecordStore.timeline(of: person).filter {
            $0.uuid != record.uuid && DayIndex.of($0.occurredAt) <= today
        }
        let days = UpcomingDays.of(person, today: UpcomingDays.today(), within: UpcomingDays.soon)
        return Section {
            NavigationLink(value: person) {
                PersonRow(person: person, evidence: nil)
            }
            .accessibilityIdentifier("briefingPerson")
            if let note = person.keyNote, !note.isEmpty {
                KeyNoteBox(text: note)
            }
            if let first = firstLine {
                Label(first, systemImage: "sparkles")
                    .font(.scaled(15))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(3)
            }
            ForEach(days) { day in
                Label("\(day.title) · \(day.phrase) (\(day.dateText))", systemImage: day.kind == .birthday ? "gift" : "heart")
                    .font(.scaled(15))
                    .foregroundStyle(Color.accent)
            }
            if past.isEmpty {
                Text("아직 함께한 기록이 없습니다.")
                    .font(.scaled(14))
                    .foregroundStyle(Color.muted)
            } else {
                ForEach(past.prefix(Self.pastShown)) { item in
                    NavigationLink(value: item) {
                        RecentRecordRow(record: item)
                    }
                    .accessibilityIdentifier("briefingRecord")
                }
            }
        } header: {
            Text(past.count > Self.pastShown
                 ? "만나기 전에 · \(person.name) · 지난 기록 \(past.count)건 중 셋"
                 : "만나기 전에 · \(person.name)")
                .accessibilityIdentifier("briefingSection")
        }
    }

    /// `2019년 3월 · 직장 — 회의에서 처음 인사` 처럼 처음 만난 때 · 경로 · 첫 인연 메모를 한 줄로. 없으면 nil.
    private var firstLine: String? {
        var head: [String] = []
        if let date = person.firstMetDate { head.append(date.shown(precision: person.firstMetPrecision, style: .long)) }
        if let path = person.metThrough, !path.isEmpty { head.append(path) }
        let note = (person.firstNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if head.isEmpty && note.isEmpty { return nil }
        let lead = head.isEmpty ? "처음" : "처음 " + head.joined(separator: " · ")
        return note.isEmpty ? lead : lead + " — " + note
    }
}
