import Core
import Foundation
import SwiftData

/// 기록 추가 · 수정 화면이 들고 있는 값 (요구사항 4.2.4).
struct RecordDraft: Equatable {
    var occurredAt = Date()
    /// 날짜의 정밀도 (FR-033).
    var occurredPrecision = DatePrecision.day
    /// 그날의 시각 (8판 · D-63) — 자정부터 센 분. 비우면 시각 없음. 날짜까지일 때만 저장한다.
    var occurredMinute: Int?
    var recordType = RecordType.defaultKey
    var title = ""
    var note = ""
    var location = ""
    /// 함께한 사람. 기록을 연 사람이 기본으로 들어 있고, 1명 이상이어야 저장된다 (FR-042).
    var participants: [Person] = []
    var tags: [String] = []
    /// 기록 사진 (9판 · FR-058) — 차례대로, 최대 `RecordPhotos.limit` 장. 저장된 사진은 번호만 든다.
    var photos: [DraftPhoto] = []
    /// 반복 (12판 · 이슈 94 · FR-069) — 날짜까지 정한 기록에만 저장된다.
    var repeatRule: RepeatRule = .none

    /// 새 기록 — 기록을 연 사람이 첫 참여자다.
    init(anchor: Person) {
        participants = [anchor]
    }

    init(record: Record) {
        occurredAt = record.occurredAt
        occurredPrecision = .of(record.occurredPrecision)
        occurredMinute = record.occurredMinute
        recordType = record.recordType
        title = record.title ?? ""
        note = record.note ?? ""
        location = record.location ?? ""
        participants = record.participants ?? []
        tags = record.tags
        photos = record.sortedPhotos.map { DraftPhoto(existing: $0) }
        repeatRule = .of(record.repeatRule)
    }

    /// 제목 또는 메모 중 하나(D-4) · 참여자 1명 이상.
    var canSave: Bool {
        RecordValidation.canSave(title: title, note: note) && !participants.isEmpty
    }
}

/// 기록을 고치는 **유일한 문**. 저장은 `저장` 을 누른 자리에서 디스크에 닿는다.
@MainActor
struct RecordStore {
    let context: ModelContext

    /// 한 사람의 타임라인 (요구사항 6.7). 정렬 규칙은 `Core.TimelineSort` 한 곳이다.
    /// 지운 기록은 뺀다 — 지운 직후 사람 상세가 다시 그려질 때 관계에 남은 기록의 날짜를 읽으면 SwiftData 가 앱을 끈다
    /// (빌드 16 실기기 크래시 · 이슈 27).
    static func timeline(of person: Person) -> [Record] {
        (person.records ?? []).filter { !$0.isGone }.sorted {
            TimelineSort.areInIncreasingOrder((occurredAt: $0.occurredAt, minute: $0.occurredMinute, createdAt: $0.createdAt),
                                              (occurredAt: $1.occurredAt, minute: $1.occurredMinute, createdAt: $1.createdAt))
        }
    }

