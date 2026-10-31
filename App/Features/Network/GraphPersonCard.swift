import Core
import SwiftData
import SwiftUI

/// **관계도에서 누른 사람 요약** (아이패드 · 이슈 51 · 2026-10-28 사용자 — 관계도 아래 4분의 1 칸에 사람 상세 전체가 나와 보기 불편했다).
///
/// - 관계도 위에 떠서, 누른 점의 **맞은편 귀퉁이**에 놓인다 — 누른 점과 그 둘레를 가리지 않게. 관계도는 칸 전체 높이를 쓴다.
/// - 사진 · 이름 · 관계도 한 줄(소속 · 관계 · 모임 · 이어진 사람) · 함께한 기록 수 · 마지막 기록 · 태그.
/// - `자세히 보기` 는 칸 전체에 사람 상세를 열고, 뒤로 가면 관계도로 돌아온다(누른 점 그대로). 다른 점을 누르면 카드만 바뀐다.
/// - 기록 수 · 마지막 기록은 본문에서 세지 않는다 — 나타날 때 한 번 (CLAUDE.md). 상세에서 기록을 더하고 돌아오면 다시 센다.
struct GraphPersonCard: View {
    let detail: String
    let onClose: () -> Void

    @Query private var found: [Person]
    @State private var summary: Summary?

    private struct Summary: Equatable {
        let records: Int
        let last: Date?
    }

    init(id: UUID, detail: String, onClose: @escaping () -> Void) {
        _found = Query(filter: #Predicate<Person> { $0.uuid == id })
        self.detail = detail
        self.onClose = onClose
    }

    var body: some View {
        if let person = found.first, !person.isGone {
            card(person)
                .task(id: person.uuid) {
                    summary = Summary(records: (person.records ?? []).filter { !$0.isGone }.count,
                                      last: person.lastRecordAt)
                }
        }
    }

    private func card(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PersonAvatar(person: person, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.name)
                        .font(.scaled(18, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.scaled(13))
                            .foregroundStyle(Color.muted)
                            .lineLimit(3)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.scaled(22))
                        .foregroundStyle(Color.faint)
                        .tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("graphCardClose")
            }

            if let summary {
                HStack(alignment: .top, spacing: 16) {
                    fact("함께한 기록", value: "\(summary.records)건")
                    fact("마지막 기록", value: summary.last.map { RelativeDay.phrase(from: $0, to: Date(), calendar: .current) } ?? "아직 없음")
                }
            }

            if !person.tags.isEmpty {
                Text(person.tags.prefix(4).map { "#" + $0 }.joined(separator: "  "))
                    .font(.scaled(13))
                    .foregroundStyle(Color.accent)
                    .lineLimit(1)
                    .accessibilityLabel("태그 " + person.tags.prefix(4).joined(separator: ", "))
            }

            NavigationLink(value: PersonID(id: person.uuid)) {
                HStack {
                    Text("자세히 보기")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.scaled(15, weight: .semibold))
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accent)
            .accessibilityHint("\(person.name) 님의 인연을 칸 전체에 엽니다")
            .accessibilityIdentifier("graphCardDetail")
        }
        .padding(16)
        .background(Color.raised, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rule, lineWidth: 1))
        .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("graphPersonCard")
    }

    private func fact(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
            Text(value)
                .font(.scaled(15, weight: .semibold))
                .foregroundStyle(Color.bodyText)
        }
        .accessibilityElement(children: .combine)
    }
}
