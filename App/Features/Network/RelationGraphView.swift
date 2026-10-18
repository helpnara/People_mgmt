import Core
import SwiftUI

/// **관계도** (FR-047 · 048 · 2026-10-18 사용자 결정) — 나를 가운데 두고, 이어진 사람끼리 모이게.
///
/// - 진한 선: 함께한 기록 · 소개. 함께한 기록이 많을수록 조금 굵다.
/// - 옅은 점선: 같은 소속 (끄고 켤 수 있다).
/// - 점은 **모두 같은 크기 · 같은 색**이다 — 크기 · 거리로 사람을 줄 세우지 않는다 (ADR-0004).
///   관계 유형 칩을 고르면 그 유형만 진하게 보인다 (사람이 많아 유형마다 색을 나누면 구분이 안 된다).
/// - 모임 (D-30): 조건이 차면 Louvain 으로 찾은 묶음을 옅은 테두리로 감싸고 이름을 단다. 모임 칩을 고르면 그 모임만 진하게.
struct RelationGraphView: View {
    let snapshot: NetworkSnapshot

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var highlight: String?
    @State private var showsOrganization = true
    @State private var selected: Int?
    @State private var selectedDetail = ""
    @State private var typeChips: [String] = []
    /// 고른 모임 (`snapshot.communities` 의 id). 관계 유형 칩과 함께 고르지 않는다.
    @State private var highlightCommunity: Int?
    /// 사람 자리 → 모임 id.
    @State private var membership: [Int: Int] = [:]
    @State private var groupsItem: ReadinessItem?

    private var meIndex: Int { snapshot.people.count }

