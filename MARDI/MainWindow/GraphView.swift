import SwiftUI

// MARK: - Graph view

/// Force-directed graph of every memory with an embedding.
///
/// Edges:
///   - **soft** (cyan, thin): two memories share at least one tag.
///   - **strong** (magenta, thicker): cosine similarity of their embeddings > 0.85.
///
/// Layout is **alive**: a velocity-based Fruchterman–Reingold simulation runs
/// every frame inside a `TimelineView(.animation)`. Damping bleeds energy out
/// after a few seconds so the graph rests quietly between interactions. Drag a
/// node to grab it — the rest of the cluster ripples in response. Drag empty
/// space to pan, scroll/pinch to zoom, tap a node to switch to the Library tab
/// with that memory selected. Pre-warmed for ~150 iterations off-main on data
/// load so the first frame is already a sensible layout, then the live sim
/// continues to refine.
struct GraphView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var tab: DashboardTab
    @Binding var selectedMemory: Memory?

    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var sim = GraphSimulation()
    @State private var loading: Bool = true
    @State private var hoveredID: String? = nil

    @State private var typeFilter: MemoryType? = nil

    // Viewport transform.
    // `pan` is the committed offset; `liveDragTranslation` accumulates the
    // current drag while it's in flight (so we don't commit until the user
    // lifts their finger). Same idea for zoom + pinchScale.
    @State private var pan: CGSize = .zero
    @State private var liveDragTranslation: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    // Combined gesture state machine.
    @State private var dragMode: DragMode = .idle

    private enum DragMode: Equatable {
        case idle
        case pan
        case node(id: String, startLogical: SIMD2<Double>)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            BrailleDivider(color: Palette.neonViolet.opacity(0.45)).padding(.horizontal, 4)
            GeometryReader { geo in
                ZStack {
                    Palette.charcoal
                    BrailleField(color: Palette.brailleDim, opacity: 0.18, fontSize: 14, density: 0.16)

                    if loading {
                        loadingOverlay
                    } else if filteredNodes.isEmpty {
                        emptyOverlay
                    } else {
                        liveCanvas(in: geo.size)
                    }
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(combinedDragGesture(in: geo.size))
                .simultaneousGesture(zoomGesture)
            }
            BrailleDivider(color: Palette.border).padding(.horizontal, 4)
            footer
        }
        .task {
            await load()
        }
    }

    // MARK: - Derived

    private var filteredNodes: [GraphNode] {
        guard let f = typeFilter else { return nodes }
        return nodes.filter { $0.type == f }
    }

    private var filteredIDs: Set<String> {
        Set(filteredNodes.map(\.id))
    }

    private var filteredEdges: [GraphEdge] {
        edges.filter { filteredIDs.contains($0.a) && filteredIDs.contains($0.b) }
    }

    private var neighbors: Set<String> {
        guard let id = hoveredID else { return [] }
        var out: Set<String> = [id]
        for e in filteredEdges where e.a == id || e.b == id {
            out.insert(e.a)
            out.insert(e.b)
        }
        return out
    }

    private var pinnedID: String? {
        if case .node(let id, _) = dragMode { return id }
        return nil
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("⡶⡶")
                        .monoFont(11)
                        .foregroundStyle(Palette.neonViolet)
                    Text("[MARDI :: GRAPH]")
                        .monoFont(12, weight: .bold)
                        .tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                }
                Text("\(filteredNodes.count) nodes · \(filteredEdges.count) edges · drag a node to move it · drag empty space to pan")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            typePicker
            Button(action: kick) {
                HStack(spacing: 5) {
                    Text("⠶")
                        .monoFont(10, weight: .bold)
                    Text("KICK")
                        .monoFont(10, weight: .bold)
                        .tracking(1.4)
                }
            }
            .buttonStyle(.pixel(Palette.neonViolet))
            .help("Inject energy and let the layout re-organize.")
            Button(action: resetViewport) {
                HStack(spacing: 5) {
                    Text("⡷")
                        .monoFont(10, weight: .bold)
                    Text("RESET VIEW")
                        .monoFont(10, weight: .bold)
                        .tracking(1.4)
                }
            }
            .buttonStyle(.pixel(Palette.textSecondary))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.40, fontSize: 10, density: 0.30)
            }
        )
    }

    private var typePicker: some View {
        Menu {
            Button("All Types") { typeFilter = nil }
            Divider()
            ForEach(MemoryType.allCases.filter { $0 != .select }, id: \.self) { t in
                Button(t.pluralName) { typeFilter = t }
            }
        } label: {
            HStack(spacing: 6) {
                Text(typeFilter?.glyph ?? "⣿")
                    .monoFont(10, weight: .bold)
                Text((typeFilter?.pluralName ?? "all").uppercased())
                    .monoFont(10, weight: .bold)
                    .tracking(1.3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(typeFilter?.accent ?? Palette.textSecondary)
            .background((typeFilter?.accent ?? Palette.border).opacity(0.10))
            .pixelBorder((typeFilter?.accent ?? Palette.border).opacity(0.55), width: 1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            legendDot(color: Palette.neonCyan, label: "shared tag")
            legendDot(color: Palette.neonMagenta, label: "embedding > 0.85")
            Spacer()
            simStatusPill
            HStack(spacing: 5) {
                Text("⠶").monoFont(9).foregroundStyle(Palette.textMuted)
                Text("zoom \(Int(zoom * 100))%")
                    .monoFont(9, weight: .bold)
                    .tracking(1.2)
                    .foregroundStyle(Palette.textMuted)
            }
            if let id = hoveredID, let node = nodes.first(where: { $0.id == id }) {
                BrailleDivider(color: Palette.border).frame(width: 24)
                Text(node.title)
                    .monoFont(9, weight: .bold)
                    .tracking(0.8)
                    .foregroundStyle(node.type.accent)
                    .lineLimit(1)
                    .frame(maxWidth: 260, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Palette.panelSlate)
    }

    /// Tiny indicator so you can tell whether the simulation is running.
    /// Active = small spinner glyph + cyan; settled = static dot + muted.
    private var simStatusPill: some View {
        HStack(spacing: 5) {
            Text(sim.isSettled ? "⠂" : "⣿")
                .monoFont(9, weight: .bold)
                .foregroundStyle(sim.isSettled ? Palette.textMuted : Palette.neonCyan)
            Text(sim.isSettled ? "settled" : "active")
                .monoFont(9, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(sim.isSettled ? Palette.textMuted : Palette.neonCyan)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 2)
                .shadow(color: color.opacity(0.5), radius: 2)
            Text(label)
                .monoFont(9, weight: .bold)
                .tracking(1.0)
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            Text("⣟⣷⣯⣽⣾⣻")
                .monoFont(18, weight: .bold)
                .foregroundStyle(Palette.neonViolet)
            BrailleLabel(text: "computing layout…", color: Palette.neonViolet, size: 10)
        }
    }

    private var emptyOverlay: some View {
        VStack(spacing: 14) {
            Text("⠿⠶⠿")
                .monoFont(18, weight: .bold)
                .foregroundStyle(Palette.neonViolet.opacity(0.5))
            BrailleLabel(text: "no nodes yet — capture some memories", color: Palette.textMuted, size: 10)
        }
    }

    // MARK: - Live canvas

    /// TimelineView fires every frame. We use that tick to advance the
    /// simulation and then redraw the Canvas. When the sim is settled and
    /// nothing is pinned, the tick becomes a no-op (cheap energy check) and
    /// the Canvas just re-renders unchanged frames — no actual physics work.
    private func liveCanvas(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            // Step the simulation. Mutating a class instance from inside the
            // body closure is safe — `sim` is a plain class, not @Published,
            // so SwiftUI doesn't observe property changes. The TimelineView
            // tick is what drives the re-render.
            let _ = sim.tick(
                at: context.date,
                nodes: filteredNodes,
                edges: filteredEdges,
                pinnedID: pinnedID
            )
            canvasBody(in: size)
        }
    }

    private func canvasBody(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let totalScale = zoom * pinchScale
        let totalPan = currentPan()

        return Canvas { ctx, _ in
            // Edges first so nodes draw over them.
            for edge in filteredEdges {
                guard
                    let pa = sim.positions[edge.a],
                    let pb = sim.positions[edge.b]
                else { continue }
                let highlighted = !neighbors.isEmpty && (neighbors.contains(edge.a) && neighbors.contains(edge.b))
                let dimmed = !neighbors.isEmpty && !highlighted
                let baseColor = edge.kind == .strong ? Palette.neonMagenta : Palette.neonCyan
                let opacity: Double = dimmed ? 0.06 : (highlighted ? 0.85 : (edge.kind == .strong ? 0.55 : 0.32))
                let lineWidth: CGFloat = edge.kind == .strong ? 1.2 : 0.8
                let path = Path { p in
                    p.move(to: project(pa, center: center, scale: totalScale, pan: totalPan))
                    p.addLine(to: project(pb, center: center, scale: totalScale, pan: totalPan))
                }
                ctx.stroke(path, with: .color(baseColor.opacity(opacity)), lineWidth: lineWidth)
            }

            // Nodes
            for node in filteredNodes {
                guard let pos = sim.positions[node.id] else { continue }
                let p = project(pos, center: center, scale: totalScale, pan: totalPan)
                let isPinned = pinnedID == node.id
                let isHovered = hoveredID == node.id || isPinned
                let isNeighbor = neighbors.contains(node.id) && !isHovered
                let isDimmed = !neighbors.isEmpty && !neighbors.contains(node.id)

                let radius: CGFloat = isPinned ? 9 : (isHovered ? 8 : (isNeighbor ? 6 : 5))
                let alpha: Double = isDimmed ? 0.18 : 1.0
                let color = node.type.accent.opacity(alpha)

                if isHovered || isPinned {
                    let glowR = radius + (isPinned ? 6 : 4)
                    let glowRect = CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2)
                    ctx.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(isPinned ? 0.30 : 0.20)))
                }
                let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(isPinned ? Palette.textPrimary.opacity(0.9) : Color.black.opacity(isDimmed ? 0.2 : 0.55)),
                    lineWidth: isPinned ? 1.5 : 0.8
                )

                if isHovered || isNeighbor || isPinned {
                    let label = Text(node.title.lowercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.textPrimary)
                    ctx.draw(label, at: CGPoint(x: p.x + radius + 4, y: p.y - 1), anchor: .leading)
                }
            }
        }
        .onContinuousHover { phase in
            // Don't re-target while the user is mid-drag — would feel jittery.
            guard dragMode == .idle else { return }
            switch phase {
            case .active(let location):
                hoveredID = nodeID(at: location, in: size)
            case .ended:
                hoveredID = nil
            }
        }
    }

    // MARK: - Coord-space helpers

    private func currentPan() -> CGSize {
        if dragMode == .pan {
            return CGSize(width: pan.width + liveDragTranslation.width, height: pan.height + liveDragTranslation.height)
        }
        return pan
    }

    private func project(_ logical: SIMD2<Double>, center: CGPoint, scale: CGFloat, pan: CGSize) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(logical.x) * scale + pan.width,
            y: center.y + CGFloat(logical.y) * scale + pan.height
        )
    }

    /// Inverse of `project` — screen point back to logical coords. Used when
    /// the user starts dragging a node so we can pin its logical position to
    /// follow the cursor regardless of pan/zoom.
    private func unproject(_ screen: CGPoint, in size: CGSize) -> SIMD2<Double> {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let totalScale = zoom * pinchScale
        let totalPan = currentPan()
        return SIMD2(
            Double((screen.x - center.x - totalPan.width) / totalScale),
            Double((screen.y - center.y - totalPan.height) / totalScale)
        )
    }

    private func nodeID(at point: CGPoint, in size: CGSize) -> String? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let totalScale = zoom * pinchScale
        let totalPan = currentPan()
        let hitRadius: CGFloat = 14
        var best: (id: String, dist: CGFloat)? = nil
        for node in filteredNodes {
            guard let pos = sim.positions[node.id] else { continue }
            let p = project(pos, center: center, scale: totalScale, pan: totalPan)
            let dx = p.x - point.x
            let dy = p.y - point.y
            let d = (dx * dx + dy * dy).squareRoot()
            if d < hitRadius && (best == nil || d < best!.dist) {
                best = (node.id, d)
            }
        }
        return best?.id
    }

    // MARK: - Gestures

    /// One DragGesture rules them all. On the first `.onChanged` we hit-test
    /// the start location and pick a mode (pan vs node-drag). Subsequent calls
    /// route translation accordingly. `.onEnded` checks for a tiny translation
    /// and treats it as a tap (navigate to the node, or clear hover).
    private func combinedDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragMode == .idle {
                    if let hitID = nodeID(at: value.startLocation, in: size),
                       let startLogical = sim.positions[hitID] {
                        dragMode = .node(id: hitID, startLogical: startLogical)
                        sim.wakeUp()
                    } else {
                        dragMode = .pan
                        liveDragTranslation = .zero
                    }
                }

                switch dragMode {
                case .idle:
                    return
                case .pan:
                    liveDragTranslation = value.translation
                case .node(let id, let startLogical):
                    let totalScale = zoom * pinchScale
                    guard totalScale > 0.0001 else { return }
                    let dlogical = SIMD2(
                        Double(value.translation.width / totalScale),
                        Double(value.translation.height / totalScale)
                    )
                    sim.pin(id: id, to: startLogical + dlogical)
                }
            }
            .onEnded { value in
                let mag = (value.translation.width * value.translation.width + value.translation.height * value.translation.height).squareRoot()
                let isTap = mag < 5

                switch dragMode {
                case .idle:
                    break
                case .pan:
                    if isTap {
                        // Background tap clears hover focus.
                        hoveredID = nil
                    } else {
                        pan.width += value.translation.width
                        pan.height += value.translation.height
                    }
                    liveDragTranslation = .zero
                case .node(let id, _):
                    if isTap {
                        navigate(to: id)
                    } else {
                        // Release pin without inertia — Obsidian-like settle.
                        sim.releasePin()
                        sim.wakeUp()
                    }
                }
                dragMode = .idle
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoom = max(0.3, min(3.5, zoom * value))
            }
    }

    private func navigate(to id: String) {
        Task { @MainActor in
            if let memory = try? await env.store.get(id: id) {
                selectedMemory = memory
                tab = .library
            }
        }
    }

    private func resetViewport() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = 1.0
            pan = .zero
        }
    }

    // MARK: - Load + kick

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let rows = try await env.store.allForGraph(limit: 600)
            let computed = await Task.detached(priority: .userInitiated) {
                buildGraph(from: rows)
            }.value
            self.nodes = computed.nodes
            self.edges = computed.edges
            self.sim.adopt(layout: computed.layout, jitter: 1.5)
        } catch {
            self.nodes = []
            self.edges = []
            self.sim.reset()
        }
    }

    /// "Kick" — inject energy and let the live sim re-organize without
    /// re-running the expensive pre-warm. Much faster than a full re-layout
    /// and the motion is visible to the user.
    private func kick() {
        sim.kick(strength: 80)
    }
}

