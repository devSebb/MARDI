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
                Text("⠿")
                    .monoFont(18, weight: .bold)
                    .foregroundStyle(Palette.pink)
                TextField("", text: $text, prompt: Text("Ask Mardi…").foregroundStyle(Palette.textMuted))
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

            Divider().background(Palette.rule)

            if !results.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, m in
                            Row(memory: m, isSelected: idx == selectedIndex) {
                                selectedIndex = idx
                                submit()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
            } else if !text.isEmpty {
                Text("nothing matching").monoFont(11).foregroundStyle(Palette.textMuted).padding(18)
            } else {
                Text("Type to search — Enter copies to clipboard.")
                    .monoFont(11).foregroundStyle(Palette.textMuted).padding(18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.panelSlate)
                .brailleField(opacity: 0.04)
                .pixelBorder(color: Palette.ruleHi, glow: Palette.pink, cornerRadius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(.clear)
                .scanlines(opacity: 0.03, spacing: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .allowsHitTesting(false)
        )
        .frame(width: 560)
        .colorScheme(.dark)
        .onAppear { focused = true }
        .task(id: text) {
            try? await Task.sleep(nanoseconds: 100_000_000) // small debounce
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
                Text(memory.type.brailleGlyph)
                    .monoFont(15, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(memory.title).monoFont(12, weight: .bold)
                        .foregroundStyle(isSelected ? Palette.pink : Palette.textPrimary)
                        .lineLimit(1)
                    if let s = memory.summary {
                        Text(s).bodyFont(10).lineLimit(1).foregroundStyle(Palette.textMuted)
                    }
                }
                Spacer()
                Text(memory.type.displayName.uppercased()).monoFont(9).foregroundStyle(memory.type.accent.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Palette.pink.opacity(0.12) : Color.clear)
                    .pixelBorder(color: isSelected ? Palette.pink.opacity(0.7) : .clear, cornerRadius: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
