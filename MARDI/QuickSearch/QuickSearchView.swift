import SwiftUI

struct QuickSearchView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var text: String = ""
    @State private var results: [Memory] = []
    @State private var selectedIndex: Int = 0
    @FocusState private var focused: Bool
    var onClose: () -> Void
    var onOpenInDashboard: (Memory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("⣿⣿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Text("[MARDI::RECALL]")
                    .monoFont(10, weight: .bold)
                    .tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("⌘⇧M · ESC")
                    .monoFont(9, weight: .bold)
                    .tracking(1.3)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Palette.panelSlateHi)

            BrailleDivider(color: Palette.neonMagenta.opacity(0.4))
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Text("⠿")
                    .monoFont(14, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                TextField("", text: $text, prompt: Text("ask mardi…").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(16)
                    .foregroundStyle(Palette.textPrimary)
                    .focused($focused)
                    .onSubmit { submit() }
                    .onKeyPress(.escape) { onClose(); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            BrailleDivider(color: Palette.border).padding(.horizontal, 4)

            if !results.isEmpty {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, m in
                            Row(memory: m, isSelected: idx == selectedIndex) {
                                selectedIndex = idx
                                submit()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 320)
            } else if !text.isEmpty {
                HStack(spacing: 6) {
                    Text("⠂")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.textMuted)
                    Text("nothing matching").monoFont(11).foregroundStyle(Palette.textMuted)
                }
                .padding(20)
            } else {
                HStack(spacing: 6) {
                    Text("⠂")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.textMuted)
                    Text("Type to search · Enter copies to clipboard.")
                        .monoFont(11).foregroundStyle(Palette.textMuted)
                }
                .padding(20)
            }
        }
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.30, fontSize: 11, density: 0.22)
            }
        )
        .pixelBorder(Palette.neonMagenta, width: 1.5, lit: true, radius: 0)
        .shadow(color: Palette.neonMagenta.opacity(0.30), radius: 8, y: 4)
        .frame(width: 580)
        .colorScheme(.dark)
        .onAppear { focused = true }
        .task(id: text) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await reload()
        }
    }

    private func reload() async {
        do {
            if text.isEmpty {
                results = try await env.store.all(limit: 12)
            } else {
                results = try await env.search.search(query: text, k: 10)
            }
            if selectedIndex >= results.count { selectedIndex = max(0, results.count - 1) }
        } catch {
            results = []
        }
    }

    private func moveSelection(_ d: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + d))
    }

    private func submit() {
        guard selectedIndex < results.count else { return }
        let m = results[selectedIndex]
        ClipboardReader.copy(m.body)
        onClose()
    }
}

private struct Row: View {
    let memory: Memory
    let isSelected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text(memory.type.glyph)
                        .monoFont(12, weight: .bold)
                        .foregroundStyle(memory.type.accent)
                    Text(memory.type.shortCode)
                        .monoFont(7, weight: .bold)
                        .tracking(0.8)
                        .foregroundStyle(memory.type.accent.opacity(0.7))
                }
                .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(memory.title).monoFont(12, weight: .bold)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if let s = memory.summary {
                        Text(s).bodyFont(10).lineLimit(1).foregroundStyle(Palette.textMuted)
                    }
                }
                Spacer()
                if isSelected {
                    Text("⏎")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.neonMagenta)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Palette.neonMagenta.opacity(0.10) : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(Palette.neonMagenta)
                        .frame(width: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
