import Core
import SwiftUI

/// **날짜 칸 하나** (빌드 39 · 1.1 · 이슈 60 · 2026-11-01 사용자) — 앱의 날짜 입력은 모두 이 꼴이다.
/// 왼쪽에 이름, 오른쪽에 지금 값(누르는 칩). 누르면 말풍선이 뜨고 **정밀도의 마지막 단위를 고르는 순간 닫히며 값이 들어간다**.
///
/// - 날짜까지: 달력(`DayCalendar`) — 해 · 달은 위 제목을 눌러 바꾸고(닫히지 않는다), **날을 누르면** 닫힌다
/// - 월까지: 열두 달 — 해는 제목을 눌러 바꾸고(닫히지 않는다), **달을 누르면** 닫힌다
/// - 연도만: 열두 해씩 넘기며 — **해를 누르면** 닫힌다
///
/// 빌드 57 까지 날짜까지는 시스템 달력(`DatePicker` · graphical)이었고 값이 바뀌면 닫았다 — 시스템 달력은 위의 해 · 달을
/// 돌리기만 해도 고른 날을 바꾸므로 해만 바꿔도 닫혔다(이슈 83 · 2026-11-05 사용자: 해 → 닫힘 → 다시 열어 달 → 닫힘 → 다시 열어 날).
/// 날을 누른 것과 해 · 달을 바꾼 것을 시스템 달력에서는 가를 수 없어, 앱의 다른 고르개와 같은 칸 달력으로 바꿨다.
///
/// 저장할 때 `Core.ApproximateDate` 가 접는다(월까지 = 그달 1일 · 연도만 = 1월 1일). 여기서는 달 · 해만 바꾸고 날은 그달에
/// 맞게 남긴다(`Core.CivilDate.clamped`) — 정밀도를 날짜까지로 되돌려도 고른 날이 크게 흔들리지 않게.
struct ApproxDateField: View {
    let title: LocalizedStringKey
    @Binding var date: Date
    let precision: DatePrecision
    @State private var picking = false

    init(_ title: LocalizedStringKey, date: Binding<Date>, precision: DatePrecision) {
        self.title = title
        self._date = date
        self.precision = precision
    }

    var body: some View {
        LabeledContent(title) {
            Button {
                // 입력 칸의 초점을 먼저 놓는다 — 말풍선이 닫힐 때 화면이 그 칸으로 튀지 않게 (이슈 61).
                Keyboard.dismiss()
                picking = true
            } label: {
                DateChip(text: valueText)
            }
            .buttonStyle(.plain)
            .accessibilityHint("눌러서 고릅니다")
            .accessibilityIdentifier("dateChip")
            .popover(isPresented: $picking) {
                picker
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
            }
        }
        // 정밀도를 바꾸면 떠 있던 말풍선은 닫는다 — 다른 꼴의 고르개가 남지 않게.
        .onChange(of: precision) { _, _ in picking = false }
    }

    /// 저장했을 때 보일 글 그대로 — 저장 규칙과 같은 함수로 접어 본다.
    private var valueText: String {
        let stored = ApproximateDate.noon(of: date, precision: precision, calendar: .current)
        return ApproximateDate.label(of: stored, precision: precision) ?? date.formatted(date: .long, time: .omitted)
    }

    private var parts: (year: Int, month: Int, day: Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// 고른 연 · 월(· 일)로 바꾸고 닫는다. 날을 주지 않으면 지금 날을 그달에 맞게 남긴다.
    private func set(year: Int, month: Int, day: Int? = nil) {
        let civil = CivilDate.clamped(year: year, month: month, day: day ?? parts.day)
        if let next = Calendar.current.date(from: DateComponents(year: civil.year, month: civil.month, day: civil.day, hour: 12)) {
            date = next
        }
        picking = false
    }

    @ViewBuilder
    private var picker: some View {
        switch precision {
        case .day:
            DayCalendar(selectedYear: parts.year, selectedMonth: parts.month, selectedDay: parts.day) { year, month, day in
                set(year: year, month: month, day: day)
            }
        case .month:
            MonthGrid(selectedYear: parts.year, selectedMonth: parts.month) { year, month in
                set(year: year, month: month)
            }
        case .year:
            YearGrid(selected: parts.year, range: DateGrids.years) { year in
                if let year { set(year: year, month: parts.month) }
            }
        }
    }
}

/// 날짜 칸의 값 칩 — 시스템 날짜 고르개의 작은 꼴과 비슷하게(옅은 바탕 · 강조색 글자).
struct DateChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.scaled(16))
            .foregroundStyle(Color.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.chip, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}

enum DateGrids {
    /// 고를 수 있는 해 — 1900년부터 올해 + 10년(예정된 만남)까지.
    static let years: ClosedRange<Int> = {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        return 1900...(now + 10)
    }()
}