// MARK: - Graph data

struct GraphNode: Identifiable, Sendable {
    let id: String
    let title: String
    let type: MemoryType
    let tags: Set<String>
}

struct GraphEdge: Sendable {
    enum Kind: Sendable { case soft, strong }
    let a: String
    let b: String
    let kind: Kind
    let weight: Double
}

private struct ComputedGraph {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let layout: [String: SIMD2<Double>]
}

private func buildGraph(from rows: [GraphNodeRow]) -> ComputedGraph {
    let nodes = rows.map {
        GraphNode(id: $0.id, title: $0.title.isEmpty ? "(untitled)" : $0.title, type: $0.type, tags: Set($0.tags))
    }
    var edges: [GraphEdge] = []
    if rows.count > 1 {
        for i in 0..<(rows.count - 1) {
            for j in (i + 1)..<rows.count {
                let a = rows[i]
                let b = rows[j]
                let shared = Set(a.tags).intersection(b.tags)
                let cosineValue = cosine(a.embedding, b.embedding)
                if cosineValue > 0.85 {
                    edges.append(GraphEdge(a: a.id, b: b.id, kind: .strong, weight: Double(cosineValue)))
                } else if !shared.isEmpty {
                    edges.append(GraphEdge(a: a.id, b: b.id, kind: .soft, weight: Double(shared.count)))
                }
            }
        }
    }
    // Quick pre-warm so the first paint is already a sensible layout —
    // the live sim then continues to refine over the next few seconds.
    let layout = preWarmLayout(nodes: nodes, edges: edges, iterations: 150)
    return ComputedGraph(nodes: nodes, edges: edges, layout: layout)
}

