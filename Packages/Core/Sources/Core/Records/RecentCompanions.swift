import Foundation

/// **최근 함께한 사람** (빌드 16 · 조사 보고서 지금 7) — 기록 쓰기에서 함께한 사람을 한 번에 넣는 칩.
///
/// 하루에 여러 명을 만나면 같은 사람을 찾아 고르는 일이 반복된다. 최근 기록부터(`TimelineSort` 와 같은 차례) 훑어
/// 처음 보이는 사람을 차례로 모은다. 한 기록 안에서는 이름 순(`NameSort`) — 저장소가 주는 참여자 차례는 정해져 있지 않다.
/// 이미 고른 사람 · 나는 부르는 쪽이 `excluding` 으로 뺀다. 앞날짜(예정) 기록은 부르는 쪽이 넣지 않는다.
/// 파이썬 정답표(`Tools/golden` 의 `recentCompanions`)와 같은 셈이다.
public enum RecentCompanions {
    public static let limit = 8

    public struct Participant: Sendable, Equatable {
        public let id: UUID
        public let name: String
        public init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct Entry: Sendable {
        public let occurredAt: Date
        public let createdAt: Date
        public let participants: [Participant]
        public init(occurredAt: Date, createdAt: Date, participants: [Participant]) {
            self.occurredAt = occurredAt
            self.createdAt = createdAt
            self.participants = participants
        }
    }

    public static func pick(_ entries: [Entry], excluding: Set<UUID> = [], limit: Int = limit) -> [UUID] {
        let ordered = entries.sorted {
            TimelineSort.areInIncreasingOrder((occurredAt: $0.occurredAt, createdAt: $0.createdAt),
                                              (occurredAt: $1.occurredAt, createdAt: $1.createdAt))
        }
        var seen = excluding
        var out: [UUID] = []
        for entry in ordered {
            let people = entry.participants
                .map { (key: NameSort.key($0.name), id: $0.id) }
                .sorted { $0.key != $1.key ? $0.key < $1.key : $0.id.uuidString < $1.id.uuidString }
            for person in people where seen.insert(person.id).inserted {
                out.append(person.id)
                if out.count >= limit { return out }
            }
        }
        return out
    }
}
