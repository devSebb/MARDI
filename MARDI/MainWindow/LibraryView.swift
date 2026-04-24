import SwiftUI
import AppKit

struct LibraryView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var typeFilter: MemoryType?
    @Binding var folderFilter: String?
    @Binding var searchText: String
    @Binding var selected: Memory?
    let memories: [Memory]

    var body: some View {
        NavigationSplitView {
            SidebarView(typeFilter: $typeFilter, folderFilter: $folderFilter)
        } content: {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                if let folderFilter {
                    BrailleDivider(color: Palette.neonOrange.opacity(0.4)).padding(.horizontal, 4)
                    FolderCollectionHeader(folder: folderFilter, itemCount: memories.count) {
                        Task { await renameFolder(folderFilter) }
                    } onClear: {
                        self.folderFilter = nil
                    }
                }
                BrailleDivider(color: Palette.border).padding(.horizontal, 4)
                if memories.isEmpty {
                    emptyState
                } else {
                    MemoryListView(memories: memories, selected: $selected)
                }
            }
            .background(
                ZStack {
                    Palette.charcoal
                    BrailleField(color: Palette.brailleDim, opacity: 0.25, fontSize: 12, density: 0.2)
                }
            )
        } detail: {
            if let m = selected {
                MemoryDetailView(memory: m)
                    .id(m.id)
            } else {
                VStack(spacing: 18) {
                    MardiFishBrailleView(mood: .idle, size: 180)
                    SpeechBubbleView(text: env.recentMemories.isEmpty ? MardiVoice.emptyVault : "Pick something on the left.")
                    HStack(spacing: 5) {
                        Text("⠿").monoFont(9).foregroundStyle(Palette.neonCyan)
                        Text(env.recentMemories.isEmpty ? "vault · empty" : "vault · select memory")
                            .monoFont(9).tracking(1.5).foregroundStyle(Palette.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Palette.charcoal
                        BrailleField(color: Palette.brailleDim, opacity: 0.28, fontSize: 14, density: 0.18)
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("⠿⠿⠿")
                .pixelFont(16)
                .foregroundStyle(Palette.neonMagenta.opacity(0.45))
            Text(searchText.isEmpty ? MardiVoice.emptyVault : "No matches.")
                .monoFont(11)
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func renameFolder(_ current: String) async {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let panel = NSAlert()
        panel.messageText = "Rename Folder"
        panel.informativeText = "Update the folder name for all memories in this collection."
        let field = NSTextField(string: trimmed)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        panel.accessoryView = field
        panel.addButton(withTitle: "Rename")
        panel.addButton(withTitle: "Cancel")
        let response = panel.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let next = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty, next != trimmed else { return }
        let renamed = await env.renameFolder(from: trimmed, to: next)
        if renamed {
            folderFilter = next
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var typeFilter: MemoryType?
    @Binding var folderFilter: String?

    var body: some View {
        List {
            Section {
                Button {
                    typeFilter = nil
                    folderFilter = nil
                } label: {
                    SidebarRow(
                        glyph: "⣿",
                        label: "All",
                        count: env.countsByType.values.reduce(0, +),
                        isActive: typeFilter == nil && folderFilter == nil,
                        tint: Palette.neonCyan
                    )
                }
                .buttonStyle(.plain)

                ForEach(MemoryType.allCases.filter { $0 != .select }, id: \.self) { t in
                    Button {
                        typeFilter = t
                        folderFilter = nil
                    } label: {
                        SidebarRow(
                            glyph: t.glyph,
                            label: t.pluralName,
                            count: env.countsByType[t] ?? 0,
                            isActive: typeFilter == t,
                            tint: t.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack(spacing: 5) {
                    Text("⠿").monoFont(9).foregroundStyle(Palette.neonMagenta)
                    Text("library").monoFont(9).tracking(1.5).foregroundStyle(Palette.textMuted)
                }
                .padding(.bottom, 4)
            }

            if !env.countsByFolder.isEmpty {
                Section {
                    ForEach(sortedFolders, id: \.self) { folder in
                        Button {
                            folderFilter = folder
                            typeFilter = nil
                        } label: {
                            SidebarRow(
                                glyph: "⡶",
                                label: folder,
                                count: env.countsByFolder[folder] ?? 0,
                                isActive: folderFilter == folder,
                                tint: Palette.neonOrange
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("⡶").monoFont(9).foregroundStyle(Palette.neonOrange)
                        Text("folders").monoFont(9).tracking(1.5).foregroundStyle(Palette.textMuted)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 210)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.5, fontSize: 11, density: 0.35)
            }
        )
    }

    private var sortedFolders: [String] {
        env.countsByFolder.keys.sorted { lhs, rhs in
            let lc = env.countsByFolder[lhs] ?? 0
            let rc = env.countsByFolder[rhs] ?? 0
            if lc == rc { return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending }
            return lc > rc
        }
    }
}

private struct SidebarRow: View {
    let glyph: String
    let label: String
    let count: Int
    let isActive: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(glyph)
                .monoFont(11, weight: .bold)
                .foregroundStyle(isActive ? tint : tint.opacity(0.55))
                .frame(width: 14)
            Text(label.uppercased())
                .monoFont(10, weight: isActive ? .bold : .regular)
                .tracking(1.2)
                .foregroundStyle(isActive ? Palette.textPrimary : Palette.textSecondary)
            Spacer()
            Text("\(count)")
                .monoFont(9)
                .foregroundStyle(isActive ? tint : Palette.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isActive ? tint.opacity(0.10) : Color.clear)
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle()
                    .fill(tint)
                    .frame(width: 2)
                    .shadow(color: tint.opacity(0.55), radius: 1.5)
            }
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("⠿")
                .monoFont(11, weight: .bold)
                .foregroundStyle(Palette.neonCyan)
            TextField("", text: $text, prompt: Text("search memories…").foregroundStyle(Palette.textMuted))
                .textFieldStyle(.plain)
                .monoFont(12)
                .foregroundStyle(Palette.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Text("⡏⠯")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.textMuted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Palette.panelSlate)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}

private struct FolderCollectionHeader: View {
    let folder: String
    let itemCount: Int
    var onRename: () -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("⡶")
                        .monoFont(11, weight: .bold)
                        .foregroundStyle(Palette.neonOrange)
                    Text(folder.uppercased())
                        .monoFont(12, weight: .bold)
                        .tracking(1.5)
                        .foregroundStyle(Palette.textPrimary)
                }
                Text("\(itemCount) item\(itemCount == 1 ? "" : "s") · collection")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }

            Spacer()

            Button(action: onRename) {
                HStack(spacing: 4) {
                    Text("⠶").monoFont(9, weight: .bold)
                    Text("RENAME").monoFont(9, weight: .bold).tracking(1.2)
                }
                .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: onClear) {
                HStack(spacing: 4) {
                    Text("⠄").monoFont(9, weight: .bold)
                    Text("ALL").monoFont(9, weight: .bold).tracking(1.2)
                }
                .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [Palette.neonOrange.opacity(0.14), Palette.panelSlate],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

private struct MemoryRow: View {
    @EnvironmentObject var env: AppEnvironment
    let memory: Memory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if memory.type == .url, let thumbnail = memory.thumbnailPath {
                VaultThumbnailView(relativePath: thumbnail)
                    .frame(width: 76, height: 54)
                    .clipped()
                    .pixelBorder(Palette.neonViolet.opacity(0.6), width: 1.5)
            } else if memory.type == .url {
                URLRowFallback(domain: domain)
            } else {
                VStack(spacing: 2) {
                    Text(memory.type.glyph)
                        .monoFont(13, weight: .bold)
                        .foregroundStyle(memory.type.accent)
                    Text(memory.type.shortCode)
                        .monoFont(8, weight: .bold)
                        .tracking(0.5)
                        .foregroundStyle(memory.type.accent.opacity(0.7))
                }
                .frame(width: 36, height: 48)
                .background(Palette.panelSlateHi)
                .pixelBorder(memory.type.accent.opacity(0.45), width: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .monoFont(12, weight: .bold)
                    .lineLimit(1)
                    .foregroundStyle(Palette.textPrimary)
                if let s = memory.summary {
                    Text(s).bodyFont(11).lineLimit(2)
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(spacing: 5) {
                    if memory.type == .url, let domain {
                        pixelChip(text: domain, tint: Palette.neonViolet)
                    }
                    if let folder = memory.folder {
                        pixelChip(text: folder, tint: Palette.neonOrange)
                    }
                    ForEach(memory.tags.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .monoFont(9)
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Text(memory.created, style: .relative)
                        .monoFont(9)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func pixelChip(text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .monoFont(8, weight: .bold)
            .tracking(1.0)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14))
            .pixelBorder(tint.opacity(0.55), width: 1)
            .foregroundStyle(tint)
    }

    private var domain: String? {
        guard let raw = memory.sourceURL ?? URL(string: memory.body)?.absoluteString,
              let host = URL(string: raw)?.host else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

private struct URLRowFallback: View {
    let domain: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Palette.neonViolet.opacity(0.24), Palette.panelSlateHi],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .pixelBorder(Palette.neonViolet.opacity(0.5), width: 1)

            Text((domain ?? "link").uppercased())
                .monoFont(8, weight: .bold)
                .tracking(1.0)
                .foregroundStyle(Palette.neonViolet.opacity(0.5))
                .padding(6)
        }
        .frame(width: 76, height: 54)
    }
}

// MARK: - MemoryType pixel helpers

extension MemoryType {
    /// Braille glyph used everywhere instead of SF Symbols for type badges.
    var glyph: String {
        switch self {
        case .url: "⢸"
        case .snippet: "⠿"
        case .ssh: "⡶"
        case .prompt: "⣿"
        case .signature: "⠶"
        case .reply: "⢰"
        case .note: "⠉"
        case .select: "⡟"
        }
    }

    /// Three-letter uppercase shortcode for pixel type badges.
    var shortCode: String {
        switch self {
        case .url: "URL"
        case .snippet: "SNP"
        case .ssh: "SSH"
        case .prompt: "PRM"
        case .signature: "SIG"
        case .reply: "RPY"
        case .note: "NOT"
        case .select: "SEL"
        }
    }
}
