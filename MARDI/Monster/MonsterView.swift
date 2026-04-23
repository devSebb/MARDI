import SwiftUI
import AppKit

/// Root of the monster panel. Composes the fishbowl character, speech bubble,
/// and one of three sub-views: root button grid, capture form, or search.
struct MonsterView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var vm: MonsterViewModel
    var onOpenDashboard: () -> Void
    var onDismiss: () -> Void

    @State private var customDrawerHeight: CGFloat? = nil
    @State private var dragStartHeight: CGFloat = 0

    private let drawerMinHeight: CGFloat = 90
    private let drawerMaxHeight: CGFloat = 560

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    titleBar

                    HStack(alignment: .center, spacing: 10) {
                        MardiFishBrailleView(mood: vm.mood, size: 82)
                        SpeechBubbleView(text: currentSpeech)
                        Spacer(minLength: 0)
                    }

                    Group {
                        switch vm.mode {
                        case .root:
                            rootBody
                        case .capture(let type, let prefill):
                            CaptureFormView(
                                type: type,
                                prefill: prefill ?? .init(),
                                onCancel: { vm.cancelCapture() },
                                onSubmit: { title, body, tags, folder in
                                    vm.submitCapture(title: title, body: body, tagsRaw: tags, folder: folder, type: type, prefill: prefill)
                                }
                            )
                        case .search:
                            searchPanel
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    footer
                }
                .padding(14)
                .background(
                    ZStack {
                        Palette.panelSlate
                        BrailleField(color: Palette.brailleDim, opacity: 0.50, fontSize: 11, density: 0.35)
                        Scanlines(opacity: 0.10, spacing: 3)
                    }
                )
                .pixelBorder(Palette.neonMagenta, width: 1, radius: 0)
                .shadow(color: Palette.neonMagenta.opacity(0.12), radius: 20, y: 5)
                .shadow(color: Color.black.opacity(0.6), radius: 10, y: 4)

                Button(action: onDismiss) {
                    Text("⡏⠯")
                        .monoFont(10)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.panelSlate)
                        .pixelBorder(Palette.border, width: 1)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Close (esc)")
            }

            if let drawerType = activeDrawerType {
                drawerBubble(type: drawerType)
            }
        }
        .frame(width: 400)
        .colorScheme(.dark)
        .onAppear { vm.onSummon() }
    }

    private var titleBar: some View {
        HStack(spacing: 6) {
            Text("⣿⣿")
                .monoFont(10)
                .foregroundStyle(Palette.neonMagenta.opacity(0.45))
            Text("mardi · fishbowl")
                .monoFont(10)
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
            Spacer()
            Text(statusPhrase)
                .monoFont(9)
                .tracking(1.3)
                .foregroundStyle(statusTint)
                .lineLimit(1)
        }
        .padding(.trailing, 44) // reserve space for the close button in the top-right corner
    }

    private var statusPhrase: String {
        switch vm.mood {
        case .idle: "· standby"
        case .summoned: "⠿ awake"
        case .listening: "⠿ listening"
        case .thinking: "⠿ thinking…"
        case .success: "⠿ saved"
        case .error: "⡏⠯ error"
        case .selectMode: "⡟ selecting"
        case .sleeping: "· sleeping"
        }
    }

    private var statusTint: Color {
        switch vm.mood {
        case .error: Palette.neonRed
        case .success: Palette.neonCyan
        case .thinking: Palette.neonOrange
        case .listening, .summoned: Palette.neonMagenta
        case .selectMode: Palette.neonViolet
        default: Palette.textSecondary
        }
    }

    private var currentSpeech: String {
        if let err = vm.errorMessage { return MardiVoice.errorGeneric(err) }
        if let saving = vm.savingMessage { return saving }
        if case .search = vm.mode { return "Ask, and I'll remember." }
        if case .capture(let t, _) = vm.mode { return "Saving a \(t.displayName)." }
        if !env.settings.hasAPIKey { return "Set an API key in Settings first." }
        return vm.speech
    }

    private var rootBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            rootButtons
            rootRecentsRow
        }
    }

    private var rootButtons: some View {
        let order = env.activeAppWatcher.context.primaryCaptureTypes
        let rest = MemoryType.allCases.filter { !order.contains($0) && $0 != .select }
        let all = (order + rest).filter { $0 != .note }
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 6
        ) {
            ForEach(all, id: \.self) { type in
                CaptureButton(type: type) { vm.beginCapture(type: type) }
            }
            CaptureButton(type: .note, title: "Other") { vm.beginCapture(type: .note) }
            CaptureButton(type: .select, disabled: true) { }
        }
    }

    private var browsableRecentTypes: [MemoryType] {
        let order = env.activeAppWatcher.context.primaryCaptureTypes
        let rest = MemoryType.allCases.filter { !order.contains($0) && $0 != .select }
        return (order + rest)
    }

    private var rootRecentsRow: some View {
        HStack(spacing: 5) {
            Text("⠿ BROWSE")
                .monoFont(9, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Palette.textMuted)
            ForEach(browsableRecentTypes, id: \.self) { type in
                let isActive = vm.drawerType == type && vm.drawerExpanded
                let count = recentForDrawer(type: type).count
                Button(action: { vm.toggleDrawer(for: type) }) {
                    HStack(spacing: 4) {
                        Text(type.glyph)
                            .monoFont(10, weight: .bold)
                            .foregroundStyle(isActive ? type.accent : type.accent.opacity(0.65))
                        if count > 0 {
                            Text("\(count)")
                                .monoFont(8, weight: .bold)
                                .foregroundStyle(isActive ? type.accent : Palette.textMuted)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isActive ? type.accent.opacity(0.18) : Palette.panelSlateHi)
                    .pixelBorder(isActive ? type.accent : Palette.border, width: 1)
                }
                .buttonStyle(.plain)
                .help("Browse recent \(type.pluralName.lowercased())")
            }
            Spacer(minLength: 0)
        }
    }

    private var activeDrawerType: MemoryType? {
        switch vm.mode {
        case .capture(let type, _):
            return type
        default:
            return vm.drawerType
        }
    }

    private func recentForDrawer(type: MemoryType) -> [Memory] {
        env.recentMemories
            .filter { $0.type == type }
            .sorted { $0.created > $1.created }
            .prefix(8)
            .map { $0 }
    }

    @ViewBuilder
    private func drawerBubble(type: MemoryType) -> some View {
        let memories = recentForDrawer(type: type)
        VStack(spacing: 0) {
            Button(action: { vm.toggleDrawer(for: type) }) {
                HStack(spacing: 8) {
                    Text(type.glyph)
                        .monoFont(11, weight: .bold)
                        .foregroundStyle(type.accent)
                    Text("RECENT \(type.pluralName.uppercased())")
                        .monoFont(10, weight: .bold)
                        .tracking(1.4)
                        .foregroundStyle(type.accent)
                    Text("\(memories.count)")
                        .monoFont(9)
                        .foregroundStyle(Palette.textMuted)
                    Spacer()
                    Text(vm.drawerExpanded ? "⣤" : "⣀")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if vm.drawerExpanded {
                BrailleDivider(color: type.accent.opacity(0.4))
                    .padding(.horizontal, 4)
                RecentDrawerContent(
                    type: type,
                    memories: memories,
                    scrollHeight: effectiveDrawerHeight(for: type),
                    onOpenDashboard: onOpenDashboard
                )
                .transition(.opacity.combined(with: .move(edge: .top)))

                if !memories.isEmpty {
                    BrailleDivider(color: type.accent.opacity(0.4))
                        .padding(.horizontal, 4)
                    resizeHandle(for: type)
                }
            }
        }
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.40, fontSize: 10, density: 0.28)
            }
        )
        .pixelBorder(type.accent.opacity(vm.drawerExpanded ? 0.75 : 0.45), width: 1.5, lit: vm.drawerExpanded)
        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
    }

    private func defaultDrawerHeight(for type: MemoryType) -> CGFloat {
        switch type {
        case .url: return 240
        case .reply, .signature: return 200
        default: return 170
        }
    }

    private func effectiveDrawerHeight(for type: MemoryType) -> CGFloat {
        customDrawerHeight ?? defaultDrawerHeight(for: type)
    }

    private func resizeHandle(for type: MemoryType) -> some View {
        HStack {
            Spacer()
            Text("⠒⠒⠒⠒⠒⠒⠒⠒")
                .monoFont(9, weight: .bold)
                .foregroundStyle(Palette.textMuted.opacity(0.65))
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .local)
                .onChanged { value in
                    if dragStartHeight == 0 {
                        dragStartHeight = effectiveDrawerHeight(for: type)
                    }
                    let proposed = dragStartHeight + value.translation.height
                    customDrawerHeight = max(drawerMinHeight, min(drawerMaxHeight, proposed))
                }
                .onEnded { _ in
                    dragStartHeight = 0
                }
        )
        .onTapGesture(count: 2) {
            let atMax = (customDrawerHeight ?? 0) >= drawerMaxHeight - 1
            withAnimation(.easeOut(duration: 0.18)) {
                customDrawerHeight = atMax ? nil : drawerMaxHeight
            }
        }
        .help("Drag to resize · double-click for full height")
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    @ViewBuilder
    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("⠿")
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(Palette.neonCyan)
                TextField("", text: Binding(
                    get: { vm.searchText },
                    set: { vm.updateSearch($0) }
                ), prompt: Text("ask mardi to find…").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(12)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(10)
            .background(Palette.bubbleBg)
            .pixelBorder(Palette.neonCyan.opacity(0.55), width: 1)

            if vm.searchResults.isEmpty {
                Text(vm.searchText.isEmpty ? "⠂ type to search" : "⠂ nothing matching")
                    .monoFont(10)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(vm.searchResults.prefix(6), id: \.id) { m in
                        SearchResultRow(memory: m) {
                            ClipboardReader.copy(m.body)
                            vm.savingMessage = "Copied \(m.type.displayName)."
                            vm.mood = .success
                            Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                vm.mood = .idle
                                vm.savingMessage = nil
                            }
                        }
                    }
                }
            }

            Button("⟵ BACK") { vm.mode = .root; vm.mood = .idle }
                .buttonStyle(.plain)
                .monoFont(9, weight: .bold)
                .tracking(1.3)
                .foregroundStyle(Palette.textMuted)
                .padding(.top, 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: {
                if case .search = vm.mode {
                    vm.mode = .root
                } else {
                    vm.enterSearch()
                }
            }) {
                HStack(spacing: 4) {
                    Text("⠿")
                        .monoFont(10, weight: .bold)
                    Text("SEARCH")
                        .monoFont(9, weight: .bold)
                        .tracking(1.3)
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Palette.panelSlateHi)
                .pixelBorder(Palette.border, width: 1)
            }
            .buttonStyle(.plain)

            Spacer()

            SettingsLink {
                HStack(spacing: 4) {
                    Text("⠶")
                        .monoFont(10, weight: .bold)
                    Text("CFG")
                        .monoFont(9, weight: .bold)
                        .tracking(1.3)
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Palette.panelSlateHi)
                .pixelBorder(Palette.border, width: 1)
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            Button(action: onOpenDashboard) {
                HStack(spacing: 4) {
                    Text("⣿")
                        .monoFont(10, weight: .bold)
                    Text("DASH")
                        .monoFont(9, weight: .bold)
                        .tracking(1.3)
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Palette.panelSlateHi)
                .pixelBorder(Palette.border, width: 1)
            }
            .buttonStyle(.plain)
            .help("Open MARDI dashboard")
        }
    }
}