/// 칸 하나 — 누르기 쉬운 크기(44pt 이상), 고른 것은 옅은 강조 바탕 · 강조색 굵은 글자.
private struct GridCell: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.scaled(16, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.accent : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.accentSoft : Color.chip, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 해가 든 접근성 이름은 `Text(verbatim:)` 로 — 글 열쇠(LocalizedStringKey)에 넣은 정수는 천 단위 쉼표가 붙어
/// `2,026년 1월` 이 된다(CI 138 에서 찾음 · VoiceOver 도 그렇게 읽는다).
/// 위쪽 넘기기 줄 — `‹ 2026년 ›`. `onTitle` 이 있으면 제목이 단추다(`2026년 3월 ⌄` — 눌러서 한 단계 위를 고른다).
private struct PagerHeader: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void
    var onTitle: (() -> Void)?
    var titleHint: String = ""

    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("이전")
            Spacer()
            if let onTitle {
                Button(action: onTitle) {
                    HStack(spacing: 4) {
                        Text(title).font(.scaled(17, weight: .semibold)).foregroundStyle(Color.ink)
                        Image(systemName: "chevron.down").font(.scaled(12, weight: .semibold)).foregroundStyle(Color.accent)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(titleHint)
                .accessibilityIdentifier("calendarTitle")
            } else {
                Text(title).font(.scaled(17, weight: .semibold)).foregroundStyle(Color.ink)
            }
            Spacer()
            Button(action: forward) {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("다음")
        }
        .foregroundStyle(Color.accent)
    }
}

/// 열두 달 — 해를 넘기고 달을 누르면 그 연 · 월을 알린다. 제목(`2026년 ⌄`)을 누르면 열두 해에서 해를 고른다 —
/// 해를 골라도 알리지 않고(닫히지 않는다) 그 해의 열두 달로 돌아온다 (이슈 83).
struct MonthGrid: View {
    let selectedYear: Int
    let selectedMonth: Int
    let onPick: (Int, Int) -> Void
    @State private var year: Int
    @State private var choosingYear = false

    init(selectedYear: Int, selectedMonth: Int, onPick: @escaping (Int, Int) -> Void) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.onPick = onPick
        self._year = State(initialValue: selectedYear)
    }

    var body: some View {
        if choosingYear {
            YearGrid(selected: year, range: DateGrids.years) { picked in
                if let picked { year = picked }
                choosingYear = false
            }
        } else {
            months
        }
    }

    private var months: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(year)년",
                        canGoBack: year > DateGrids.years.lowerBound, canGoForward: year < DateGrids.years.upperBound,
                        back: { year -= 1 }, forward: { year += 1 },
                        onTitle: { choosingYear = true }, titleHint: "눌러서 해를 고릅니다")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    GridCell(text: "\(month)월", selected: year == selectedYear && month == selectedMonth) {
                        onPick(year, month)
                    }
                    .accessibilityLabel(Text(verbatim: "\(year)년 \(month)월"))
                }
            }
        }
        .frame(minWidth: 280)
    }
}

/// 열두 해씩 — 넘기고 해를 누르면 그 해를 알린다. `unknownLabel` 이 있으면 맨 위에 `모름` 단추(nil 을 알린다).
struct YearGrid: View {
    let selected: Int?
    let range: ClosedRange<Int>
    var unknownLabel: String?
    let onPick: (Int?) -> Void
    @State private var start: Int

    init(selected: Int?, range: ClosedRange<Int>, unknownLabel: String? = nil, onPick: @escaping (Int?) -> Void) {
        self.selected = selected
        self.range = range
        self.unknownLabel = unknownLabel
        self.onPick = onPick
        let anchor = min(max(selected ?? Calendar(identifier: .gregorian).component(.year, from: Date()), range.lowerBound),
                         range.upperBound)
        self._start = State(initialValue: anchor - (anchor - range.lowerBound) % 12)
    }

    var body: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(start) – \(min(start + 11, range.upperBound))",
                        canGoBack: start > range.lowerBound, canGoForward: start + 12 <= range.upperBound,
                        back: { start -= 12 }, forward: { start += 12 })
            if let unknownLabel {
                GridCell(text: unknownLabel, selected: selected == nil) { onPick(nil) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(start...min(start + 11, range.upperBound)), id: \.self) { year in
                    GridCell(text: "\(year)년", selected: year == selected) { onPick(year) }
                }
            }
        }
        .frame(minWidth: 280)
    }
}

/// 생일의 월 · 일 — 달을 누르면 그 달의 날로 넘어가고, 날을 누르면 알린다. 그 달에 없는 날은 없다(`dayLimit`).
struct MonthDayGrid: View {
    let selectedMonth: Int
    let selectedDay: Int
    let dayLimit: (Int) -> Int
    let onPick: (Int, Int) -> Void
    @State private var month: Int?

