import Core
import SwiftUI

/// **관계도** (FR-047 · 048 · 2026-10-18 사용자 결정) — 나를 가운데 두고, 이어진 사람끼리 모이게.
///
/// - 진한 선: 함께한 기록 · 아는 사이 · 소개. 함께한 기록이 많을수록 조금 굵다.
/// - 옅은 점선: 같은 소속 (끄고 켤 수 있다). 지난 시점에는 그리지 않는다 — 소속에는 날짜가 없다.
/// - 점은 **모두 같은 크기 · 같은 색**이다 — 크기 · 거리로 사람을 줄 세우지 않는다 (ADR-0004).
///   관계 유형 칩을 고르면 그 유형만 진하게 보인다 (사람이 많아 유형마다 색을 나누면 구분이 안 된다).
/// - 모임 (D-30): 조건이 차면 Louvain 으로 찾은 모임을 옅은 테두리로 감싸고 이름을 단다. 모임 칩을 고르면 그 모임만 진하게.
/// - **시점 막대** (8번째 묶음 · D-32): 분기 끝마다 12개월 창으로 다시 센 관계도. 지난 시점의 자리는 **지금 자리에서 출발**해
///   셈한다 — 같은 사람은 비슷한 자리에 머물고 변한 곳만 움직인다. 앱을 쓰기 전 시기는 옅게.
///
/// 그리기는 프레임마다 돈다 — **사람 전원을 훑는 셈은 자료나 시점이 바뀔 때 상태에 담는다** (CLAUDE.md · 전수조사 이슈 18).
struct RelationGraphView: View {
    let snapshot: NetworkSnapshot