private func cosine(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        na += a[i] * a[i]
        nb += b[i] * b[i]
    }
    let denom = (na * nb).squareRoot()
    return denom == 0 ? 0 : dot / denom
}

/// Cooling Fruchterman–Reingold. Used only for the one-shot pre-warm so the
/// first frame of the live sim already looks reasonable. The live sim itself
/// is velocity-based and lives on `GraphSimulation`.
private func preWarmLayout(nodes: [GraphNode], edges: [GraphEdge], iterations: Int) -> [String: SIMD2<Double>] {
    guard !nodes.isEmpty else { return [:] }
    let area: Double = 800 * 800
    let k = (area / Double(nodes.count)).squareRoot()
    var positions: [String: SIMD2<Double>] = [:]
    var generator = SystemRandomNumberGenerator()
    for n in nodes {
        positions[n.id] = SIMD2(
            Double.random(in: -200...200, using: &generator),
            Double.random(in: -200...200, using: &generator)
        )
    }

    var temperature = 200.0
    let cooling = temperature / Double(iterations)
    let weakWeight = 0.4
    let strongWeight = 1.4

    for _ in 0..<iterations {
        var displacement: [String: SIMD2<Double>] = [:]
        for n in nodes { displacement[n.id] = SIMD2(0, 0) }

        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let aID = nodes[i].id
                let bID = nodes[j].id
                let pa = positions[aID]!
                let pb = positions[bID]!
                var delta = pa - pb
                var dist = (delta.x * delta.x + delta.y * delta.y).squareRoot()
                if dist < 0.01 {
                    delta = SIMD2(Double.random(in: -1...1), Double.random(in: -1...1))
                    dist = 1
                }
                let force = (k * k) / dist
                let push = (delta / dist) * force
                displacement[aID]! += push
                displacement[bID]! -= push
            }
        }

        for edge in edges {
            guard
                let pa = positions[edge.a],
                let pb = positions[edge.b]
            else { continue }
            let weight = edge.kind == .strong ? strongWeight : weakWeight
            var delta = pa - pb
            let dist = max(0.01, (delta.x * delta.x + delta.y * delta.y).squareRoot())
            let force = (dist * dist / k) * weight
            let pull = (delta / dist) * force
            displacement[edge.a]! -= pull
            displacement[edge.b]! += pull
        }

        for n in nodes {
            let pos = positions[n.id]!
            displacement[n.id]! -= pos * 0.012
        }

        for n in nodes {
            let disp = displacement[n.id]!
            let mag = (disp.x * disp.x + disp.y * disp.y).squareRoot()
            if mag > 0 {
                let limited = (disp / mag) * min(mag, temperature)
                positions[n.id]! += limited
            }
        }

        temperature = max(0.5, temperature - cooling)
    }
    return positions
}