    var body: some View {
        VStack(spacing: 0) {
            controls
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
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                    }
                }
                .onTapGesture { location in
                    selected = nearest(to: location, size: size)
                    selectedDetail = selected.map { detail(forIndex: $0) } ?? ""
                }
                .accessibilityElement()
                .accessibilityLabel("관계도 — 사람 \(snapshot.people.count)명, 이어진 선 \(snapshot.edges.count)개. 아래 특성 · 돌아보기에서 목록으로 볼 수 있습니다.")
            }
            .clipped()
            .background(Color.raised)
            footer
        }
        .task(id: snapshot.generation) {
            let buckets = TraitDistribution.buckets(snapshot.people.map { (id: $0.id, values: [$0.relationshipType ?? ""]) }, limit: 8)
            typeChips = buckets.filter { !$0.isRest && !$0.isUnspecified }.map(\.label)
            var map: [Int: Int] = [:]
            for community in snapshot.communities {
                for i in community.memberIndices { map[i] = community.id }
            }
            membership = map
            // 다시 만든 자료는 차례가 달라질 수 있다 — 고른 사람을 푼다.
            selected = nil
            if let id = highlightCommunity, !snapshot.communities.contains(where: { $0.id == id }) { highlightCommunity = nil }
            groupsItem = InputReadiness.evaluate(snapshot.readiness).first { $0.feature == .groups }
        }
    }

    // MARK: - 위 · 아래

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("전체", selected: highlight == nil && highlightCommunity == nil) {
                        highlight = nil
                        highlightCommunity = nil
                    }
                    ForEach(typeChips, id: \.self) { type in
                        chip(type, selected: highlight == type) {
                            highlight = highlight == type ? nil : type
                            highlightCommunity = nil
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            if !snapshot.communities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("모임").font(.scaled(13, weight: .semibold)).foregroundStyle(Color.muted)
                        ForEach(snapshot.communities) { community in
                            chip("\(community.name) \(community.memberIDs.count)", selected: highlightCommunity == community.id) {
                                highlightCommunity = highlightCommunity == community.id ? nil : community.id
                                highlight = nil
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Toggle(isOn: $showsOrganization) {
                Text("같은 소속도 옅은 선으로 잇기").font(.scaled(14)).foregroundStyle(Color.bodyText)
            }
            .tint(Color.accent)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: text, selected: selected)
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
                            Text(selectedDetail).font(.scaled(13)).foregroundStyle(Color.muted).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.faint)
                    }
                    .padding(12)
                    .background(Color.raised, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("점을 누르면 그 사람을 봅니다. 두 손가락으로 키우고 옮기고, 두 번 누르면 처음 크기로.")
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
            }
            readiness
            RecordedScopeNotice()
        }
        .padding(16)
    }

    /// 무엇이 선이 되는지와 지금 얼마나 이어졌는지 · 모임을 찾으려면 무엇이 더 있어야 하는지.
    private var readiness: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("진한 선 \(snapshot.readiness.strongEdges)개 · 서로 이어진 사람 \(snapshot.readiness.linkedPeople)명 / \(snapshot.people.count)명")
                .font(.scaled(13, weight: .medium))
                .foregroundStyle(Color.bodyText)
                .monospacedDigit()
            Text(snapshot.readiness.strongEdges == 0
                 ? "아직 사람끼리 이어진 선이 없습니다. 기록의 함께한 사람에 두 명 이상을 넣거나, 사람 편집의 아는 사이에서 서로 아는 사람을 고르거나, 알게 된 경로를 소개로 하고 소개한 사람을 고르면 선이 생깁니다."
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
        let links = snapshot.edges.filter { $0.isStrong && ($0.a == person.id || $0.b == person.id) }.count
        let community = membership[i].flatMap { id in snapshot.communities.first { $0.id == id } }
        let parts = [person.subtitle, community.map { "모임 " + $0.name },
                     links > 0 ? "이어진 사람 \(links)명" : "아직 이어진 사람 없음"].compactMap { $0 }
        return parts.joined(separator: " · ")
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

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let positions = snapshot.positions
        guard positions.count == snapshot.people.count + 1 else { return }
        var index: [UUID: Int] = [:]
        for (i, person) in snapshot.people.enumerated() { index[person.id] = i }

        // 모임 — 옅은 테두리. 채운 볼록 껍질에 굵고 둥근 선을 겹쳐 점 둘레에 여백을 둔다. 한 층으로 그려 겹친 곳이 진해지지 않게.
        for community in snapshot.communities {
            let points = community.memberIndices.map { screenPoint(positions[$0], size: size) }
            let hull = Self.convexHull(points)
            guard let first = hull.first else { continue }
            var path = Path()
            path.move(to: first)
            for point in hull.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            var layer = context
            layer.opacity = highlightCommunity == nil ? 0.10 : (highlightCommunity == community.id ? 0.22 : 0.04)
            layer.drawLayer { inner in
                inner.fill(path, with: .color(Color.accent))
                inner.stroke(path, with: .color(Color.accent), style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))
            }
            if highlightCommunity == nil || highlightCommunity == community.id,
               let top = hull.min(by: { $0.y < $1.y }) {
                let centerX = hull.map(\.x).reduce(0, +) / CGFloat(hull.count)
                context.draw(Text(community.name).font(.scaled(11, weight: .semibold)).foregroundStyle(Color.muted),
                             at: CGPoint(x: centerX, y: top.y - 20), anchor: .center)
            }
        }

        // 선
        var weak = Path()
        for edge in snapshot.edges {
            guard let i = index[edge.a], let j = index[edge.b] else { continue }
            let a = screenPoint(positions[i], size: size)
            let b = screenPoint(positions[j], size: size)
            if edge.isStrong {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                let faded = (highlight != nil || highlightCommunity != nil) && !(matches(i) && matches(j))
                context.stroke(path, with: .color(Color.accent.opacity(faded ? 0.12 : 0.55)),
                               lineWidth: 1 + CGFloat(min(edge.together, 4)) * 0.5)
            } else if showsOrganization && edge.sameOrganization {
                weak.move(to: a)
                weak.addLine(to: b)
            }
        }
        if showsOrganization {
            context.stroke(weak, with: .color(Color.faint.opacity(0.7)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }

        // 점
        let radius: CGFloat = 5
        let showsNames = snapshot.people.count <= 40 || scale >= 2.5
        var labels = 0
        for (i, person) in snapshot.people.enumerated() {
            let p = screenPoint(positions[i], size: size)
            guard p.x > -20, p.y > -20, p.x < size.width + 20, p.y < size.height + 20 else { continue }
            let faded = (highlight != nil || highlightCommunity != nil) && !matches(i)
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(faded ? Color.faint.opacity(0.5) : Color.accent))
            if selected == i {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(Color.ink), lineWidth: 2)
            }
            if showsNames && !faded && labels < 150 {
                labels += 1
                context.draw(Text(person.name).font(.scaled(11)).foregroundStyle(Color.bodyText),
                             at: CGPoint(x: p.x, y: p.y + radius + 8), anchor: .center)
            }
        }

        // 나 — 가운데, 조금 크게, 고리
        let me = screenPoint(positions[meIndex], size: size)
        let meRect = CGRect(x: me.x - 9, y: me.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: meRect), with: .color(Color.ink))
        context.stroke(Path(ellipseIn: meRect.insetBy(dx: -3, dy: -3)), with: .color(Color.accent), lineWidth: 2)
        context.draw(Text(snapshot.meName ?? "나").font(.scaled(12, weight: .semibold)).foregroundStyle(Color.ink),
                     at: CGPoint(x: me.x, y: me.y + 22), anchor: .center)
    }

    private func matches(_ i: Int) -> Bool {
        if let highlightCommunity {
            return i < snapshot.people.count && membership[i] == highlightCommunity
        }
        guard let highlight else { return true }
        guard i < snapshot.people.count else { return true }
        return NameSort.key(snapshot.people[i].relationshipType ?? "") == NameSort.key(highlight)
    }

    /// 누른 자리에서 가장 가까운 사람 (22pt 안). 없으면 고른 것을 푼다.
    private func nearest(to location: CGPoint, size: CGSize) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for i in snapshot.people.indices {
            let p = screenPoint(snapshot.positions[i], size: size)
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
