import Core
import SwiftUI

/// **관계도** (FR-047 · 048 · 2026-10-18 사용자 결정) — 나를 가운데 두고, 이어진 사람끼리 모이게.
///
/// - 진한 선: 함께한 기록 · 소개. 함께한 기록이 많을수록 조금 굵다.
/// - 옅은 점선: 같은 소속 (끄고 켤 수 있다).
/// - 점은 **모두 같은 크기 · 같은 색**이다 — 크기 · 거리로 사람을 줄 세우지 않는다 (ADR-0004).
///   관계 유형 칩을 고르면 그 유형만 진하게 보인다 (사람이 많아 유형마다 색을 나누면 구분이 안 된다).
struct RelationGraphView: View {
    let snapshot: NetworkSnapshot

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var highlight: String?
    @State private var showsOrganization = true
    @State private var selected: Int?
    @State private var typeChips: [String] = []

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
                }
                .accessibilityElement()
                .accessibilityLabel("관계도 — 사람 \(snapshot.people.count)명, 이어진 선 \(snapshot.edges.count)개. 아래 특성 · 돌아보기에서 목록으로 볼 수 있습니다.")
            }
            .clipped()
            .background(Color.raised)
            footer
        }
        .task(id: snapshot.people.count) {
            let buckets = TraitDistribution.buckets(snapshot.people.map { (id: $0.id, values: [$0.relationshipType ?? ""]) }, limit: 8)
            typeChips = buckets.filter { !$0.isRest && !$0.isUnspecified }.map(\.label)
        }
    }

    // MARK: - 위 · 아래

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("전체", selected: highlight == nil) { highlight = nil }
                    ForEach(typeChips, id: \.self) { type in
                        chip(type, selected: highlight == type) { highlight = highlight == type ? nil : type }
                    }
                }
                .padding(.horizontal, 16)
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
                            Text(selectedDetail(person)).font(.scaled(13)).foregroundStyle(Color.muted).lineLimit(1)
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
            RecordedScopeNotice()
        }
        .padding(16)
    }

    private func selectedDetail(_ person: NetworkSnapshot.PersonInfo) -> String {
        let links = snapshot.edges.filter { $0.isStrong && ($0.a == person.id || $0.b == person.id) }.count
        let parts = [person.subtitle, links > 0 ? "함께 이어진 사람 \(links)명" : "아직 함께한 기록 없음"].compactMap { $0 }
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
                let faded = highlight != nil && !(matches(i) && matches(j))
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
            let faded = highlight != nil && !matches(i)
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
}