// MARK: - Live simulation

/// Velocity-based Fruchterman–Reingold integrator.
///
/// Plain class on purpose — not `@Published`, not `@Observable`. The view
/// drives re-renders via `TimelineView(.animation)`, so observation here would
/// be redundant noise. The class just holds mutable state that the view reads
/// each frame.
///
/// Settling: kinetic energy averaged across all nodes is tracked each step;
/// when it falls below `settleThreshold` for `settleFrameCount` consecutive
/// frames the simulation marks itself settled and skips future steps until
/// re-perturbed (drag, kick, fresh data).
@MainActor
final class GraphSimulation {
    private(set) var positions: [String: SIMD2<Double>] = [:]
    private var velocities: [String: SIMD2<Double>] = [:]
    private var settledFrames: Int = 0
    private var lastTickDate: Date?
    private var pinnedID: String? = nil

    /// Tunables. Picked by feel — Obsidian-ish settle time of ~2-3s.
    private let damping: Double = 0.88
    private let maxSpeed: Double = 900
    private let gravity: Double = 0.018
    private let weakWeight: Double = 0.4
    private let strongWeight: Double = 1.4
    private let settleThreshold: Double = 0.8
    private let settleFrameCount: Int = 30
    private let maxDt: TimeInterval = 0.05  // clamp big jumps if app was backgrounded

