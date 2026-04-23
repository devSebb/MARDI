import SwiftUI

/// Root of the monster panel. Composes the robot, speech bubble, and one of
/// three sub-views: root button grid, capture form, or search results.
struct MonsterView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var vm: MonsterViewModel
    var onOpenDashboard: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                panelHeader

                // Top row: robot + speech bubble
                HStack(alignment: .center, spacing: 10) {
                    MardiRobotView(mood: vm.mood, size: 92)
                    SpeechBubbleView(text: currentSpeech)
                    Spacer(minLength: 0)
                }

                // Body area
                ZStack(alignment: .topLeading) {
                    Group {
                        switch vm.mode {
                        case .root:
                            rootButtons
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        case .capture(let type, let prefill):
                            drawerShell(label: "capture", accent: type.accent, glyph: type.brailleGlyph) {
                                CaptureFormView(
                                    type: type,
                                    prefill: prefill ?? .init(),
                                    onCancel: { vm.mode = .root },
                                    onSubmit: { title, body, tags in
                                        vm.submitCapture(title: title, body: body, tagsRaw: tags, type: type, prefill: prefill)
                                    }
                                )
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                        case .search:
                            drawerShell(label: "recall", accent: Palette.pink, glyph: "⠿") {
                                searchPanel
                            }
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
                        }
                    }
                    .id(modeID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.snappy(duration: 0.24), value: vm.mode)

                // Footer: search / gear / dismiss
                footer
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.panelSlate)
                    .brailleField(opacity: 0.05)
                    .pixelBorder(color: Palette.ruleHi, glow: Palette.pink, cornerRadius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.clear)
                    .scanlines(opacity: 0.025, spacing: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, y: 8)

            // Close button
            Button(action: onDismiss) {
                Text("×")
                    .foregroundStyle(Palette.textMuted)
                    .monoFont(16, weight: .bold)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: 420)
        .colorScheme(.dark)
        .onAppear { vm.onSummon() }
    }

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Text("⣿⣿")
                .monoFont(11, weight: .bold)
                .foregroundStyle(Palette.pink)
            Text("[MARDI]")
                .monoFont(11, weight: .bold)
                .foregroundStyle(Palette.bone)
            Text("corner capture")
                .monoFont(9)
                .foregroundStyle(Palette.bone3)
            Spacer()
            Text(env.activeAppWatcher.context.label.uppercased())
                .monoFont(9)
                .foregroundStyle(Palette.bone2)
        }
        .padding(.horizontal, 2)
    }

    private var modeID: String {
        switch vm.mode {
        case .root: "root"
        case .capture(let type, _): "capture-\(type.rawValue)"
        case .search: "search"
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

    private var rootButtons: some View {
        let order = env.activeAppWatcher.context.primaryCaptureTypes
        let rest = MemoryType.allCases.filter { !order.contains($0) && $0 != .select }
        // Put prioritised types first, then the rest. Select is shown separately.
        let all = order + rest
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("⠿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.pink)
                Text("choose what to keep")
                    .monoFont(10)
                    .foregroundStyle(Palette.bone2)
                Spacer()
                Text("drawer 00")
                    .monoFont(9)
                    .foregroundStyle(Palette.bone3)
            }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(all, id: \.self) { type in
                    CaptureButton(type: type) { vm.beginCapture(type: type) }
                }
                // Select Mode placeholder — wired up in v0.5
                CaptureButton(type: .select, disabled: true) { }
            }
        }
    }

    private func drawerShell<Content: View>(
        label: String,
        accent: Color,
        glyph: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(glyph)
                    .monoFont(14, weight: .bold)
                    .foregroundStyle(accent)
                Text("[\(label)]")
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(Palette.bone)
                Spacer()
                Text("› slide-out drawer")
                    .monoFont(9)
                    .foregroundStyle(Palette.bone3)
            }
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.ink.opacity(0.72))
                .pixelBorder(color: accent.opacity(0.7), glow: accent, cornerRadius: 2)
        )
    }

    @ViewBuilder
    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.textSecondary)
                TextField("", text: Binding(
                    get: { vm.searchText },
                    set: { vm.updateSearch($0) }
                ), prompt: Text("ask Mardi to find…").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(12)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Palette.bubbleBg)
                    .pixelBorder(color: Palette.ruleHi, cornerRadius: 2)
            )

            if vm.searchResults.isEmpty {
                Text(vm.searchText.isEmpty ? "type to search" : "nothing matching")
                    .monoFont(11)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 3) {
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

            Button("‹ back") { vm.mode = .root; vm.mood = .idle }
                .buttonStyle(.plain)
                .monoFont(10)
                .foregroundStyle(Palette.textMuted)
                .padding(.top, 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button(action: {
                if case .search = vm.mode {
                    vm.mode = .root
                } else {
                    vm.enterSearch()
                }
            }) {
                HStack(spacing: 4) {
                    Text("⠿")
                    Text("recall")
                }
                .monoFont(10)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.panelSlateHi)
                        .pixelBorder(color: Palette.ruleHi, cornerRadius: 2)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(Palette.textSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            Button(action: onOpenDashboard) {
                Image(systemName: "rectangle.3.group")
                    .foregroundStyle(Palette.textSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Open MARDI dashboard")
        }
    }
}

// MARK: - Buttons

private struct CaptureButton: View {
    let type: MemoryType
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(type.brailleGlyph)
                    .foregroundStyle(type.accent)
                Text(type.displayName)
                    .monoFont(11, weight: .medium)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(disabled ? Palette.panelSlateHi.opacity(0.4) : Palette.panelSlateHi)
                    .pixelBorder(color: type.accent.opacity(disabled ? 0.25 : 0.7), glow: disabled ? nil : type.accent, cornerRadius: 2)
            )
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
                Text(memory.type.brailleGlyph)
                    .monoFont(14, weight: .bold)
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
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 2).fill(Palette.panelSlateHi.opacity(0.5)).pixelBorder(color: Palette.rule, cornerRadius: 2))
        }
        .buttonStyle(.plain)
    }
}