    fileprivate struct DrawnLink {
        let i: Int
        let j: Int
        let width: CGFloat
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 관계도 설명 시트 — 큰 글씨에서 설명 글을 관계도 밖으로 옮긴다 (이슈 26).
    @State private var showsGuide = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var highlight: String?
    @State private var highlightKey: String?
    @State private var showsOrganization = true
    @State private var selected: Int?
    @State private var selectedDetail = ""
    @State private var typeChips: [String] = []
    /// 사람 자리마다 관계 유형의 이름 열쇠 — 칩 강조를 그릴 때마다 세지 않게.
    @State private var typeKeys: [String] = []
    /// 고른 모임 (보이는 시점의 `communities` 의 id). 관계 유형 칩과 함께 고르지 않는다.
    @State private var highlightCommunity: Int?
    /// 사람 자리 → 모임 id (보이는 시점의).
    @State private var membership: [Int: Int] = [:]
    @State private var groupsItem: ReadinessItem?

    /// 지금의 선 — 자료가 바뀔 때 한 번 만든다.
    @State private var currentStrong: [DrawnLink] = []
    @State private var currentOrganization: [DrawnLink] = []

    /// 시점 막대의 값. `slices.count` 이면 지금.
    @State private var sliderValue: Double = 0
    /// 고른 지난 시점 (`timeline.slices` 의 자리). nil 이면 지금.
    @State private var sliceIndex: Int?
    @State private var sliceStrong: [DrawnLink] = []
    /// 그 시점에 있던 사람.
    @State private var slicePresent: [Bool] = []
    /// 시점마다 셈해 둔 자리 — 다시 고르면 바로 그린다.
    @State private var slicePositions: [Int: [GraphLayout.Point]] = [:]

    /// 접근성 크기 글씨 (AX1~5) — 칩 줄 · 켜기 · 설명 글이 화면을 다 차지해 관계도가 0 높이가 되었다 (빌드 14 · 이슈 26).
    /// 이때는 거르기를 차림표 하나로 접고 설명은 시트로 옮겨, **관계도 칸이 먼저** 자리를 갖는다.
    private var compact: Bool { typeSize.isAccessibilitySize }
    private var meIndex: Int { snapshot.people.count }
    private var timeline: NetworkSnapshot.Timeline { snapshot.timeline }
    private var slice: NetworkSnapshot.Timeline.Slice? {
        sliceIndex.flatMap { $0 < timeline.slices.count ? timeline.slices[$0] : nil }
    }
    private var activeCommunities: [NetworkSnapshot.Community] { slice?.communities ?? snapshot.communities }
    private var activePositions: [GraphLayout.Point] {
        sliceIndex.flatMap { slicePositions[$0] } ?? snapshot.positions
    }

    var body: some View {
        VStack(spacing: 0) {
            if compact {
                compactControls
            } else {
                controls
            }
            GeometryReader { proxy in
                let size = proxy.size
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize)
                }
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in scale = min(max(lastScale * value.magnification, 0.6), 8) }
                        .onEnded { _ in lastScale = scale }
                        .simultaneously(with:
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                )
                .onTapGesture(count: 2) {
                    // 동작 줄이기를 켜 두었으면 움직이지 않고 바로 (요구사항 8.6 · D-33).
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                    }
                }
                .onTapGesture { location in
                    selected = nearest(to: location, size: size)
                    selectedDetail = selected.map { detail(forIndex: $0) } ?? ""
                }
                .accessibilityElement()
                .accessibilityLabel("관계도 \(slice?.label ?? "지금") — 사람 \(snapshot.people.count)명. 위의 특성 · 돌아보기 칸에서 목록으로 볼 수 있습니다.")
            }
            // 큰 글씨에서도 관계도 칸은 줄어 없어지지 않는다 (이슈 26). 둘레는 위에서 짧게 접었다.
            .frame(minHeight: compact ? 240 : 0)
            .clipped()
            .background(Color.raised)
            if !timeline.slices.isEmpty {
                timeBar
            }
            footer
        }
        .sheet(isPresented: $showsGuide) {
            guide
        }
        .task(id: snapshot.generation) {
            let buckets = TraitDistribution.buckets(snapshot.people.map { (id: $0.id, values: [$0.relationshipType ?? ""]) }, limit: 8)
            typeChips = buckets.filter { !$0.isRest && !$0.isUnspecified }.map(\.label)
            typeKeys = snapshot.people.map { NameSort.key($0.relationshipType ?? "") }
            var index: [UUID: Int] = [:]
            for (i, person) in snapshot.people.enumerated() { index[person.id] = i }
            var strong: [DrawnLink] = []
            var organization: [DrawnLink] = []
            for edge in snapshot.edges {
                guard let i = index[edge.a], let j = index[edge.b] else { continue }
                if edge.isStrong {
                    strong.append(DrawnLink(i: i, j: j, width: 1 + CGFloat(min(edge.together, 4)) * 0.5))
                } else if edge.sameOrganization {
                    organization.append(DrawnLink(i: i, j: j, width: 0.8))
                }
            }
            currentStrong = strong
            currentOrganization = organization
            // 다시 만든 자료는 차례가 달라질 수 있다 — 고른 사람 · 시점을 푼다.
            selected = nil
            sliceIndex = nil
            slicePositions = [:]
            sliderValue = Double(timeline.slices.count)
            // CI 스크린샷 — 지난 시점의 관계도를 바로 연다 (`-timeSlice`).
            if let k = LaunchArguments.current.timeSlice, k < timeline.slices.count {
                sliderValue = Double(k)
            }
            refreshMembership()
            groupsItem = InputReadiness.evaluate(snapshot.readiness).first { $0.feature == .groups }
        }
        .onChange(of: sliderValue) { _, value in
            let k = Int(value.rounded())
            let next = k >= timeline.slices.count ? nil : k
            guard next != sliceIndex else { return }
            sliceIndex = next
            selected = nil
            prepareSlice()
            refreshMembership()
        }
        .task(id: sliceIndex) {
            // 막대를 끄는 동안은 셈하지 않는다 — 멈추고 0.25초 뒤 그 시점의 자리를 셈한다.
            guard let k = sliceIndex, slicePositions[k] == nil, let slice else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let positions = await Self.layout(slice: slice, peopleCount: snapshot.people.count, start: snapshot.positions)
            guard !Task.isCancelled else { return }
            slicePositions[k] = positions
        }
    }

    // MARK: - 위 · 아래

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("전체", selected: highlight == nil && highlightCommunity == nil) {
                        showAll()
                    }
                    ForEach(typeChips, id: \.self) { type in
                        chip(type, selected: highlight == type) {
                            toggleType(type)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            if !activeCommunities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("모임").font(.scaled(13, weight: .semibold)).foregroundStyle(Color.muted)
                        ForEach(activeCommunities) { community in
                            chip("\(community.name) \(community.memberIDs.count)", selected: highlightCommunity == community.id) {
                                toggleCommunity(community.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            if sliceIndex == nil {
                Toggle(isOn: $showsOrganization) {
                    Text("같은 소속도 옅은 선으로 잇기").font(.scaled(14)).foregroundStyle(Color.bodyText)
                }
                .tint(Color.accent)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    /// 큰 글씨의 위 줄 (이슈 26) — 관계 유형 · 모임 · 같은 소속 선을 차림표 하나로, 설명은 오른쪽 단추의 시트로.
    private var compactControls: some View {
        HStack(spacing: 12) {
            Menu {
                Section("관계 유형") {
                    Button { showAll() } label: {
                        menuLabel("전체", selected: highlight == nil && highlightCommunity == nil)
                    }
                    ForEach(typeChips, id: \.self) { type in
                        Button { toggleType(type) } label: {
                            menuLabel(type, selected: highlight == type)
                        }
                    }
                }
                if !activeCommunities.isEmpty {
                    Section("모임") {
                        ForEach(activeCommunities) { community in
                            Button { toggleCommunity(community.id) } label: {
                                menuLabel("\(community.name) \(community.memberIDs.count)명", selected: highlightCommunity == community.id)
                            }
                        }
                    }
                }
                if sliceIndex == nil {
                    Toggle("같은 소속도 옅은 선으로 잇기", isOn: $showsOrganization)
                }
            } label: {
                Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .lineLimit(1)
                    .tapTarget()
            }
            .accessibilityLabel("보기 거르기, 지금 \(filterTitle)")
            Spacer(minLength: 0)
            Button {
                showsGuide = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.scaled(17))
                    .foregroundStyle(Color.accent)
                    .frame(minWidth: Font.scaledLength(44))
                    .tapTarget()
            }
            .accessibilityLabel("관계도 설명")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    /// 차림표 단추에 비치는 지금 고른 것.
    private var filterTitle: String {
        if let id = highlightCommunity, let community = activeCommunities.first(where: { $0.id == id }) {
            return "모임 " + community.name
        }
        return highlight ?? "전체"
    }

    @ViewBuilder
    private func menuLabel(_ text: String, selected: Bool) -> some View {
        if selected {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }

    private func showAll() {
        highlight = nil
        highlightKey = nil
        highlightCommunity = nil
    }

    private func toggleType(_ type: String) {
        highlight = highlight == type ? nil : type
        highlightKey = highlight.map { NameSort.key($0) }
        highlightCommunity = nil
    }

    private func toggleCommunity(_ id: Int) {
        highlightCommunity = highlightCommunity == id ? nil : id
        highlight = nil
        highlightKey = nil
    }

    /// 시점 막대 (D-32) — 분기 끝마다 · 맨 오른쪽이 지금.
    private var timeBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(slice?.label ?? "지금")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if sliceIndex != nil {
                    Button { sliderValue = Double(timeline.slices.count) } label: {
                        // 큰 글씨에서는 글 대신 그림 하나 — 시점 이름이 한 줄에 남게 (이슈 26).
                        if compact {
                            Image(systemName: "arrow.uturn.forward.circle")
                                .frame(minWidth: Font.scaledLength(44))
                                .tapTarget()
                        } else {
                            Text("지금으로")
                        }
                    }
                    .font(.scaled(14))
                    .accessibilityLabel("지금으로")
                }
            }
            if compact {
                // 양 끝 이름표는 큰 글씨에서 막대를 밀어낸다 — 고른 시점은 위 이름이 말한다.
                Slider(value: $sliderValue, in: 0...Double(timeline.slices.count), step: 1) {
                    Text("시점")
                }
                .tint(Color.accent)
                .accessibilityValue(slice?.label ?? "지금")
            } else {
                Slider(value: $sliderValue, in: 0...Double(timeline.slices.count), step: 1) {
                    Text("시점")
                } minimumValueLabel: {
                    Text(timeline.slices.first?.label ?? "").font(.scaled(11)).foregroundStyle(Color.muted)
                } maximumValueLabel: {
                    Text("지금").font(.scaled(11)).foregroundStyle(Color.muted)
                }
                .tint(Color.accent)
                .accessibilityValue(slice?.label ?? "지금")
                Text(timeLine)
                    .font(.scaled(12))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 4 : 10)
    }

    /// 시점 막대 아래 한 줄 — 그 시점에 무엇을 보고 있나.
    private var timeLine: String {
        guard let slice else {
            return "막대를 왼쪽으로 옮기면 분기마다 그 전 12개월의 기록으로 다시 그린 관계도를 봅니다."
        }
        var parts: [String]
        switch slice.status {
        case .sparse:
            parts = ["이 시기는 기록이 적습니다 — 진한 선 \(slice.links.count)개 (모임은 \(TemporalNetwork.minimumStrongEdges)개부터)"]
        case .unclear:
            parts = ["진한 선 \(slice.links.count)개 · 뚜렷하게 나뉘는 모임은 없습니다"]
        case .shown:
            parts = ["모임 \(slice.communities.count)개 · 진한 선 \(slice.links.count)개"]
        }
        parts.append("그 시점에 있던 사람 \(slice.present.count)명")
        var line = parts.joined(separator: " · ") + "."
        if slice.beforeUse { line += " 앱을 쓰기 시작한 뒤의 시기가 더 정확합니다." }
        return line
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: text, selected: selected)
                .tapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected, selected < snapshot.people.count {
                let person = snapshot.people[selected]
                NavigationLink(value: PersonID(id: person.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink)
                                .lineLimit(compact ? 1 : nil)
                            Text(selectedDetail).font(.scaled(13)).foregroundStyle(Color.muted).lineLimit(compact ? 1 : 2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.muted)
                    }
                    .padding(12)
                    .background(Color.raised, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else if !compact {
                Text(Self.hint)
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
            // 큰 글씨에서는 설명 글을 시트로 (이슈 26) — 위 줄 오른쪽의 설명 단추.
            if !compact {
                if sliceIndex == nil {
                    readiness
                }
                RecordedScopeNotice()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 8 : 16)
    }

    private static let hint = "점을 누르면 그 사람을 봅니다. 두 손가락으로 키우고 옮기고, 두 번 누르면 처음 크기로."

    /// 관계도 설명 시트 — 큰 글씨에서 관계도 아래에 두던 글을 그대로 모은다 (이슈 26).
    private var guide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Self.hint)
                        .font(.scaled(15))
                        .foregroundStyle(Color.bodyText)
                    Text("위의 거르기 단추로 관계 유형이나 모임 하나만 진하게 볼 수 있습니다.")
                        .font(.scaled(15))
                        .foregroundStyle(Color.bodyText)
                    if !timeline.slices.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slice?.label ?? "지금")
                                .font(.scaled(15, weight: .semibold))
                                .foregroundStyle(Color.ink)
                            Text(timeLine)
                                .font(.scaled(13))
                                .foregroundStyle(Color.muted)
                        }
                    }
                    if sliceIndex == nil {
                        readiness
                    }
                    RecordedScopeNotice()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ground)
            .navigationTitle("관계도 설명")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { showsGuide = false }
                }
            }
        }
    }

    /// 무엇이 선이 되는지와 지금 얼마나 이어졌는지 · 모임을 찾으려면 무엇이 더 있어야 하는지.
    private var readiness: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("진한 선 \(snapshot.readiness.strongEdges)개 · 서로 이어진 사람 \(snapshot.readiness.linkedPeople)명 / \(snapshot.people.count)명")
                .font(.scaled(13, weight: .medium))
                .foregroundStyle(Color.bodyText)
                .monospacedDigit()
            Text(snapshot.readiness.strongEdges == 0
                 ? "아직 사람끼리 이어진 선이 없습니다. 기록의 함께한 사람에 두 명 이상을 넣거나, 사람 수정의 아는 사이에서 서로 아는 사람을 고르거나, 알게 된 경로를 소개로 하고 소개한 사람을 고르면 선이 생깁니다."
                 : "진한 선은 함께한 기록 · 아는 사이 · 소개에서 생깁니다. 함께한 사람을 빠짐없이 넣을수록 모임의 모양이 드러납니다.")
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
            Text(communityText)
                .font(.scaled(12))
                .foregroundStyle(Color.muted)
        }
    }

    private var communityText: String {
        switch snapshot.communityStatus {
        case .shown:
            return "모임 \(snapshot.communities.count)개 — 진한 선으로 서로 많이 이어진 사람들을 테두리로 묶었습니다. 이름은 소속 · 태그 · 알게 된 경로에서 제안합니다."
        case .noClearGroups:
            return "모임 찾기 — 연결은 넉넉하지만 아직 뚜렷하게 나뉘는 모임이 없습니다."
        case .notEnoughLinks:
            return "모임 찾기 — " + (groupsItem?.hint ?? "")
        }
    }

    /// 누른 사람 한 줄 — 누를 때 한 번 센다 (본문에서 선 전부를 훑지 않는다).
    private func detail(forIndex i: Int) -> String {
        let person = snapshot.people[i]
        let links = (sliceIndex == nil ? currentStrong : sliceStrong).filter { $0.i == i || $0.j == i }.count
        let community = membership[i].flatMap { id in activeCommunities.first { $0.id == id } }
        let parts = [person.subtitle, community.map { "모임 " + $0.name },
                     links > 0 ? "이어진 사람 \(links)명" : "아직 이어진 사람 없음"].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    // MARK: - 시점

    /// 고른 시점의 선 · 있던 사람을 상태에 담는다.
    private func prepareSlice() {
        guard let slice else {
            sliceStrong = []
            slicePresent = []
            return
        }
        sliceStrong = slice.links.map { DrawnLink(i: $0.i, j: $0.j, width: 1 + CGFloat(min($0.weight, 4)) * 0.5) }
        var present = [Bool](repeating: false, count: snapshot.people.count)
        for i in slice.present where i < present.count { present[i] = true }
        slicePresent = present
    }

    private func refreshMembership() {
        var map: [Int: Int] = [:]
        for community in activeCommunities {
            for i in community.memberIndices { map[i] = community.id }
        }
        membership = map
        if let id = highlightCommunity, !activeCommunities.contains(where: { $0.id == id }) { highlightCommunity = nil }
    }

    /// 지난 시점의 자리 — 지금 자리에서 출발해 낮은 온도로 조금만 움직인다 (주 스레드 밖).
    private static func layout(slice: NetworkSnapshot.Timeline.Slice, peopleCount: Int,
                               start: [GraphLayout.Point]) async -> [GraphLayout.Point] {
        await Task.detached(priority: .userInitiated) {
            let links = slice.links.map { GraphLayout.Link(i: $0.i, j: $0.j, weight: 1 + log(1 + $0.weight)) }
            return GraphLayout.layout(nodeCount: peopleCount + 1, center: peopleCount, links: links,
                                      iterations: 60, initial: start, startTemperature: 0.02)
        }.value
    }

    // MARK: - 그리기

    /// 0~1 자리를 화면 자리로 — 가운데 기준으로 키우고 옮긴다.
    private func screenPoint(_ point: GraphLayout.Point, size: CGSize) -> CGPoint {
        let side = min(size.width, size.height) * 0.92
        let baseX = (point.x - 0.5) * side
        let baseY = (point.y - 0.5) * side
        return CGPoint(x: size.width / 2 + baseX * scale + offset.width,
                       y: size.height / 2 + baseY * scale + offset.height)
    }

    private func isShown(_ i: Int) -> Bool {
        sliceIndex == nil || (i < slicePresent.count && slicePresent[i])
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let positions = activePositions
        guard positions.count == snapshot.people.count + 1 else { return }
        // 앱을 쓰기 전 시기는 옅게 (D-32).
        if slice?.beforeUse == true { context.opacity = 0.55 }
        let highlighting = highlight != nil || highlightCommunity != nil

        // 모임 — 옅은 테두리. 채운 볼록 껍질에 굵고 둥근 선을 겹쳐 점 둘레에 여백을 둔다. 한 층으로 그려 겹친 곳이 진해지지 않게.
        for community in activeCommunities {
            let points = community.memberIndices.map { screenPoint(positions[$0], size: size) }
            let hull = Self.convexHull(points)
            guard let first = hull.first else { continue }
            var path = Path()
            path.move(to: first)
            for point in hull.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            var layer = context
            layer.opacity *= highlightCommunity == nil ? 0.10 : (highlightCommunity == community.id ? 0.22 : 0.04)
            layer.drawLayer { inner in
                inner.fill(path, with: .color(Color.accent))
                inner.stroke(path, with: .color(Color.accent), style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))
            }
            if highlightCommunity == nil || highlightCommunity == community.id,
               let top = hull.min(by: { $0.y < $1.y }) {
                let centerX = hull.map(\.x).reduce(0, +) / CGFloat(hull.count)
                context.draw(Text(community.name).font(.scaledCapped(11, weight: .semibold)).foregroundStyle(Color.muted),
                             at: CGPoint(x: centerX, y: top.y - 20), anchor: .center)
            }
        }

        // 선
        for link in sliceIndex == nil ? currentStrong : sliceStrong {
            let a = screenPoint(positions[link.i], size: size)
            let b = screenPoint(positions[link.j], size: size)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            let faded = highlighting && !(matches(link.i) && matches(link.j))
            context.stroke(path, with: .color(Color.accent.opacity(faded ? 0.12 : 0.55)), lineWidth: link.width)
        }
        if sliceIndex == nil && showsOrganization && !currentOrganization.isEmpty {
            var weak = Path()
            for link in currentOrganization {
                weak.move(to: screenPoint(positions[link.i], size: size))
                weak.addLine(to: screenPoint(positions[link.j], size: size))
            }
            context.stroke(weak, with: .color(Color.faint.opacity(0.7)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }

        // 점
        let radius: CGFloat = 5
        let showsNames = snapshot.people.count <= 40 || scale >= 2.5
        var labels = 0
        for (i, person) in snapshot.people.enumerated() where isShown(i) {
            let p = screenPoint(positions[i], size: size)
            guard p.x > -20, p.y > -20, p.x < size.width + 20, p.y < size.height + 20 else { continue }
            let faded = highlighting && !matches(i)
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(faded ? Color.faint.opacity(0.5) : Color.accent))
            if selected == i {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(Color.ink), lineWidth: 2)
            }
            if showsNames && !faded && labels < 150 {
                labels += 1
                context.draw(Text(person.name).font(.scaledCapped(11)).foregroundStyle(Color.bodyText),
                             at: CGPoint(x: p.x, y: p.y + radius + 8), anchor: .center)
            }
        }

        // 나 — 가운데, 조금 크게, 고리
        let me = screenPoint(positions[meIndex], size: size)
        let meRect = CGRect(x: me.x - 9, y: me.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: meRect), with: .color(Color.ink))
        context.stroke(Path(ellipseIn: meRect.insetBy(dx: -3, dy: -3)), with: .color(Color.accent), lineWidth: 2)
        context.draw(Text(snapshot.meName ?? "나").font(.scaledCapped(12, weight: .semibold)).foregroundStyle(Color.ink),
                     at: CGPoint(x: me.x, y: me.y + 22), anchor: .center)
    }

    private func matches(_ i: Int) -> Bool {
        if let highlightCommunity {
            return i < snapshot.people.count && membership[i] == highlightCommunity
        }
        guard let highlightKey else { return true }
        guard i < typeKeys.count else { return true }
        return typeKeys[i] == highlightKey
    }

    /// 누른 자리에서 가장 가까운 사람 (22pt 안). 없으면 고른 것을 푼다. 그 시점에 없던 사람은 고르지 않는다.
    private func nearest(to location: CGPoint, size: CGSize) -> Int? {
        let positions = activePositions
        guard positions.count == snapshot.people.count + 1 else { return nil }
        var best: (index: Int, distance: CGFloat)?
        for i in snapshot.people.indices where isShown(i) {
            let p = screenPoint(positions[i], size: size)
            let d = hypot(p.x - location.x, p.y - location.y)
            if d < 22, d < (best?.distance ?? .infinity) { best = (i, d) }
        }
        return best?.index
    }

    /// 볼록 껍질 (단조 사슬). 점이 둘 이하이면 그대로 — 굵은 선이 감싼다.
    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard sorted.count > 2 else { return sorted }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [CGPoint] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [CGPoint] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }
}