    var isSettled: Bool { settledFrames >= settleFrameCount }

    // MARK: - Lifecycle

    func adopt(layout: [String: SIMD2<Double>], jitter: Double) {
        positions = layout
        velocities = [:]
        var rng = SystemRandomNumberGenerator()
        for id in positions.keys {
            // Tiny initial velocity so the live sim has something to do — the
            // first few seconds visibly refine the pre-warm layout instead of
            // snapping to a frozen graph.
            velocities[id] = SIMD2(
                Double.random(in: -jitter...jitter, using: &rng),
                Double.random(in: -jitter...jitter, using: &rng)
            )
        }
        settledFrames = 0
        lastTickDate = nil
        pinnedID = nil
    }

    func reset() {
        positions = [:]
        velocities = [:]
        settledFrames = 0
        lastTickDate = nil
        pinnedID = nil
    }

    /// Re-energize a settled simulation. Called after a node release, a kick,
    /// or any other perturbation so the system starts ticking again.
    func wakeUp() {
        settledFrames = 0
    }

    /// Visible nudge: gives every node a small random velocity and wakes the
    /// sim. Use case: the "KICK" button when the user wants to re-shuffle.
    func kick(strength: Double) {
        var rng = SystemRandomNumberGenerator()
        for id in velocities.keys {
            velocities[id] = SIMD2(
                Double.random(in: -strength...strength, using: &rng),
                Double.random(in: -strength...strength, using: &rng)
            )
        }
        settledFrames = 0
    }

