import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var typeFilter: MemoryType?
    @Binding var searchText: String
    @Binding var selected: Memory?
    let memories: [Memory]

    var body: some View {
        NavigationSplitView {
            SidebarView(typeFilter: $typeFilter)
        } content: {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                Divider().background(Palette.border)
                if memories.isEmpty {
                    emptyState
                } else {
                    MemoryListView(memories: memories, selected: $selected)
                }
            }
            .background(Palette.charcoal)
        } detail: {
            if let m = selected {
                MemoryDetailView(memory: m)
                    .id(m.id)
            } else {
                VStack(spacing: 10) {
                    MardiRobotView(mood: .idle, size: 80)
                    Text(env.recentMemories.isEmpty ? MardiVoice.emptyVault : "Pick something on the left.")
                        .monoFont(11).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.charcoal)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(searchText.isEmpty ? MardiVoice.emptyVault : "No matches.")
                .monoFont(12).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SidebarView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var typeFilter: MemoryType?

    var body: some View {
        List(selection: $typeFilter) {
            Section("LIBRARY") {
                Button {
                    typeFilter = nil
                } label: {
                    HStack {
                        Image(systemName: "tray.full")
                        Text("All")
                        Spacer()
                        Text("\(env.countsByType.values.reduce(0, +))")
                            .monoFont(10)
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(typeFilter == nil ? Palette.phosphor : Palette.textPrimary)

                ForEach(MemoryType.allCases, id: \.self) { t in
                    Button {
                        typeFilter = t
                    } label: {
                        HStack {
                            Image(systemName: t.symbol).foregroundStyle(t.accent)
                            Text(t.pluralName)
                            Spacer()
                            Text("\(env.countsByType[t] ?? 0)")
                                .monoFont(10)
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(typeFilter == t ? Palette.phosphor : Palette.textPrimary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .background(Palette.panelSlate)
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textSecondary)
            TextField("", text: $text, prompt: Text("Search memories…").foregroundStyle(Palette.textMuted))
                .textFieldStyle(.plain)
                .monoFont(12)
                .foregroundStyle(Palette.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textMuted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.panelSlate)
    }
}

struct MemoryListView: View {
    let memories: [Memory]
    @Binding var selected: Memory?

    var body: some View {
        List(selection: $selected) {
            ForEach(memories, id: \.id) { m in
                MemoryRow(memory: m)
                    .tag(m)
            }
        }
        .listStyle(.plain)
        .background(Palette.charcoal)
    }
}

private struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: memory.type.symbol)
                .foregroundStyle(memory.type.accent)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(memory.title).monoFont(12, weight: .bold).lineLimit(1)
                    .foregroundStyle(Palette.textPrimary)
                if let s = memory.summary {
                    Text(s).bodyFont(11).lineLimit(2)
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(spacing: 4) {
                    ForEach(memory.tags.prefix(4), id: \.self) { tag in
                        Text(tag).monoFont(9)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Palette.panelSlateHi)
                            )
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Text(memory.created, style: .relative)
                        .monoFont(9)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
