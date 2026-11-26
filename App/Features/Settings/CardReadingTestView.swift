import Core
import PhotosUI
import SwiftUI
import UIKit

/// **명함 읽기 시험** (이슈 127 · D-84 · 2026-11-26 사용자 — 느린 부자의 캡처 읽기 시험처럼).
///
/// 여러 명함 사진을 골라 앱의 명함 읽기(기기 안의 Vision 글자 인식 + `Core.BusinessCardParser`)가 칸마다 얼마나 맞히는지 잰다.
/// 같은 명함을 세 방식으로 읽어 견준다 — ① 앱과 같은 길(테두리를 찾아 편 사진) ② 펴지 않은 원본 ③ ①에 고쳐 읽기(언어 보정)를 켬.
///
/// - **아무것도 저장하지 않는다.** 사람 · 명함 · 설정 어디에도 쓰지 않는다. 화면을 나가면 결과도 사라진다.
/// - **그림은 읽고 나면 버린다.** 시스템 사진 고르기 창으로 고른 것만 건네진다 — 사진 보관함 권한을 묻지 않는다.
/// - **밖으로 보내지 않는다.** 복사는 사용자가 누를 때만, 기본은 숫자 · 글자를 가린 모양(`Core.CardMasking`).
/// - 채점은 칸마다 한 번 — 세 방식이 읽은 값 가운데 맞는 것을 누르거나, `모두 틀림`.
///   읽은 것이 없는 줄(`읽은 것 없음`)을 누르면 그 칸이 명함에 없다는 뜻이다.
struct CardReadingTestView: View {

    enum Mode: Int, CaseIterable, Identifiable {
        case app, original, corrected
        var id: Int { rawValue }
        var mark: String { ["①", "②", "③"][rawValue] }
        var title: String {
            switch self {
            case .app: "앱과 같은 길"
            case .original: "펴지 않은 원본"
            case .corrected: "고쳐 읽기 켬"
            }
        }
    }

    enum Field: String, CaseIterable, Identifiable {
        case name, organization, role, mobile, office, fax, email
        var id: String { rawValue }
        var title: String {
            switch self {
            case .name: "이름"
            case .organization: "소속"
            case .role: "직무"
            case .mobile: "휴대전화"
            case .office: "사무실"
            case .fax: "팩스"
            case .email: "이메일"
            }
        }

        func value(in suggestion: CardSuggestion) -> String? {
            let raw: String? = switch self {
            case .name: suggestion.name
            case .organization: suggestion.organization
            case .role: suggestion.role
            case .mobile: suggestion.contact.mobile
            case .office: suggestion.contact.office
            case .fax: suggestion.contact.fax
            case .email: suggestion.contact.email
            }
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        }
    }

    /// 칸 하나의 채점 — 맞는 값을 골랐다 · 모두 틀렸다 · 명함에 그 칸이 없다.
    enum Verdict: Equatable {
        case pick(String)
        case allWrong
        case absent
    }

    struct Reading {
        let lines: [CardLine]
        let suggestion: CardSuggestion
        let milliseconds: Int
    }

    struct CardResult: Identifiable {
        let id = UUID()
        let number: Int
        let foundEdges: Bool
        /// 테두리를 찾았지만 편 것이 글자를 덜 읽어 원본을 골랐다 (이슈 131).
        let keptOriginal: Bool
        let readings: [Mode: Reading]
    }

    /// 채점 줄 하나 — 세 방식이 읽은 서로 다른 값(읽은 것 없음 포함)과 그 값을 낸 방식들.
    struct Option: Identifiable {
        let value: String?
        let modes: [Mode]
        var id: String { value ?? "\u{0}" }
    }

    @State private var picks: [PhotosPickerItem] = []
    @State private var pickingPhotos = false
    @State private var cards: [CardResult] = []
    @State private var verdicts: [UUID: [Field: Verdict]] = [:]
    @State private var isReading = false
    @State private var done = 0
    @State private var total = 0
    @State private var failures: [String] = []
    @State private var copiedCard: UUID?
    @State private var seeded = false

    var body: some View {
        List {
            introSection
            pickSection
            if !cards.isEmpty {
                summarySection
                ForEach(cards) { card in
                    cardSection(card)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.custom(28))
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("명함 읽기 시험")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $pickingPhotos, selection: $picks, maxSelectionCount: 20,
                      selectionBehavior: .ordered, matching: .images)
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task { await read(items) }
        }
        .task { await seedForScreenshot() }
    }