    // MARK: - Pin (drag) support

    func pin(id: String, to logical: SIMD2<Double>) {
        pinnedID = id
        positions[id] = logical
        velocities[id] = .zero
    }

    func releasePin() {
        pinnedID = nil
    }

    // MARK: - Tick

    /// Returns true if the sim actually advanced. Returns false if settled
    /// and there's nothing pinned to keep it lively.
    @discardableResult
    func tick(at date: Date, nodes: [GraphNode], edges: [GraphEdge], pinnedID externalPinned: String?) -> Bool {
        // Sync external pin state (the view's drag mode) into our own.
        // The view authoritatively knows whether the user is dragging.
        self.pinnedID = externalPinned

        let dt: TimeInterval
        if let last = lastTickDate {
            dt = min(maxDt, date.timeIntervalSince(last))
        } else {
            dt = 1.0 / 60.0
        }
        lastTickDate = date

        if isSettled && externalPinned == nil {
            return false
        }

        step(dt: dt, nodes: nodes, edges: edges)
        return true
    }

    private func step(dt: TimeInterval, nodes: [GraphNode], edges: [GraphEdge]) {
        guard !nodes.isEmpty else { return }
        let area: Double = 800 * 800
        let k = (area / Double(nodes.count)).squareRoot()

        // Force accumulator. Initialize for every node we know about.
        var forces: [String: SIMD2<Double>] = [:]
        for n in nodes { forces[n.id] = .zero }

        // Repulsion — every pair pushes apart with k²/d.
        // Iterating over the nodes array (not the dict) so order is stable.
        for i in 0..<nodes.count {
            let aID = nodes[i].id
            guard let pa = positions[aID] else { continue }
            for j in (i + 1)..<nodes.count {
                let bID = nodes[j].id
                guard let pb = positions[bID] else { continue }
                var delta = pa - pb
                var dist = (delta.x * delta.x + delta.y * delta.y).squareRoot()
                if dist < 0.01 {
                    delta = SIMD2(Double.random(in: -1...1), Double.random(in: -1...1))
                    dist = 1
                }
                let mag = (k * k) / dist
                let push = (delta / dist) * mag
                forces[aID]! += push
                forces[bID]! -= push
            }
        }

        // Attraction along edges (Hooke-ish). Strong edges pull harder.
        for edge in edges {
            guard
                let pa = positions[edge.a],
                let pb = positions[edge.b]
            else { continue }
            let weight = edge.kind == .strong ? strongWeight : weakWeight
            var delta = pa - pb
            let dist = max(0.01, (delta.x * delta.x + delta.y * delta.y).squareRoot())
            let mag = (dist * dist / k) * weight
            let pull = (delta / dist) * mag
            forces[edge.a]! -= pull
            forces[edge.b]! += pull
        }

        // Gentle gravity to origin so disconnected components don't drift.
        for n in nodes {
            guard let pos = positions[n.id] else { continue }
            forces[n.id]! -= pos * gravity * k
        }

        // Integrate. Pinned node is held in place, but its position still
        // exerts forces on the rest (that's why connected nodes ripple).
        var energySum: Double = 0
        var moving = 0
        for n in nodes {
            if n.id == pinnedID {
                velocities[n.id] = .zero
                continue
            }
            guard var v = velocities[n.id], let f = forces[n.id] else { continue }
            v += f * dt
            v *= damping
            // Speed clamp to prevent runaway when the graph is briefly unstable.
            let speed = (v.x * v.x + v.y * v.y).squareRoot()
            if speed > maxSpeed {
                v = (v / speed) * maxSpeed
            }
            velocities[n.id] = v
            positions[n.id]! += v * dt
            energySum += v.x * v.x + v.y * v.y
            moving += 1
        }

        let avgEnergy = moving > 0 ? energySum / Double(moving) : 0
        if avgEnergy < settleThreshold {
            settledFrames += 1
        } else {
            settledFrames = 0
        }
    }
}
