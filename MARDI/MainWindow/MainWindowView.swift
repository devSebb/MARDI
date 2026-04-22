import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case library, mardi, graph, timeline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .library: "LIBRARY"
        case .mardi: "MARDI"
        case .graph: "GRAPH"
        case .timeline: "TIMELINE"
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
            BrailleDivider(color: Palette.neonMagenta.opacity(0.55))
                .padding(.horizontal, 4)
                .background(Palette.charcoal)
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
            HStack(spacing: 8) {
                Text("⣿⣿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Text("MARDI")
                    .pixelFont(14)
                    .tracking(3)
                    .foregroundStyle(Palette.neonCyan)
                    .shadow(color: Palette.neonCyan.opacity(0.4), radius: 2)
                Text("⣿⣿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Text("⠂⠂⠂")
                .monoFont(10)
                .foregroundStyle(Palette.border)
                .padding(.horizontal, 4)

            ForEach(DashboardTab.allCases) { t in
                Button(action: { tab = t }) {
                    HStack(spacing: 5) {
                        Text(t.glyph)
                            .monoFont(10, weight: .bold)
                        Text(t.label)
                            .monoFont(10, weight: tab == t ? .bold : .regular)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .foregroundStyle(tab == t ? Palette.neonCyan : Palette.textSecondary)
                    .background(
                        tab == t
                            ? Palette.neonCyan.opacity(0.10)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if tab == t {
                            Rectangle()
                                .fill(Palette.neonCyan)
                                .frame(height: 2)
                                .shadow(color: Palette.neonCyan.opacity(0.55), radius: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let err = env.bootError {
                HStack(spacing: 5) {
                    Text("⡏⠯")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.neonRed)
                    Text(err)
                        .monoFont(10)
                        .foregroundStyle(Palette.neonRed)
                }
                .padding(.horizontal, 10)
            }

            SettingsLink {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("CFG")
                        .monoFont(10, weight: .bold)
                        .tracking(1.5)
                }
                .foregroundStyle(Palette.textSecondary)
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
                BrailleField(color: Palette.brailleDim, opacity: 0.50, fontSize: 10, density: 0.45)
                Scanlines(opacity: 0.10, spacing: 3)
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
        VStack(spacing: 10) {
            Text("⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶⠶⡶")
                .pixelFont(18)
                .foregroundStyle(Palette.neonMagenta.opacity(0.55))
            BrailleLabel(text: "Graph // v0.5", color: Palette.neonMagenta, size: 11)
            Text("Force-directed layout of your memories.")
                .monoFont(10).foregroundStyle(Palette.textSecondary)
            Text("Edges: shared tags + embedding similarity > 0.85")
                .monoFont(9).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct TimelinePlaceholderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿⠶⠿")
                .pixelFont(18)
                .foregroundStyle(Palette.neonOrange.opacity(0.55))
            BrailleLabel(text: "Timeline // v0.5", color: Palette.neonOrange, size: 11)
            Text("Contribution heatmap of captures per day.")
                .monoFont(10).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
