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
    @State private var selected: Memory? = nil
    @State private var memories: [Memory] = []

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
                        searchText: $searchText,
                        selected: $selected,
                        memories: memories
                    )
                case .mardi:
                    MardiDashboardView(workspace: env.agent)
                case .graph:
                    GraphPlaceholderView()
                case .timeline:
                    TimelinePlaceholderView()
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
        .colorScheme(.dark)
        .task(id: "\(typeFilter?.rawValue ?? "all")-\(folderFilter ?? "all-folders")-\(searchText)") {
            await reload()
        }
        .task {
            await reload()
        }
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
        if searchText.isEmpty && typeFilter == nil && folderFilter == nil {
            memories = env.recentMemories
        } else {
            do {
                memories = try await env.search.search(query: searchText, type: typeFilter, folder: folderFilter, k: 100)
            } catch {
                memories = []
            }
        }
    }
}

private struct GraphPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶")
                .monoFont(16)
                .foregroundStyle(Palette.neonViolet.opacity(0.45))
            AgentHeader(title: "graph", subtitle: "force-directed layout · v0.5", tint: Palette.neonViolet)
                .frame(maxWidth: 380)
            Text("Edges: shared tags + embedding similarity > 0.85")
                .monoFont(9).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

private struct TimelinePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿")
                .monoFont(16)
                .foregroundStyle(Palette.neonOrange.opacity(0.45))
            AgentHeader(title: "timeline", subtitle: "contribution heatmap · v0.5", tint: Palette.neonOrange)
                .frame(maxWidth: 380)
            Text("Captures per day, visualized.")
                .monoFont(9).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
