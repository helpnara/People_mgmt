import Core
import Foundation
import SwiftData

/// **내 선택지**를 읽고 고치는 유일한 문 (FR-035 · 9판 · D-66) — 관계 유형 · 알게 된 경로.
///
/// - 종류마다 `ChoiceList` 하나다. 유니크 제약을 둘 수 없어(CloudKit · ADR-0001) 아이폰 · 아이패드가 따로 만들면 둘이 될 수 있다 —
///   읽을 때는 **늦게 고친 것**(같으면 `uuid` 글자 순 뒤)을 쓰고, 고칠 때 나머지를 지운다.
/// - 셈(보이는 차례 · 숨긴 것 · 직접 입력해 쓴 값 붙이기)은 `Core.ChoiceEditing` 하나다.
/// - 읽기는 화면 본문이 아니라 화면을 열 때 · 동작에서만 (CLAUDE.md).
enum ChoiceStore {
    /// 종류마다 쓰는 하나 — `ChoiceKind` 차례대로. 백업이 따로 연 문맥에서도 부른다.
    static func current(in context: ModelContext) -> [ChoiceList] {
        let lists = (try? context.fetch(FetchDescriptor<ChoiceList>())) ?? []
        return ChoiceKind.allCases.compactMap { kind in pick(lists.filter { $0.kind == kind.rawValue }) }
    }

    /// 이 종류에 내가 정한 것. 정한 것이 없으면 nil(기본값 그대로).
    static func setting(_ kind: ChoiceKind, in context: ModelContext) -> ChoiceSetting? {
        pick(lists(kind, in: context)).map { ChoiceSetting(items: $0.items, hidden: $0.hidden) }
    }

    /// 칩으로 보일 선택지 — 내가 정한 것 + 사람들에게 직접 입력해 쓴 값(`used`).
    static func choices(_ kind: ChoiceKind, used: [String], in context: ModelContext) -> [String] {
        ChoiceEditing.choices(kind, setting: setting(kind, in: context), used: used)
    }

    /// 보이는 차례 · 숨긴 것을 저장한다. 실패하면 이번에 바꾼 것을 모두 되돌리고 던진다.
    @MainActor
    static func save(_ kind: ChoiceKind, items: [String], hidden: [String], in context: ModelContext) throws {
        let existing = lists(kind, in: context)
        let keep: ChoiceList
        if let found = pick(existing) {
            keep = found
        } else {
            keep = ChoiceList(kind: kind.rawValue)
            context.insert(keep)
        }
        // `rollback()` 은 바뀐 칸을 되돌리지 않았다(`RecordStore.apply`) — 옛 값을 떠 두었다가 실패하면 되돌려 쓴다.
        let before = (items: keep.items, hidden: keep.hidden, updatedAt: keep.updatedAt)
        keep.items = items
        keep.hidden = hidden
        keep.updatedAt = Date()
        for other in existing where other !== keep { context.delete(other) }
        do {
            try commit(context)
        } catch {
            if !keep.isGone {
                keep.items = before.items
                keep.hidden = before.hidden
                keep.updatedAt = before.updatedAt
            }
            throw error
        }
    }

    /// 기본값으로 — 이 종류의 것을 모두 지운다.
    @MainActor
    static func reset(_ kind: ChoiceKind, in context: ModelContext) throws {
        for list in lists(kind, in: context) { context.delete(list) }
        try commit(context)
    }

    private static func lists(_ kind: ChoiceKind, in context: ModelContext) -> [ChoiceList] {
        let raw = kind.rawValue
        return (try? context.fetch(FetchDescriptor<ChoiceList>(predicate: #Predicate<ChoiceList> { $0.kind == raw }))) ?? []
    }

    private static func pick(_ lists: [ChoiceList]) -> ChoiceList? {
        lists.max { ($0.updatedAt, $0.uuid.uuidString) < ($1.updatedAt, $1.uuid.uuidString) }
    }

    @MainActor
    private static func commit(_ context: ModelContext) throws {
        do {
            try SaveFailure.check()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
