import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case library, mardi, graph, timeline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .library: "library"
        case .mardi: "mardi"
        case .graph: "graph"
        case .timeline: "timeline"
        }
    }
    var symbol: String {
        switch self {
        case .library: "books.vertical"
        case .mardi: "sparkles.rectangle.stack"
        case .graph: "circle.grid.cross"
        case .timeline: "calendar"
        }
    }
    var glyph: String {
        switch self {
        case .library: "⠿"
        case .mardi: "⣿"
        case .graph: "⡶"
        case .timeline: "⠶"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var tab: DashboardTab = .library
    @State private var searchText: String = ""
    @State private var typeFilter: MemoryType? = nil
    @State private var folderFilter: String? = nil
    @State private var dayFilter: Date? = nil
    @State private var selected: Memory? = nil
    @State private var memories: [Memory] = []
    @State private var showOnboarding: Bool = false
    /// Drives subtree re-render whenever zoom changes from anywhere
    /// (menu, settings, another view). Typeface helpers read the same key.
    @AppStorage(UIZoom.key) private var zoom: Double = UIZoom.defaultValue

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            BrailleDivider(color: Palette.neonMagenta.opacity(0.35))
                .padding(.horizontal, 0)
                .background(Palette.panelSlate)
            Group {
                switch tab {
                case .library:
                    LibraryView(
                        typeFilter: $typeFilter,
                        folderFilter: $folderFilter,
                        dayFilter: $dayFilter,
                        searchText: $searchText,
                        selected: $selected,
                        memories: memories
                    )
                case .mardi:
                    MardiDashboardView(workspace: env.agent)
                case .graph:
                    GraphView(tab: $tab, selectedMemory: $selected)
                case .timeline:
                    MardiTimelineView(tab: $tab, dayFilter: $dayFilter)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.35, fontSize: 12, density: 0.22)
            }
        )
        .overlay {
            ToastOverlay()
        }
        .colorScheme(.dark)
        .task(id: reloadKey) {
            await reload()
        }
        .task {
            await reload()
        }
        .onAppear {
            if !env.settings.hasOnboarded {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
                .environmentObject(env)
        }
    }

    private var reloadKey: String {
        let day = dayFilter.map { String(Int($0.timeIntervalSince1970)) } ?? "any"
        return "\(typeFilter?.rawValue ?? "all")-\(folderFilter ?? "all-folders")-\(day)-\(searchText)"
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            // Wordmark — ⣿⣿ [MARDI] ⣿⣿
            HStack(spacing: 8) {
                Text("⣿⣿")
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Text("[MARDI]")
                    .monoFont(11, weight: .bold)
                    .tracking(2.5)
                    .foregroundStyle(Palette.textPrimary)
                Text("⣿⣿")
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Divider dot
            Text("⠒")
                .monoFont(9)
                .foregroundStyle(Palette.border)
                .padding(.horizontal, 4)

            ForEach(DashboardTab.allCases) { t in
                Button(action: { tab = t }) {
                    HStack(spacing: 5) {
                        Text(t.glyph)
                            .monoFont(10)
                        Text(t.label)
                            .monoFont(10, weight: tab == t ? .semibold : .regular)
                            .tracking(1.2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .foregroundStyle(tab == t ? Palette.textPrimary : Palette.textMuted)
                    .background(
                        tab == t
                            ? Palette.neonMagenta.opacity(0.08)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if tab == t {
                            Rectangle()
                                .fill(Palette.neonMagenta)
                                .frame(height: 1)
                                .shadow(color: Palette.neonMagenta.opacity(0.55), radius: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let err = env.bootError {
                HStack(spacing: 5) {
                    Text("⡏⠯")
                        .monoFont(9)
                        .foregroundStyle(Palette.neonRed)
                    Text(err)
                        .monoFont(9)
                        .foregroundStyle(Palette.neonRed)
                }
                .padding(.horizontal, 10)
            }

            SettingsLink {
                HStack(spacing: 4) {
                    Text("⠶")
                        .monoFont(10)
                    Text("cfg")
                        .monoFont(9)
                        .tracking(1.5)
                }
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")
            .keyboardShortcut(",", modifiers: .command)
        }
        .frame(height: 44)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.55, fontSize: 10, density: 0.38)
                Scanlines(opacity: 0.07, spacing: 3)
            }
        )
    }

    private func reload() async {
        if searchText.isEmpty && typeFilter == nil && folderFilter == nil && dayFilter == nil {
            memories = env.recentMemories
            return
        }
        do {
            if !searchText.isEmpty {
                var hits = try await env.search.search(query: searchText, type: typeFilter, folder: folderFilter, k: 200)
                if let day = dayFilter {
                    let cal = Calendar(identifier: .gregorian)
                    let start = cal.startOfDay(for: day)
                    let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
                    hits = hits.filter { $0.created >= start && $0.created < end }
                }
                memories = hits
            } else {
                memories = try await env.store.all(type: typeFilter, folder: folderFilter, day: dayFilter, limit: 500)
            }
        } catch {
            memories = []
        }
    }
}

