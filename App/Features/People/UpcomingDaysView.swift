import Core
import SwiftUI

/// 다가오는 날 한 줄 (1.1.8 · 이슈 93 · FR-068) — `3일 후 · 11월 9일` / `김하늘 · 결혼기념일 8주년`.
struct UpcomingDayRow: View {
    let day: UpcomingDay

    var body: some View {
        if day.person.isGone {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: day.kind == .birthday ? "gift" : "heart")
                    .font(.scaled(16))
                    .foregroundStyle(Color.accent)
                    .frame(width: Font.scaledLength(24))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(day.phrase) · \(day.dateText)")
                        .font(.scaled(13, weight: day.daysAway <= 1 ? .semibold : .regular))
                        .foregroundStyle(day.daysAway <= 1 ? Color.accent : Color.muted)
                    Text("\(day.person.name) · \(day.title)")
                        .font(.scaled(16, weight: .medium))
                        .foregroundStyle(Color.ink)
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }
}

/// 다가오는 날 모두 보기 — 한 해 안의 생일 · 기념일을 달마다 묶어. 사람을 누르면 창을 닫고 그 사람을 연다(`onOpen`).
struct UpcomingDaysView: View {
    let days: [UpcomingDay]
    let onOpen: (Person) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if days.isEmpty {
                    Text("한 해 안에 다가오는 생일 · 기념일이 없습니다. 사람 수정에서 생일 · 기념일을 적어 두세요.")
                        .font(.scaled(15))
                        .foregroundStyle(Color.muted)
                }
                ForEach(groups, id: \.key) { group in
                    Section(group.title) {
                        ForEach(group.days) { day in
                            Button {
                                onOpen(day.person)
                            } label: {
                                HStack {
                                    UpcomingDayRow(day: day)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.scaled(13, weight: .semibold))
                                        .foregroundStyle(Color.faint)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.ground)
            .navigationTitle("다가오는 날")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private struct MonthGroup {
        let key: Int
        let title: String
        let days: [UpcomingDay]
    }

    /// 해 · 달마다 — 날짜 차례 그대로.
    private var groups: [MonthGroup] {
        var result: [MonthGroup] = []
        for day in days where !day.person.isGone {
            let key = day.date.year * 100 + day.date.month
            if let last = result.last, last.key == key {
                result[result.count - 1] = MonthGroup(key: key, title: last.title, days: last.days + [day])
            } else {
                result.append(MonthGroup(key: key, title: "\(day.date.year)년 \(day.date.month)월", days: [day]))
            }
        }
        return result
    }
}