private struct RecentDrawerContent: View {
    let type: MemoryType
    let memories: [Memory]
    let scrollHeight: CGFloat
    var onOpenDashboard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if memories.isEmpty {
                Text("⠂ No recent \(type.pluralName.lowercased()) yet.")
                    .monoFont(10)
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(memories, id: \.id) { memory in
                            if type == .url {
                                URLDrawerRow(memory: memory)
                            } else {
                                DrawerRow(memory: memory)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: scrollHeight)
            }

            BrailleDivider(color: Palette.border).padding(.horizontal, 4)
            Button(action: onOpenDashboard) {
                HStack(spacing: 5) {
                    Text("⣿")
                        .monoFont(10, weight: .bold)
                    Text("SEE ALL IN DASHBOARD")
                        .monoFont(9, weight: .bold)
                        .tracking(1.3)
                    Spacer()
                    Text("⢰")
                        .monoFont(9, weight: .bold)
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DrawerRow: View {
    let memory: Memory
    @State private var justCopied = false

    var body: some View {
        Button(action: copy) {
            HStack(alignment: .top, spacing: 8) {
                Text(memory.type.glyph)
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                    .frame(width: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(bodyPreview)
                        .monoFont(10)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        Text(memory.title)
                            .monoFont(9, weight: .medium)
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                        if let folder = memory.folder {
                            FolderChip(name: folder)
                        }
                        Spacer(minLength: 0)
                        Text(memory.created, style: .relative)
                            .monoFont(8)
                            .foregroundStyle(Palette.textMuted)
                    }
                }

                Text(justCopied ? "⠿" : "⢸")
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(justCopied ? Palette.neonCyan : Palette.textMuted)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Palette.panelSlateHi)
            .pixelBorder(Palette.border, width: 1)
        }
        .buttonStyle(.plain)
        .help("Click to copy")
    }

    private var bodyPreview: String {
        let trimmed = memory.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return memory.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? memory.title
        }
        return trimmed
    }

    private func copy() {
        ClipboardReader.copy(memory.body)
        justCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            justCopied = false
        }
    }
}

private struct URLDrawerRow: View {
    @EnvironmentObject var env: AppEnvironment
    let memory: Memory