    // MARK: - 칸

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("여러 명함 사진을 골라 앱이 칸마다 얼마나 맞게 읽는지 재 봅니다.")
                    .font(.scaled(15, weight: .medium))
                    .foregroundStyle(Color.ink)
                // `FootnoteText` 는 글을 그대로 그린다 — `**…**` 를 쓰지 않는다(빌드 82 · 이슈 129). 칸 본문이라 꼬리말 크기 · 색을 직접 준다.
                FootnoteText("읽은 결과만 보여 주고 아무것도 저장하지 않습니다. 글자 인식은 이 기기 안에서만 하고, 사진은 읽은 뒤 바로 버립니다. 같은 명함을 ① 앱과 같은 길(테두리를 찾아 편 사진) ② 펴지 않은 원본 ③ 고쳐 읽기를 켠 것, 세 방식으로 읽어 견줍니다. 칸마다 맞는 값을 누르면 위에 칸별 인식률이 모입니다.")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
            .padding(.vertical, 6)
        }
    }

    private var pickSection: some View {
        Section {
            // 목록 줄 안에 `PhotosPicker` 뷰를 두지 않는다 — 단추는 값만 켜고 창은 바깥의 `.photosPicker` 가 띄운다 (이슈 10).
            Button {
                pickingPhotos = true
            } label: {
                Label(isReading ? "읽는 중 \(done)/\(total)" : "명함 사진 고르기", systemImage: "person.crop.rectangle.stack")
            }
            .disabled(isReading)
            if !cards.isEmpty && !isReading {
                Button {
                    cards = []
                    verdicts = [:]
                    failures = []
                } label: {
                    Label("결과 비우기", systemImage: "xmark.circle")
                }
            }
            ForEach(failures, id: \.self) { message in
                Text(message)
                    .font(.scaled(13))
                    .foregroundStyle(Color.danger)
            }
        } footer: {
            Text("한 번에 20장까지 고를 수 있습니다. 명함 한 장에 몇 초 걸립니다.")
        }
    }

    private var summarySection: some View {
        let graded = cards.filter { !(verdicts[$0.id] ?? [:]).isEmpty }
        return Section {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("칸")
                    ForEach(Mode.allCases) { mode in
                        Text(mode.mark).gridColumnAlignment(.trailing)
                    }
                }
                .font(.scaled(13, weight: .semibold))
                .foregroundStyle(Color.muted)
                ForEach(Field.allCases) { field in
                    GridRow {
                        Text(field.title)
                            .font(.scaled(14))
                            .foregroundStyle(Color.ink)
                        ForEach(Mode.allCases) { mode in
                            Text(rateText(field: field, mode: mode))
                                .font(.scaled(14).monospacedDigit())
                                .foregroundStyle(Color.bodyText)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("모든 칸")
                        .font(.scaled(14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    ForEach(Mode.allCases) { mode in
                        Text(rateText(field: nil, mode: mode))
                            .font(.scaled(14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.ink)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
            .padding(.vertical, 6)
            ForEach(Mode.allCases) { mode in
                LabeledContent("\(mode.mark) \(mode.title)", value: averageTime(mode))
                    .font(.scaled(13))
            }
        } header: {
            Text("명함 \(cards.count)장 · 채점 \(graded.count)장")
        } footer: {
            Text("맞음 / 채점한 칸. 테두리를 찾은 명함 \(cards.filter(\.foundEdges).count)장.")
        }
    }

    private func cardSection(_ card: CardResult) -> some View {
        Section {
            ForEach(Field.allCases) { field in
                fieldRow(card, field)
            }
            DisclosureGroup {
                ForEach(Mode.allCases) { mode in
                    if let reading = card.readings[mode] {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(mode.mark) \(mode.title) · \(reading.lines.count)줄")
                                .font(.scaled(12, weight: .semibold))
                                .foregroundStyle(Color.muted)
                            ForEach(Array(reading.lines.enumerated()), id: \.offset) { _, line in
                                Text(line.text)
                                    .font(.scaled(12))
                                    .foregroundStyle(Color.bodyText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } label: {
                Text("읽은 글자")
                    .font(.scaled(14))
                    .foregroundStyle(Color.ink)
            }
            Menu {
                Button("가리고 복사 (숫자 · 글자를 기호로)") { copy(card, masked: true) }
                Button("그대로 복사") { copy(card, masked: false) }
            } label: {
                Label(copiedCard == card.id ? "복사했습니다 — 대화에 붙여 넣으세요" : "읽은 결과 복사",
                      systemImage: copiedCard == card.id ? "checkmark" : "doc.on.doc")
            }
        } header: {
            Text("\(card.number)번째 명함 · " + Self.edgeText(card))
        } footer: {
            Text(Mode.allCases.compactMap { mode in card.readings[mode].map { "\(mode.mark) \($0.milliseconds)ms" } }
                .joined(separator: " · "))
        }
    }

    private func fieldRow(_ card: CardResult, _ field: Field) -> some View {
        let options = Self.options(card, field)
        let verdict = verdicts[card.id]?[field]
        return VStack(alignment: .leading, spacing: 8) {
            Text(field.title)
                .font(.scaled(13, weight: .semibold))
                .foregroundStyle(Color.muted)
            ForEach(options) { option in
                optionButton(card: card, field: field, option: option, selected: verdict == Self.verdict(for: option))
            }
            Button {
                setVerdict(.allWrong, card: card, field: field)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: verdict == .allWrong ? "xmark.circle.fill" : "circle")
                        .foregroundStyle(verdict == .allWrong ? Color.danger : Color.faint)
                    Text("모두 틀림")
                        .font(.scaled(14))
                        .foregroundStyle(verdict == .allWrong ? Color.danger : Color.muted)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private func optionButton(card: CardResult, field: Field, option: Option, selected: Bool) -> some View {
        Button {
            setVerdict(Self.verdict(for: option), card: card, field: field)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accent : Color.faint)
                Text(option.value ?? "읽은 것 없음 — 명함에도 없음")
                    .font(.scaled(15))
                    .foregroundStyle(option.value == nil ? Color.muted : Color.ink)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(option.modes.map(\.mark).joined(separator: " "))
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 셈

    /// 세 방식이 읽은 서로 다른 값 — 앱의 값(①)이 맨 앞, 읽은 것 없음은 맨 뒤.
    static func options(_ card: CardResult, _ field: Field) -> [Option] {
        var order: [String?] = []
        var modes: [String: [Mode]] = [:]
        var empty: [Mode] = []
        for mode in Mode.allCases {
            guard let reading = card.readings[mode] else { continue }
            if let value = field.value(in: reading.suggestion) {
                if modes[value] == nil { order.append(value) }
                modes[value, default: []].append(mode)
            } else {
                empty.append(mode)
            }
        }
        var options = order.compactMap { $0 }.map { Option(value: $0, modes: modes[$0] ?? []) }
        if !empty.isEmpty { options.append(Option(value: nil, modes: empty)) }
        return options
    }

    /// 테두리를 찾았는지 · 찾았지만 원본을 골랐는지 (이슈 131 — ① 앱과 같은 길이 고른 그림).
    static func edgeText(_ card: CardResult) -> String {
        if !card.foundEdges { return "테두리 못 찾음" }
        return card.keptOriginal ? "테두리 찾음 · 원본 씀" : "테두리 찾음"
    }

    static func verdict(for option: Option) -> Verdict {
        option.value.map { .pick($0) } ?? .absent
    }

    static func isCorrect(_ value: String?, _ verdict: Verdict) -> Bool {
        switch verdict {
        case .pick(let right): return value == right
        case .absent: return value == nil
        case .allWrong: return false
        }
    }

    private func setVerdict(_ verdict: Verdict, card: CardResult, field: Field) {
        var forCard = verdicts[card.id] ?? [:]
        forCard[field] = forCard[field] == verdict ? nil : verdict
        verdicts[card.id] = forCard
    }

    private func rateText(field: Field?, mode: Mode) -> String {
        var right = 0
        var graded = 0
        for card in cards {
            guard let reading = card.readings[mode], let forCard = verdicts[card.id] else { continue }
            for target in field.map({ [$0] }) ?? Field.allCases {
                guard let verdict = forCard[target] else { continue }
                graded += 1
                if Self.isCorrect(target.value(in: reading.suggestion), verdict) { right += 1 }
            }
        }
        return graded == 0 ? "—" : "\(right)/\(graded)"
    }

    private func averageTime(_ mode: Mode) -> String {
        let times = cards.compactMap { $0.readings[mode]?.milliseconds }
        guard !times.isEmpty else { return "—" }
        return "평균 \(times.reduce(0, +) / times.count)ms"
    }

    // MARK: - 읽기

    private func read(_ items: [PhotosPickerItem]) async {
        isReading = true
        failures = []
        done = 0
        total = items.count
        let start = (cards.map(\.number).max() ?? 0) + 1
        for (offset, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                failures.append("\(start + offset)번째 사진을 열지 못했습니다.")
                done += 1
                continue
            }
            if let card = await Self.readCard(data, number: start + offset) {
                cards.append(card)
            } else {
                failures.append("\(start + offset)번째 사진을 읽지 못했습니다.")
            }
            done += 1
        }
        // 그림은 여기서 버린다 — 고른 표지도 비운다. 남는 것은 화면의 결과뿐.
        picks = []
        isReading = false
    }

    /// 명함 한 장을 세 방식으로. 원본 사진(`data`)은 이 함수가 끝나면 놓는다.
    static func readCard(_ data: Data, number: Int) async -> CardResult? {
        let straight = await CardImaging.straightenedCardReport(from: data)
        let original = await CardImaging.normalizedCard(from: data)
        var readings: [Mode: Reading] = [:]
        if let card = straight.card {
            readings[.app] = await reading(card, correction: false)
            readings[.corrected] = await reading(card, correction: true)
        }
        if let original {
            readings[.original] = await reading(original, correction: false)
        }
        guard !readings.isEmpty else { return nil }
        return CardResult(number: number, foundEdges: straight.foundEdges, keptOriginal: straight.keptOriginal, readings: readings)
    }

    static func reading(_ data: Data, correction: Bool) async -> Reading {
        let started = Date()
        let lines = await CardImaging.recognizeLines(in: data, languageCorrection: correction)
        let milliseconds = Int(Date().timeIntervalSince(started) * 1000)
        return Reading(lines: lines, suggestion: BusinessCardParser.parse(lines), milliseconds: milliseconds)
    }

    /// CI 스크린샷 54 (`-openSettings -openCardTest`) — 시뮬레이터에는 고를 사진이 없어 견본 명함 셋(지어낸 사람)을 그려 읽고,
    /// 그린 값으로 미리 채점해 둔다. 명함에 없는 칸(사무실 · 팩스)은 `명함에 없음`.
    private func seedForScreenshot() async {
        guard LaunchArguments.current.openCardTest, !seeded else { return }
        seeded = true
        let samples: [(organization: String, name: String, role: String, phone: String, email: String)] = [
            ("솔빛출판", "한서연", "편집장", "010-5555-0101", "seoyeon@example.com"),
            ("다올건축사무소", "오지훈", "실장", "010-5555-0102", "jihoon@example.com"),
            ("푸른숲협동조합", "남궁별", "사무국장", "010-5555-0103", "byeol@example.com"),
        ]
        isReading = true
        total = samples.count
        for (offset, sample) in samples.enumerated() {
            guard let data = SampleData.renderCard(organization: sample.organization, name: sample.name, role: sample.role,
                                                   phone: sample.phone, email: sample.email),
                  let card = await Self.readCard(data, number: offset + 1) else { continue }
            let truth: [Field: String?] = [
                .name: sample.name, .organization: sample.organization, .role: sample.role,
                .mobile: sample.phone, .office: nil, .fax: nil, .email: sample.email,
            ]
            var forCard: [Field: Verdict] = [:]
            for field in Field.allCases {
                let right = truth[field] ?? nil
                let options = Self.options(card, field)
                if let right {
                    forCard[field] = options.contains { $0.value == right } ? .pick(right) : .allWrong
                } else {
                    forCard[field] = options.contains { $0.value == nil } ? .absent : .allWrong
                }
            }
            cards.append(card)
            verdicts[card.id] = forCard
            done += 1
        }
        isReading = false
    }

    // MARK: - 복사

    private func copy(_ card: CardResult, masked: Bool) {
        UIPasteboard.general.string = Self.copyText(card, verdicts: verdicts[card.id] ?? [:], masked: masked)
        copiedCard = card.id
    }

    /// 대화에 붙여 넣을 글 — 머리에 칸별 값과 채점, 아래로 방식마다 `높이 | 글자`(위에서 아래로).
    /// `Tools/card-reading/from_paste.py` 가 이 글을 그대로 읽어 규칙을 다시 돌린다. 가리면 숫자 `#` · 영문 `x` · 한글 `○`.
    static func copyText(_ card: CardResult, verdicts: [Field: Verdict], masked: Bool) -> String {
        func hide(_ text: String) -> String { masked ? CardMasking.mask(text) : text }
        var out = ["# 명함 읽기 시험 — \(card.number)번째 명함\(masked ? " · 가림" : "")",
                   "# \(edgeText(card)) · "
                    + Mode.allCases.compactMap { mode in card.readings[mode].map { "\(mode.mark) \($0.milliseconds)ms" } }
                    .joined(separator: " · ")]
        for field in Field.allCases {
            let values = Mode.allCases.map { mode -> String in
                guard let reading = card.readings[mode] else { return "\(mode.mark) (안 읽음)" }
                return "\(mode.mark) " + (field.value(in: reading.suggestion).map(hide) ?? "(없음)")
            }
            var line = "# \(field.title): " + values.joined(separator: " | ")
            if let verdict = verdicts[field] {
                let marks = Mode.allCases.compactMap { mode in
                    card.readings[mode].map { mode.mark + (isCorrect(field.value(in: $0.suggestion), verdict) ? "맞음" : "틀림") }
                }
                line += " · 채점 " + marks.joined(separator: " ")
            } else {
                line += " · 채점 안 함"
            }
            out.append(line)
        }
        for mode in Mode.allCases {
            guard let reading = card.readings[mode] else { continue }
            out.append("## \(mode.mark) \(mode.title)")
            for line in reading.lines {
                out.append(String(format: "%.4f | ", line.height) + hide(line.text))
            }
        }
        return out.joined(separator: "\n")
    }
}
