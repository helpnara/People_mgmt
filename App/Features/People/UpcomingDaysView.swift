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

/// **기간 · 장소 칩** (1.1.9 · 이슈 97 · FR-072 · D-79) — 홈 검색창을 열면 목록 맨 위에. 칩만 골라도 그 기간 · 장소의 기록이 나오고,
/// 글자를 함께 치면 그 기록 안에서 찾는다. 검색창을 닫아도 골라 둔 칩이 있으면 남아 풀 수 있게 한다.
struct SearchFilterChips: View {
    @Binding var period: RecordPeriod?
    @Binding var place: String?
    let places: [String]

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        if isSearching || period != nil || place != nil {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.scaled(13))
                            .foregroundStyle(Color.muted)
                            .accessibilityHidden(true)
                        ForEach(RecordPeriod.allCases) { item in
                            chip(item.label, selected: period == item) {
                                period = period == item ? nil : item
                            }
                        }
                    }
                }
                .accessibilityIdentifier("periodChips")
                if !places.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                                .accessibilityHidden(true)
                            ForEach(places, id: \.self) { item in
                                chip(item, selected: place == item) {
                                    place = place == item ? nil : item
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("placeChips")
                }
            } footer: {
                Text("기간 · 장소를 고르면 그 기록이 나옵니다. 글자를 함께 치면 그 기록 안에서 찾습니다.")
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: text, selected: selected)
                .tapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