    var body: some View {
        let url = resolvedURL
        let domain = url?.host?.replacingOccurrences(of: "www.", with: "") ?? "saved link"

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("[\(domain.uppercased())]")
                        .monoFont(8, weight: .bold)
                        .tracking(1.2)
                        .foregroundStyle(Palette.neonViolet.opacity(0.95))
                    if let folder = memory.folder {
                        FolderChip(name: folder)
                    }
                    Spacer(minLength: 0)
                    Text(memory.created, style: .relative)
                        .monoFont(8)
                        .foregroundStyle(Palette.textMuted)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .monoFont(11, weight: .bold)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                    if let summary = memory.summary, !summary.isEmpty {
                        Text(summary)
                            .monoFont(9)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(2)
                    } else if let absolute = url?.absoluteString {
                        Text(absolute)
                            .monoFont(9)
                            .foregroundStyle(Palette.textSecondary.opacity(0.9))
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 8) {
                    if let url {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            HStack(spacing: 3) {
                                Text("⡀⢀").monoFont(9, weight: .bold)
                                Text("OPEN").monoFont(9, weight: .bold).tracking(1.2)
                            }
                            .foregroundStyle(Palette.neonViolet)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { ClipboardReader.copy(url?.absoluteString ?? memory.body) }) {
                        HStack(spacing: 3) {
                            Text("⢸").monoFont(9, weight: .bold)
                            Text("COPY").monoFont(9, weight: .bold).tracking(1.2)
                        }
                        .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if !memory.markdownPath.isEmpty {
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                env.vault.rootURL.appendingPathComponent(memory.markdownPath)
                            ])
                        }) {
                            HStack(spacing: 3) {
                                Text("⡷").monoFont(9, weight: .bold)
                                Text("REVEAL").monoFont(9, weight: .bold).tracking(1.2)
                            }
                            .foregroundStyle(Palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let url = resolvedURL else { return }
            NSWorkspace.shared.open(url)
        }
        .background(
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let thumbnail = memory.thumbnailPath {
                        VaultThumbnailView(relativePath: thumbnail)
                            .scaledToFill()
                            .overlay(
                                LinearGradient(
                                    colors: [Palette.neonViolet.opacity(0.15), Color.black.opacity(0.50)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Palette.neonViolet.opacity(0.18), Palette.panelSlateHi],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .clipped()
                .pixelBorder(Palette.neonViolet.opacity(0.55), width: 1)

                Text(domain.uppercased())
                    .monoFont(14, weight: .bold)
                    .tracking(2)
                    .foregroundStyle(Palette.neonViolet.opacity(0.10))
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
            }
        )
    }

    private var resolvedURL: URL? {
        if let source = memory.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: source) {
            return url
        }

        let body = memory.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: body)
    }
}

private struct FolderChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 3) {
            Text("⡶").monoFont(8, weight: .bold)
            Text(name.uppercased())
                .monoFont(8, weight: .bold)
                .tracking(1.0)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Palette.neonOrange.opacity(0.12))
        .pixelBorder(Palette.neonOrange.opacity(0.6), width: 1)
        .foregroundStyle(Palette.neonOrange)
    }
}

// MARK: - Buttons

private struct CaptureButton: View {
    let type: MemoryType
    var title: String? = nil
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(type.glyph)
                    .monoFont(13, weight: .bold)
                    .foregroundStyle(disabled ? Palette.textMuted : type.accent)
                Text((title ?? type.displayName).uppercased())
                    .monoFont(12, weight: .bold)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(disabled ? Palette.panelSlateHi.opacity(0.4) : Palette.panelSlateHi)
            .pixelBorder(type.accent.opacity(disabled ? 0.2 : 0.55), width: 1)
            .foregroundStyle(disabled ? Palette.textMuted : Palette.textPrimary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct SearchResultRow: View {
    let memory: Memory
    var onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                Text(memory.type.glyph)
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(memory.title)
                        .monoFont(11, weight: .medium)
                        .lineLimit(1)
                        .foregroundStyle(Palette.textPrimary)
                    if let s = memory.summary {
                        Text(s)
                            .monoFont(9)
                            .lineLimit(1)
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                Spacer(minLength: 0)
                Text("⢸")
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Palette.panelSlateHi.opacity(0.5))
            .pixelBorder(Palette.border.opacity(0.5), width: 1)
        }
        .buttonStyle(.plain)
    }
}
