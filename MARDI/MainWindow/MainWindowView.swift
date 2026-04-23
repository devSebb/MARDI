import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case library, graph, timeline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .library: "Library"
        case .graph: "Graph"
        case .timeline: "Timeline"
        }
    }
    var symbol: String {
        switch self {
        case .library: "books.vertical"
        case .graph: "circle.grid.cross"
        case .timeline: "calendar"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var tab: DashboardTab = .library
    @State private var searchText: String = ""
    @State private var typeFilter: MemoryType? = nil
    @State private var selected: Memory? = nil
    @State private var memories: [Memory] = []

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().background(Palette.border)
            Group {
                switch tab {
                case .library:
                    LibraryView(
                        typeFilter: $typeFilter,
                        searchText: $searchText,
                        selected: $selected,
                        memories: memories
                    )
                case .graph:
                    GraphPlaceholderView()
                case .timeline:
                    TimelinePlaceholderView()
                }
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(Palette.charcoal)
        .colorScheme(.dark)
        .task(id: "\(typeFilter?.rawValue ?? "all")-\(searchText)") {
            await reload()
        }
        .task {
            await reload()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            Text("MARDI").monoFont(14, weight: .bold).foregroundStyle(Palette.phosphor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            ForEach(DashboardTab.allCases) { t in
                Button(action: { tab = t }) {
                    HStack(spacing: 5) {
                        Image(systemName: t.symbol).font(.system(size: 11))
                        Text(t.label).monoFont(11, weight: tab == t ? .bold : .regular)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(tab == t ? Palette.phosphor : Palette.textSecondary)
                    .background(
                        Rectangle()
                            .fill(tab == t ? Palette.phosphor.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let err = env.bootError {
                Text("⚠ \(err)").monoFont(10).foregroundStyle(Palette.rust)
            }

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")
            .keyboardShortcut(",", modifiers: .command)
        }
        .frame(height: 40)
        .background(Palette.panelSlate)
    }

    private func reload() async {
        if searchText.isEmpty && typeFilter == nil {
            memories = env.recentMemories
        } else {
            do {
                memories = try await env.search.search(query: searchText, type: typeFilter, k: 100)
            } catch {
                memories = []
            }
        }
    }
}

private struct GraphPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.grid.cross").font(.system(size: 40)).foregroundStyle(Palette.phosphorDim)
            Text("Graph view coming in v0.5").monoFont(12).foregroundStyle(Palette.textSecondary)
            Text("Force-directed layout of your memories, edges by shared tags + embedding similarity.")
                .monoFont(10).foregroundStyle(Palette.textMuted).multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct TimelinePlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar").font(.system(size: 40)).foregroundStyle(Palette.phosphorDim)
            Text("Timeline coming in v0.5").monoFont(12).foregroundStyle(Palette.textSecondary)
            Text("GitHub-style contribution heatmap of captures per day.")
                .monoFont(10).foregroundStyle(Palette.textMuted).multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