    /// 저장하고, 실패하면 이번에 바꾼 것을 모두 되돌린다 — `PersonStore.commit` 과 같은 까닭 (전수조사 2026-10-18).
    private func commit() throws {
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func create(_ draft: RecordDraft) throws -> Record {
        let record = Record(recordType: draft.recordType)
        context.insert(record)
        fill(record, from: draft)
        try commit()
        return record
    }

    /// 실패하면 옛 값을 되돌려 쓴다 — `PersonStore.apply` 와 같은 까닭 (`rollback()` 은 바뀐 칸을 되돌리지 않았다).
    func apply(_ draft: RecordDraft, to record: Record) throws {
        let before = RecordDraft(record: record)
        let updatedAt = record.updatedAt
        fill(record, from: draft)
        record.updatedAt = Date()
        do {
            try commit()
        } catch {
            fill(record, from: before)
            record.updatedAt = updatedAt
            throw error
        }
    }

    /// 예정이던 만남을 **그대로 만났다**고 확인한다 (D-62) — 내용은 그대로 두고 고친 때만 지금으로 바꾼다.
    /// 그날 이후 고친 기록이 되어 결과를 적을 만남에서 빠진다 (`Core.PlannedMeetings`). 실패하면 고친 때를 되돌린다.
    func confirmMet(_ record: Record) throws {
        let updatedAt = record.updatedAt
        record.updatedAt = Date()
        do {
            try commit()
        } catch {
            record.updatedAt = updatedAt
            throw error
        }
    }

    /// 기록만 지운다. 참여자는 남는다 (6.5).
    func delete(_ record: Record) throws {
        context.delete(record)
        try commit()
    }

    private func fill(_ record: Record, from draft: RecordDraft) {
        let dayBefore = DayIndex.of(record.occurredAt)
        record.recordType = RecordType.named(draft.recordType).key
        record.occurredAt = ApproximateDate.noon(of: draft.occurredAt, precision: draft.occurredPrecision, calendar: .current)
        record.occurredPrecision = draft.occurredPrecision.rawValue
        // 월까지 · 연도만이면 시각은 뜻이 없다 — 지운다.
        record.occurredMinute = draft.occurredPrecision == .day ? TimeOfDay.clamped(draft.occurredMinute) : nil
        record.title = clipped(draft.title, Limits.recordTitle)
        record.note = clipped(draft.note, Limits.recordNote)
        record.location = clipped(draft.location, Limits.location)
        record.tags = TagNormalizer.normalizeList(draft.tags)
        // 같은 사람이 두 번 들어오지 않게, 지워진 사람은 빼고.
        var seen = Set<PersistentIdentifier>()
        record.participants = draft.participants.filter { person in
            guard !person.isGone, !seen.contains(person.persistentModelID) else { return false }
            seen.insert(person.persistentModelID)
            return true
        }
        syncPhotos(record, with: draft.photos)
        fillRepeat(record, rule: draft.occurredPrecision == .day ? draft.repeatRule : .none,
                   dateChanged: DayIndex.of(record.occurredAt) != dayBefore)
    }

    /// 반복 칸을 맞춘다 (12판 · FR-069). 매달 같은 날은 처음 날(날짜를 바꾸면 그 날)을 기억하고, 반복이 있으면 회차끼리의
    /// 같은 값(`repeatSeriesID`)을 둔다. 끄면 모두 비운다.
    private func fillRepeat(_ record: Record, rule: RepeatRule, dateChanged: Bool) {
        if record.repeatRule != rule.rawValue { record.repeatRule = rule.rawValue }
        guard rule != .none else {
            record.repeatAnchorDay = nil
            record.repeatSeriesID = nil
            return
        }
        if record.repeatSeriesID == nil { record.repeatSeriesID = UUID() }
        if rule == .monthlyDay {
            if record.repeatAnchorDay == nil || dateChanged {
                record.repeatAnchorDay = Calendar.current.component(.day, from: record.occurredAt)
            }
        } else if record.repeatAnchorDay != nil {
            record.repeatAnchorDay = nil
        }
    }

    // MARK: 반복 약속의 다음 회차 (12판 · 이슈 94 · FR-069)

    /// 때가 된 반복 회차마다 **다음 회차 하나**를 앞날짜로 만든다 — 그날이 지났거나, 그날이 왔고 결과를 적었으면
    /// (`Core.RepeatRule.isDue`). 다음 날은 오늘 뒤의 첫 회차(`nextUpcoming`). 같은 반복 · 같은 날의 기록이 이미 있으면
    /// (다른 기기가 먼저 만들었으면) 만들지 않고 표시만 한다. 만든 수를 돌려준다. 실패하면 모두 되돌린다.
    @discardableResult
    func spawnDueRepeats(now: Date = Date()) throws -> Int {
        let calendar = Calendar.current
        let today = DayIndex.of(now, calendar: calendar)
        let todayCivil = UpcomingDays.today(calendar: calendar, now: now)
        let candidates = try context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> {
            $0.repeatRule != 0 && $0.repeatSpawned == false
        })).filter { !$0.isGone }
        guard !candidates.isEmpty else { return 0 }
        var made = 0
        for record in candidates {
            let rule = RepeatRule.of(record.repeatRule)
            guard rule != .none, DatePrecision.of(record.occurredPrecision) == .day else { continue }
            let day = DayIndex.of(record.occurredAt, calendar: calendar)
            guard RepeatRule.isDue(day: day, updatedDay: DayIndex.of(record.updatedAt, calendar: calendar), today: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: record.occurredAt)
            let date = CivilDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
            record.repeatSpawned = true
            guard let next = rule.nextUpcoming(after: date, anchorDay: record.repeatAnchorDay, today: todayCivil),
                  let nextDate = calendar.date(from: DateComponents(year: next.year, month: next.month, day: next.day, hour: 12))
            else { continue }
            let series = record.repeatSeriesID ?? UUID()
            if record.repeatSeriesID == nil { record.repeatSeriesID = series }
            let nextDay = DayIndex.of(nextDate, calendar: calendar)
            if try hasOccurrence(series: series, day: nextDay, calendar: calendar) { continue }
            let copy = Record(recordType: record.recordType)
            context.insert(copy)
            copy.occurredAt = nextDate
            copy.occurredPrecision = DatePrecision.day.rawValue
            copy.occurredMinute = record.occurredMinute
            copy.title = record.title
            copy.location = record.location
            copy.tags = record.tags
            copy.participants = (record.participants ?? []).filter { !$0.isGone }
            copy.repeatRule = record.repeatRule
            copy.repeatAnchorDay = record.repeatAnchorDay
            copy.repeatSeriesID = series
            made += 1
        }
        // 바뀐 것이 없으면 저장하지 않는다 — 저장 알림이 목록을 다시 세게 하고, 다시 세면 이 함수가 또 불린다.
        if context.hasChanges { try commit() }
        return made
    }

    private func hasOccurrence(series: UUID, day: Int, calendar: Calendar) throws -> Bool {
        let siblings = try context.fetch(FetchDescriptor<Record>(predicate: #Predicate<Record> { $0.repeatSeriesID == series }))
        return siblings.contains { !$0.isGone && DayIndex.of($0.occurredAt, calendar: calendar) == day }
    }

    /// 사진을 초안에 맞춘다 (9판 · FR-058) — 초안에 없는 저장된 사진은 지우고, 남는 사진은 차례만 고치고, 새 사진은 넣는다.
    /// 바뀌지 않은 사진은 건드리지 않는다 — 기록을 고칠 때마다 사진을 iCloud 로 다시 올리지 않게.
    /// 새 사진은 기록을 저장소에 넣은 **뒤에** 잇는다(4판의 규칙).
    private func syncPhotos(_ record: Record, with drafts: [DraftPhoto]) {
        let wanted = Array(drafts.prefix(RecordPhotos.limit))
        let existing = (record.photos ?? []).filter { !$0.isGone }
        let keep = Set(wanted.filter { $0.data == nil }.map(\.id))
        for photo in existing where !keep.contains(photo.uuid) {
            context.delete(photo)
        }
        for (index, item) in wanted.enumerated() {
            if let data = item.data {
                let photo = RecordPhoto(data: data, position: index)
                photo.uuid = item.id
                context.insert(photo)
                photo.record = record
            } else if let found = existing.first(where: { $0.uuid == item.id }), found.position != index {
                found.position = index
            }
        }
    }

    private func clipped(_ text: String, _ limit: Int) -> String? {
        guard let cleaned = TextNormalization.nilIfEmpty(text) else { return nil }
        return String(cleaned.prefix(limit))
    }
}

extension SchemaV12.Record {
    /// 목록에 보일 이름 (요구사항 6.2). 규칙은 `Core.DisplayTitle` 하나다.
    var displayTitle: String { DisplayTitle.make(title: title, note: note) }

    var type: RecordType { RecordType.named(recordType) }

    /// 삭제 확인 문구 (FR-009 — 대상과 범위 · 전수조사 이슈 19). 기록은 한 번만 저장되므로(N:M) 지우면
    /// 함께한 다른 사람의 타임라인에서도 사라진다. `viewer` 는 지금 보고 있는 사람의 타임라인 (기록 상세면 nil).
    /// 단추를 누를 때 미리 만들어 둔다 — 확인 창이 닫히는 동안 지운 기록을 다시 읽지 않게.
    func deletionMessage(viewer: Person?) -> String {
        let people = (participants ?? []).filter { !$0.isGone && !$0.isMe }
        var text = "'\(displayTitle)' 기록을 삭제하시겠습니까?"
        if let viewer {
            let others = people.filter { $0 !== viewer }.count
            if others > 0 { text += " 함께한 \(others)명의 타임라인에서도 사라집니다." }
        } else if people.count >= 2 {
            text += " 함께한 \(people.count)명의 타임라인에서 모두 사라집니다."
        }
        return text + " 지운 뒤 5초 안에는 되돌릴 수 있습니다."
    }

    /// 예정된 만남 판정에 넣을 값 (D-62). 날은 모두 `DayIndex` 로 센다 — 규칙은 `Core.PlannedMeetings` 하나다.
    func plannedEntry(calendar: Calendar = .current) -> PlannedMeetings.Entry {
        PlannedMeetings.Entry(id: uuid,
                              day: DayIndex.of(occurredAt, calendar: calendar),
                              createdDay: DayIndex.of(createdAt, calendar: calendar),
                              updatedDay: DayIndex.of(updatedAt, calendar: calendar),
                              isDayPrecise: DatePrecision.of(occurredPrecision) == .day,
                              minute: occurredMinute)
    }

    /// 그날의 시각 글자 (8판 · D-63) — `오후 2:30`. 날짜까지 정한 기록에만.
    var timeText: String? {
        guard DatePrecision.of(occurredPrecision) == .day, let minute = occurredMinute else { return nil }
        return TimeOfDay.text(minute)
    }

    /// 날짜 글자만 — 목록 줄이 시각과 따로 둔다(길면 날짜 다음에서 꺾으려고 · 이슈 68).
    func dateText(style: Date.FormatStyle.DateStyle) -> String {
        occurredAt.shown(precision: occurredPrecision, style: style)
    }

    /// 날짜 · 시각 글자 — 목록 줄 · 상세 머리가 모두 이것을 쓴다.
    func whenText(style: Date.FormatStyle.DateStyle) -> String {
        let date = occurredAt.shown(precision: occurredPrecision, style: style)
        return timeText.map { "\(date) \($0)" } ?? date
    }

    /// 아직 오지 않은 날의 기록 — 다가오는 만남 · 타임라인의 `예정` 표시.
    var isUpcoming: Bool {
        DayIndex.of(occurredAt) > DayIndex.of(Date())
    }

    /// 미리 적어 둔 만남의 날이 왔는데 아직 결과를 적지 않았다 — 기록 상세의 결과 적기 띠.
    var isAwaitingResult: Bool {
        PlannedMeetings.isAwaiting(plannedEntry(), today: DayIndex.of(Date()))
    }

    /// 다가오는 만남의 앞말 — `내일` · `3일 후`.
    var upcomingPhrase: String {
        PlannedMeetings.upcomingPhrase(day: DayIndex.of(occurredAt), today: DayIndex.of(Date()))
    }

    /// 이 사람 말고 함께한 사람 수 — 타임라인 행의 "외 N명".
    func otherParticipantCount(besides person: Person) -> Int {
        (participants ?? []).filter { $0 !== person }.count
    }

    /// 메모 첫 줄 (타임라인 행에 한 줄 말줄임으로). 제목이 메모에서 나왔으면 비운다.
    var notePreview: String? {
        guard let note, !note.isEmpty else { return nil }
        if TextNormalization.nilIfEmpty(title) == nil { return nil }
        return note.split(whereSeparator: { $0.isNewline }).first.map(String.init)
    }
}