    init(selectedMonth: Int, selectedDay: Int, dayLimit: @escaping (Int) -> Int, onPick: @escaping (Int, Int) -> Void) {
        self.selectedMonth = selectedMonth
        self.selectedDay = selectedDay
        self.dayLimit = dayLimit
        self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: 8) {
            if let month {
                PagerHeader(title: "\(month)월", canGoBack: true, canGoForward: false,
                            back: { self.month = nil }, forward: {})
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(1...dayLimit(month), id: \.self) { day in
                        GridCell(text: "\(day)", selected: month == selectedMonth && day == selectedDay) {
                            onPick(month, day)
                        }
                        .accessibilityLabel("\(month)월 \(day)일")
                    }
                }
            } else {
                Text("달을 고르세요").font(.scaled(15, weight: .semibold)).foregroundStyle(Color.ink)
                    .frame(minHeight: 44)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(1...12, id: \.self) { m in
                        GridCell(text: "\(m)월", selected: m == selectedMonth) { month = m }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }
}

/// **날짜까지 달력** (이슈 83 · 2026-11-05 사용자) — 해 → 달 → 날 차례로 고르고 **날을 누를 때만** 알린다(닫힌다).
///
/// - 날: `‹ 2026년 3월 ⌄ ›` — 화살표로 달을 넘기고, 제목을 누르면 열두 달로
/// - 달: `‹ 2026년 ⌄ ›` 열두 달 — 달을 누르면 그 달의 날로(닫히지 않는다), 제목을 누르면 열두 해로
/// - 해: 열두 해씩 — 해를 누르면 그 해의 열두 달로(닫히지 않는다)
///
/// 주의 첫날 · 요일 글자는 기기 달력(`Calendar.current`)을 따른다. 오늘은 강조색 글자, 고른 날은 옅은 강조 바탕.
struct DayCalendar: View {
    let selectedYear: Int
    let selectedMonth: Int
    let selectedDay: Int
    let onPick: (Int, Int, Int) -> Void
    @State private var year: Int
    @State private var month: Int
    @State private var stage: Stage = .days

    private enum Stage { case days, months, years }

    init(selectedYear: Int, selectedMonth: Int, selectedDay: Int, onPick: @escaping (Int, Int, Int) -> Void) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.selectedDay = selectedDay
        self.onPick = onPick
        self._year = State(initialValue: selectedYear)
        self._month = State(initialValue: selectedMonth)
    }

    var body: some View {
        Group {
            switch stage {
            case .days: days
            case .months: months
            case .years:
                YearGrid(selected: year, range: DateGrids.years) { picked in
                    if let picked { year = picked }
                    stage = .months
                }
            }
        }
        .frame(minWidth: 300)
    }

    // MARK: 날

    private var days: some View {
        let calendar = Calendar.current
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12)) ?? Date()
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return VStack(spacing: 6) {
            PagerHeader(title: "\(year)년 \(month)월",
                        canGoBack: !(year == DateGrids.years.lowerBound && month == 1),
                        canGoForward: !(year == DateGrids.years.upperBound && month == 12),
                        back: { step(-1) }, forward: { step(1) },
                        onTitle: { stage = .months }, titleHint: "눌러서 해와 달을 고릅니다")
            dayGrid(lead: lead, count: count, today: today, symbols: weekdaySymbols(calendar))
        }
    }

    /// 요일 줄 + 날 칸 — 한 식이 길면 컴파일러가 형식을 제때 못 맞춰 떼어 둔다(빌드 45 교훈).
    private func dayGrid(lead: Int, count: Int, today: DateComponents, symbols: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.scaled(12, weight: .semibold))
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .accessibilityHidden(true)
            }
            ForEach(0..<(lead + count), id: \.self) { slot in
                daySlot(slot - lead + 1, today: today)
            }
        }
    }

    @ViewBuilder
    private func daySlot(_ day: Int, today: DateComponents) -> some View {
        if day < 1 {
            Color.clear.frame(minHeight: 40).accessibilityHidden(true)
        } else {
            DayCell(day: day,
                    selected: year == selectedYear && month == selectedMonth && day == selectedDay,
                    isToday: today.year == year && today.month == month && today.day == day) {
                onPick(year, month, day)
            }
            .accessibilityLabel(Text(verbatim: "\(year)년 \(month)월 \(day)일"))
        }
    }

    /// 요일 글자 — 기기의 주 첫날부터.
    private func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    /// 달 넘기기 — 해가 바뀌면 해도 넘긴다.
    private func step(_ delta: Int) {
        var m = month + delta
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        guard DateGrids.years.contains(y) else { return }
        year = y
        month = m
    }

    // MARK: 달

    private var months: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(year)년",
                        canGoBack: year > DateGrids.years.lowerBound, canGoForward: year < DateGrids.years.upperBound,
                        back: { year -= 1 }, forward: { year += 1 },
                        onTitle: { stage = .years }, titleHint: "눌러서 해를 고릅니다")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    GridCell(text: "\(m)월", selected: year == selectedYear && m == selectedMonth) {
                        month = m
                        stage = .days
                    }
                    .accessibilityLabel(Text(verbatim: "\(year)년 \(m)월"))
                }
            }
        }
    }
}

/// 달력의 날 칸 — 고른 날은 옅은 강조 바탕 · 굵은 강조 글자, 오늘은 강조 글자.
private struct DayCell: View {
    let day: Int
    let selected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(day)")
                .font(.scaled(16, weight: selected || isToday ? .semibold : .regular))
                .foregroundStyle(selected || isToday ? Color.accent : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? Color.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
