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
            VStack(spacing: 10) {
                // Top row: robot + speech bubble
                HStack(alignment: .center, spacing: 8) {
                    MardiRobotView(mood: vm.mood, size: 72)
                    SpeechBubbleView(text: currentSpeech)
                    Spacer(minLength: 0)
                }

                // Body area
                Group {
                    switch vm.mode {
                    case .root:
                        rootButtons
                    case .capture(let type, let prefill):
                        CaptureFormView(
                            type: type,
                            prefill: prefill ?? .init(),
                            onCancel: { vm.mode = .root },
                            onSubmit: { title, body, tags in
                                vm.submitCapture(title: title, body: body, tagsRaw: tags, type: type, prefill: prefill)
                            }
                        )
                    case .search:
                        searchPanel
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Footer: search / gear / dismiss
                footer
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Palette.panelSlate)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Palette.border, lineWidth: 1.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.clear)
                    .scanlines(opacity: 0.04, spacing: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 18, y: 6)

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Palette.textMuted)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: 360)
        .colorScheme(.dark)
        .onAppear { vm.onSummon() }
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
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
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

            Button("back") { vm.mode = .root; vm.mood = .idle }
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
                    Image(systemName: "magnifyingglass")
                    Text("search")
                }
                .monoFont(10)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Palette.panelSlateHi)
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
                Text(type.emoji)
                Text(type.displayName)
                    .monoFont(11, weight: .medium)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(disabled ? Palette.panelSlateHi.opacity(0.4) : Palette.panelSlateHi)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(type.accent.opacity(disabled ? 0.2 : 0.5), lineWidth: 1)
                    )
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
                Text(memory.type.emoji)
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
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.panelSlateHi.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}
