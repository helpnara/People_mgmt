import Core
import SwiftUI

/// **날짜 칸 하나** (빌드 39 · 1.1 · 이슈 60 · 2026-11-01 사용자) — 앱의 날짜 입력은 모두 이 꼴이다.
/// 왼쪽에 이름, 오른쪽에 지금 값(누르는 칩). 누르면 말풍선이 뜨고 **고르는 순간 닫히며 값이 들어간다** — 바깥을 눌러 닫지 않는다.
///
/// - 날짜까지: 달력 — 날을 누르면 닫힌다
/// - 월까지: 해를 넘기며 열두 달 — 달을 누르면 닫힌다
/// - 연도만: 열두 해씩 넘기며 — 해를 누르면 닫힌다
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

    /// 고른 연 · 월로 바꾸고 날은 그달에 맞게 남긴다.
    private func set(year: Int, month: Int) {
        let civil = CivilDate.clamped(year: year, month: month, day: parts.day)
        if let next = Calendar.current.date(from: DateComponents(year: civil.year, month: civil.month, day: civil.day, hour: 12)) {
            date = next
        }
        picking = false
    }

    @ViewBuilder
    private var picker: some View {
        switch precision {
        case .day:
            DatePicker(title, selection: Binding(get: { date }, set: { date = $0; picking = false }),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(minWidth: 300)
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

/// 위쪽 넘기기 줄 — `‹ 2026년 ›`.
private struct PagerHeader: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("이전")
            Spacer()
            Text(title).font(.scaled(17, weight: .semibold)).foregroundStyle(Color.ink)
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

/// 열두 달 — 해를 넘기고 달을 누르면 그 연 · 월을 알린다.
struct MonthGrid: View {
    let selectedYear: Int
    let selectedMonth: Int
    let onPick: (Int, Int) -> Void
    @State private var year: Int

    init(selectedYear: Int, selectedMonth: Int, onPick: @escaping (Int, Int) -> Void) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.onPick = onPick
        self._year = State(initialValue: selectedYear)
    }

    var body: some View {
        VStack(spacing: 8) {
            PagerHeader(title: "\(year)년",
                        canGoBack: year > DateGrids.years.lowerBound, canGoForward: year < DateGrids.years.upperBound,
                        back: { year -= 1 }, forward: { year += 1 })
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    GridCell(text: "\(month)월", selected: year == selectedYear && month == selectedMonth) {
                        onPick(year, month)
                    }
                    .accessibilityLabel("\(year)년 \(month)월")
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
