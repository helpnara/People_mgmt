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
    /// 아이패드 (이슈 32 · 51) — 누른 사람을 관계도 위에 떠 있는 요약 카드로 보인다(`GraphPersonCard`).
    /// 아니면(아이폰) 관계도 아래 사람 칸에서 상세로 넘어간다.
    var floatsCard = false

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
    /// 고른 사람의 id — 자료를 다시 만들어도(상세에서 기록을 더하고 돌아올 때) 떠 있는 카드를 그대로 둔다 (이슈 51).
    @State private var selectedID: UUID?
    /// 떠 있는 카드의 귀퉁이 — 누른 점의 맞은편 (이슈 51).
    @State private var cardAlignment: Alignment = .bottomTrailing
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
    /// 그리는 자리 (이슈 29). 시점을 옮기면 앞 자리(`fromPositions`)에서 새 자리(`shownPositions`)로 잠깐 옮겨 간다 —
    /// 그 시점의 자리를 셈하는 동안에도 앞 그림을 그대로 둔다(지금 자리로 잠깐 돌아갔다가 툭 바뀌지 않게).
    @State private var shownPositions: [GraphLayout.Point] = []
    @State private var fromPositions: [GraphLayout.Point] = []
    @State private var moveStart: Date?
    /// 지금이나 어느 시점에든 모임이 있는가 — 모임 줄을 시점마다 넣었다 뺐다 하지 않는다 (이슈 29).
    @State private var hasAnyCommunities = false
    /// 사람 자리 → 이름 순 차례 (이슈 30). 이름표를 놓는 차례 — 누가 더 중요한지가 아니라 이름 순이다 (ADR-0004).
    @State private var nameRank: [Int] = []
    /// 지금 자리가 나(0.5)에서 가로 · 세로로 퍼진 거리 — 그림 칸에 고루 펴는 데 쓴다 (이슈 32). 자료가 바뀔 때만 센다 —
    /// 시점마다 다시 세면 시점 막대를 옮길 때 그림이 커졌다 작아졌다 한다 (이슈 29).
    @State private var spreadX = 0.5
    @State private var spreadY = 0.5

    /// 접근성 크기 글씨 (AX1~5) — 칩 줄 · 켜기 · 설명 글이 화면을 다 차지해 관계도가 0 높이가 되었다 (빌드 14 · 이슈 26).
    /// 이때는 거르기를 차림표 하나로 접고 설명은 시트로 옮겨, **관계도 칸이 먼저** 자리를 갖는다.
    private var compact: Bool { typeSize.isAccessibilitySize }
    /// 아이패드 관계도 칸 (이슈 32 · 빌드 25 사용자 — 관계도가 여전히 작다). 위 거르기를 한 줄로, 시점 설명을 한 줄로 줄여
    /// 관계도 칸이 높이를 갖는다. 누른 사람은 관계도 위에 떠 있는 카드가 맡는다 (이슈 51).
    private var wide: Bool { floatsCard && !compact }
    private var meIndex: Int { snapshot.people.count }
    private var timeline: NetworkSnapshot.Timeline { snapshot.timeline }
    private var slice: NetworkSnapshot.Timeline.Slice? {
        sliceIndex.flatMap { $0 < timeline.slices.count ? timeline.slices[$0] : nil }
    }
    private var activeCommunities: [NetworkSnapshot.Community] { slice?.communities ?? snapshot.communities }
    /// 옮겨 가는 끝 자리 — 누른 곳 찾기는 이것으로.
    private var activePositions: [GraphLayout.Point] {
        shownPositions.isEmpty ? snapshot.positions : shownPositions
    }
    private static let moveDuration = 0.35
    /// 칸 가장자리에 남기는 여백 — 이름표 · 모임 이름 · 모임 테두리가 들어갈 자리.
    private static let edgeX: CGFloat = 36
    private static let edgeY: CGFloat = 34
    /// 가로 · 세로 배율 차이의 한도.
    private static let maxStretch: CGFloat = 1.8

    var body: some View {
        VStack(spacing: 0) {
            if compact {
                compactControls
            } else if wide {
                wideControls
            } else {
                controls
            }
            GeometryReader { proxy in
                let size = proxy.size
                // 옮겨 가는 동안만 프레임마다 다시 그린다 (이슈 29). 멈춰 있으면 쉰다.
                TimelineView(.animation(minimumInterval: nil, paused: moveStart == nil)) { frame in
                    Canvas { context, canvasSize in
                        draw(in: &context, size: canvasSize, positions: displayedPositions(at: frame.date))
                    }
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
                    selectedID = selected.flatMap { $0 < snapshot.people.count ? snapshot.people[$0].id : nil }
                    // 카드는 누른 점의 맞은편 귀퉁이로 — 누른 점과 그 둘레를 가리지 않게 (이슈 51).
                    cardAlignment = Alignment(horizontal: location.x > size.width / 2 ? .leading : .trailing,
                                              vertical: location.y > size.height / 2 ? .top : .bottom)
                }
                .accessibilityElement()
                .accessibilityLabel("관계도 \(slice?.label ?? "지금") — 사람 \(snapshot.people.count)명. 위의 특성 · 돌아보기 칸에서 목록으로 볼 수 있습니다.")
            }
            .overlay(alignment: cardAlignment) {
                if floatsCard, let selectedID, let selected, selected < snapshot.people.count {
                    GraphPersonCard(id: selectedID, detail: selectedDetail) {
                        self.selected = nil
                        self.selectedID = nil
                    }
                    .id(selectedID)
                    .frame(maxWidth: min(Font.scaledLength(340), 460))
                    .padding(16)
                    .transition(.opacity)
                }
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
            shownPositions = snapshot.positions
            moveStart = nil
            var reachX = 0.05, reachY = 0.05
            for point in snapshot.positions {
                reachX = max(reachX, abs(point.x - 0.5))
                reachY = max(reachY, abs(point.y - 0.5))
            }
            spreadX = reachX
            spreadY = reachY
            hasAnyCommunities = !snapshot.communities.isEmpty || timeline.slices.contains { !$0.communities.isEmpty }
            let byName = NameSort.sorted(Array(snapshot.people.indices), name: { snapshot.people[$0].name },
                                         createdAt: { _ in Date.distantPast })
            var rank = [Int](repeating: 0, count: snapshot.people.count)
            for (order, i) in byName.enumerated() { rank[i] = order }
            nameRank = rank
            sliderValue = Double(timeline.slices.count)
            // CI 스크린샷 — 지난 시점의 관계도를 바로 연다 (`-timeSlice`).
            if let k = LaunchArguments.current.timeSlice, k < timeline.slices.count {
                sliderValue = Double(k)
            }
            refreshMembership()
            groupsItem = InputReadiness.evaluate(snapshot.readiness).first { $0.feature == .groups }
            // 떠 있는 카드는 같은 사람을 새 자료에서 다시 찾는다 (이슈 51). CI 스크린샷은 이름으로 미리 고른다 (`-graphSelect`).
            if floatsCard {
                if selectedID == nil, let name = LaunchArguments.current.graphSelect {
                    selectedID = snapshot.people.first { $0.name == name }?.id
                }
                selected = selectedID.flatMap { id in snapshot.people.firstIndex { $0.id == id } }
                if selected == nil { selectedID = nil }
                selectedDetail = selected.map { detail(forIndex: $0) } ?? ""
            }
        }
        .onChange(of: sliderValue) { _, value in
            let k = Int(value.rounded())
            let next = k >= timeline.slices.count ? nil : k
            guard next != sliceIndex else { return }
            sliceIndex = next
            selected = nil
            selectedID = nil
            prepareSlice()
            refreshMembership()
            // 자리가 이미 있으면 바로 옮겨 가고, 없으면 셈이 끝날 때까지 앞 그림을 둔다.
            if let next {
                if let ready = slicePositions[next] { show(ready) }
            } else {
                show(snapshot.positions)
            }
        }
        .task(id: sliceIndex) {
            // 막대를 끄는 동안은 셈하지 않는다 — 멈추고 0.25초 뒤 그 시점의 자리를 셈한다.
            guard let k = sliceIndex, slicePositions[k] == nil, let slice else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let positions = await Self.layout(slice: slice, peopleCount: snapshot.people.count, start: snapshot.positions)
            guard !Task.isCancelled else { return }
            slicePositions[k] = positions
            if sliceIndex == k { show(positions) }
        }
        .task(id: moveStart) {
            // 옮겨 가기가 끝나면 프레임마다 그리기를 멈춘다.
            guard moveStart != nil else { return }
            try? await Task.sleep(for: .seconds(Self.moveDuration + 0.05))
            guard !Task.isCancelled else { return }
            moveStart = nil
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
            // 시점을 옮겨도 줄 수가 같게 (이슈 29) — 줄이 생기고 없어지면 관계도 칸 높이가 바뀌어 그림이 커졌다 작아졌다 했다.
            if hasAnyCommunities {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("모임").font(.scaled(13, weight: .semibold)).foregroundStyle(Color.muted)
                        if activeCommunities.isEmpty {
                            Text("이 시점에는 묶인 모임이 없습니다").font(.scaled(13)).foregroundStyle(Color.muted)
                        }
                        ForEach(activeCommunities) { community in
                            chip("\(community.name) \(community.memberIDs.count)", selected: highlightCommunity == community.id) {
                                toggleCommunity(community.id)
                            }
                        }
                    }
                    .frame(minHeight: Font.scaledLength(44))
                    .padding(.horizontal, 16)
                }
            }
            // 지난 시점에는 같은 소속 선을 그리지 않는다(소속에는 날짜가 없다) — 줄은 두고 흐리게.
            Toggle(isOn: $showsOrganization) {
                Text("같은 소속도 옅은 선으로 잇기").font(.scaled(14)).foregroundStyle(Color.bodyText)
            }
            .tint(Color.accent)
            .disabled(sliceIndex != nil)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    /// 아이패드의 위 줄 — 관계 유형 · 모임 칩을 한 줄에, 같은 소속 선은 오른쪽 끝에 (이슈 32).
    private var wideControls: some View {
        HStack(spacing: 12) {
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
                    // 시점을 옮겨도 칩 자리가 같게 (이슈 29).
                    if hasAnyCommunities {
                        Divider()
                            .frame(height: Font.scaledLength(20))
                        Text("모임").font(.scaled(13, weight: .semibold)).foregroundStyle(Color.muted)
                        if activeCommunities.isEmpty {
                            Text("이 시점에는 묶인 모임이 없습니다").font(.scaled(13)).foregroundStyle(Color.muted)
                        }
                        ForEach(activeCommunities) { community in
                            chip("\(community.name) \(community.memberIDs.count)", selected: highlightCommunity == community.id) {
                                toggleCommunity(community.id)
                            }
                        }
                    }
                }
                .frame(minHeight: Font.scaledLength(44))
                .padding(.leading, 16)
            }
            Toggle(isOn: $showsOrganization) {
                Text("같은 소속 선").font(.scaled(14)).foregroundStyle(Color.bodyText)
            }
            .tint(Color.accent)
            .disabled(sliceIndex != nil)
            .fixedSize()
            .padding(.trailing, 16)
        }
        .padding(.bottom, 4)
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
                    // 시점마다 글 길이가 달라도 같은 줄 수 자리를 늘 잡는다 (이슈 29). 아이패드는 폭이 넓어 한 줄 (이슈 32).
                    .lineLimit(wide ? 1 : 3, reservesSpace: true)
                    .minimumScaleFactor(wide ? 0.7 : 0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, compact || wide ? 4 : 10)
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
            if slice.steady > 0 { parts.append("앞 분기와 같은 모임 \(slice.steady)개") }
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
            // 누른 사람 칸과 안내 글이 같은 자리를 쓴다 — 사람 칸 높이를 늘 잡아 두어, 누르거나 시점을 옮겨도
            // 관계도 칸 높이가 바뀌지 않게 (이슈 29).
            ZStack(alignment: .topLeading) {
                // 큰 글씨에서는 잡아 두지 않는다 — 관계도 칸이 먼저 자리를 갖는다 (이슈 26).
                // 아이패드(누른 사람을 떠 있는 카드로 보이는 때)도 잡아 두지 않는다 (이슈 32 · 51).
                if !compact && !floatsCard {
                    personCard(name: " ", detail: " \n ")
                        .hidden()
                        .accessibilityHidden(true)
                }
                if let selected, selected < snapshot.people.count, !floatsCard {
                    let person = snapshot.people[selected]
                    NavigationLink(value: PersonID(id: person.id)) {
                        personCard(name: person.name, detail: selectedDetail)
                    }
                    .buttonStyle(.plain)
                } else if !compact && !floatsCard {
                    Text(Self.hint)
                        .font(.scaled(13))
                        .foregroundStyle(Color.muted)
                }
            }
            // 아이패드는 누른 사람을 관계도 위 카드로 보인다 (이슈 51) — 아래에는 안내 한 줄만, 늘 같은 높이로.
            if wide {
                Text(Self.hint)
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // 큰 글씨에서는 설명 글을 시트로 (이슈 26) — 위 줄 오른쪽의 설명 단추.
            if !compact && !floatsCard {
                // 지난 시점에는 지금의 숫자를 감추되 자리는 둔다 (이슈 29).
                readiness
                    .opacity(sliceIndex == nil ? 1 : 0)
                    .accessibilityHidden(sliceIndex != nil)
            }
            if !compact {
                RecordedScopeNotice()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 8 : (wide ? 6 : 16))
    }

    private func personCard(name: String, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.scaled(16, weight: .semibold)).foregroundStyle(Color.ink)
                    .lineLimit(compact ? 1 : nil)
                Text(detail).font(.scaled(13)).foregroundStyle(Color.muted).lineLimit(compact ? 1 : 2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.muted)
        }
        .padding(12)
        .background(Color.raised, in: RoundedRectangle(cornerRadius: 12))
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

    /// 0~1 자리를 화면 자리로 — 나(0.5)를 가운데 두고 키우고 옮긴다.
    /// 퍼진 거리를 칸의 가로 · 세로에 따로 맞춰 칸에 고루 편다 (이슈 32 · 전에는 짧은 쪽에 맞춘 정사각형이라 넓은 칸의 가운데만 찼다).
    /// 한쪽으로만 너무 늘이지 않는다 — 모임 모양이 알아볼 수 없게 납작해지지 않게.
    private func screenPoint(_ point: GraphLayout.Point, size: CGSize) -> CGPoint {
        var unitX = max(size.width / 2 - Self.edgeX, 20) / CGFloat(spreadX)
        var unitY = max(size.height / 2 - Self.edgeY, 20) / CGFloat(spreadY)
        let even = min(unitX, unitY)
        unitX = min(unitX, even * Self.maxStretch)
        unitY = min(unitY, even * Self.maxStretch)
        let baseX = (point.x - 0.5) * unitX
        let baseY = (point.y - 0.5) * unitY
        return CGPoint(x: size.width / 2 + baseX * scale + offset.width,
                       y: size.height / 2 + baseY * scale + offset.height)
    }

    private func isShown(_ i: Int) -> Bool {
        sliceIndex == nil || (i < slicePresent.count && slicePresent[i])
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, positions: [GraphLayout.Point]) {
        guard positions.count == snapshot.people.count + 1 else { return }
        // 앱을 쓰기 전 시기는 옅게 (D-32).
        if slice?.beforeUse == true { context.opacity = 0.55 }
        let highlighting = highlight != nil || highlightCommunity != nil

        // 이름표가 피할 칸 — 모임 이름 · 나 (이슈 30).
        var reserved: [LabelPlacement.Box] = []

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
                let title = context.resolve(Text(community.name).font(.scaledCapped(11, weight: .semibold)).foregroundStyle(Color.muted))
                let titleSize = title.measure(in: CGSize(width: 400, height: 100))
                context.draw(title, at: CGPoint(x: centerX, y: top.y - 20), anchor: .center)
                reserved.append(LabelPlacement.Box(centerX: centerX, centerY: top.y - 20,
                                                   width: titleSize.width, height: titleSize.height))
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
        var visible: [(index: Int, point: CGPoint)] = []
        for i in snapshot.people.indices where isShown(i) {
            let p = screenPoint(positions[i], size: size)
            guard p.x > -20, p.y > -20, p.x < size.width + 20, p.y < size.height + 20 else { continue }
            let faded = highlighting && !matches(i)
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(faded ? Color.faint.opacity(0.5) : Color.accent))
            if selected == i {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(Color.ink), lineWidth: 2)
            }
            visible.append((i, p))
        }

        // 나 — 가운데, 조금 크게, 고리. 이름은 늘 쓰고 다른 이름표가 비켜 간다.
        let me = screenPoint(positions[meIndex], size: size)
        let meRect = CGRect(x: me.x - 9, y: me.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: meRect), with: .color(Color.ink))
        context.stroke(Path(ellipseIn: meRect.insetBy(dx: -3, dy: -3)), with: .color(Color.accent), lineWidth: 2)
        let meTitle = context.resolve(Text(snapshot.meName ?? "나").font(.scaledCapped(12, weight: .semibold)).foregroundStyle(Color.ink))
        let meTitleSize = meTitle.measure(in: CGSize(width: 400, height: 100))
        context.draw(meTitle, at: CGPoint(x: me.x, y: me.y + 22), anchor: .center)
        reserved.append(LabelPlacement.Box(centerX: me.x, centerY: me.y, width: 24, height: 24))
        reserved.append(LabelPlacement.Box(centerX: me.x, centerY: me.y + 22, width: meTitleSize.width, height: meTitleSize.height))

        if showsNames {
            drawNames(in: &context, size: size, visible: visible, radius: radius, reserved: reserved, highlighting: highlighting)
        }
    }

    /// 사람 이름표 (이슈 30) — 이름끼리 · 점과 겹치지 않는 자리에만 쓴다(`Core.LabelPlacement`). 놓을 자리가 없으면 이번 크기에서는
    /// 비운다 — 두 손가락으로 키우면 자리가 생긴다. 차례는 누른 사람 → 강조한 사람 → 이름 순. 한 번에 150개까지.
    private func drawNames(in context: inout GraphicsContext, size: CGSize, visible: [(index: Int, point: CGPoint)],
                           radius: CGFloat, reserved: [LabelPlacement.Box], highlighting: Bool) {
        func group(_ i: Int) -> Int { i == selected ? 0 : (highlighting ? 1 : 2) }
        func order(_ i: Int) -> Int { i < nameRank.count ? nameRank[i] : i }
        let named = visible
            .filter { !highlighting || matches($0.index) || $0.index == selected }
            .sorted { (group($0.index), order($0.index)) < (group($1.index), order($1.index)) }
            .prefix(150)
        var texts: [GraphicsContext.ResolvedText] = []
        var requests: [LabelPlacement.Request] = []
        for item in named {
            let text = context.resolve(Text(snapshot.people[item.index].name).font(.scaledCapped(11)).foregroundStyle(Color.bodyText))
            let measured = text.measure(in: CGSize(width: 400, height: 100))
            texts.append(text)
            requests.append(LabelPlacement.Request(anchorX: item.point.x, anchorY: item.point.y, radius: radius,
                                                   width: measured.width, height: measured.height))
        }
        let dots = visible.map { LabelPlacement.Box(centerX: $0.point.x, centerY: $0.point.y, width: radius * 2, height: radius * 2) }
        let placed = LabelPlacement.place(requests, obstacles: dots + reserved,
                                          bounds: LabelPlacement.Box(x: 0, y: 0, width: size.width, height: size.height))
        for (k, box) in placed.enumerated() {
            guard let box else { continue }
            context.draw(texts[k], at: CGPoint(x: box.centerX, y: box.centerY), anchor: .center)
        }
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

    /// 그 순간 그릴 자리 — 옮겨 가는 중이면 앞 자리와 새 자리 사이 (처음 빠르고 끝에 느리게).
    private func displayedPositions(at date: Date) -> [GraphLayout.Point] {
        let target = activePositions
        guard let start = moveStart, fromPositions.count == target.count else { return target }
        let progress = min(max(date.timeIntervalSince(start) / Self.moveDuration, 0), 1)
        guard progress < 1 else { return target }
        let eased = 1 - pow(1 - progress, 3)
        return zip(fromPositions, target).map { from, to in
            GraphLayout.Point(x: from.x + (to.x - from.x) * eased, y: from.y + (to.y - from.y) * eased)
        }
    }

    /// 새 자리로 옮겨 간다. 동작 줄이기를 켜 두었으면 바로 (요구사항 8.6 · D-33).
    private func show(_ target: [GraphLayout.Point]) {
        guard target != shownPositions else { return }
        guard !reduceMotion, !shownPositions.isEmpty, shownPositions.count == target.count else {
            moveStart = nil
            shownPositions = target
            return
        }
        fromPositions = displayedPositions(at: Date())
        shownPositions = target
        moveStart = Date()
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
