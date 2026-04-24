import SwiftUI

/// Prefill values passed from the view-model into the capture form.
struct CapturePrefill: Equatable {
    var title: String = ""
    var body: String = ""
    var tags: [String] = []
    var folder: String = ""
    var sourceURL: String?
    var sourceApp: String?
}

/// Inline capture form shown in the monster. Same shape for all types, with
/// subtle per-type tweaks (lines for body, placeholder, whether to show URL).
struct CaptureFormView: View {
    @EnvironmentObject var env: AppEnvironment
    let type: MemoryType
    let prefill: CapturePrefill
    let onCancel: () -> Void
    let onSubmit: (_ title: String, _ body: String, _ tags: String, _ folder: String) -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var tagsRaw: String = ""
    @State private var folder: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Text("⟵")
                            .monoFont(10, weight: .bold)
                        Text("BACK")
                            .monoFont(9, weight: .bold)
                            .tracking(1.2)
                    }
                    .foregroundStyle(Palette.textMuted)
                }
                .buttonStyle(.plain)

                Text(type.glyph)
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(type.accent)
                Text("[\(type.shortCode)]")
                    .monoFont(10, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(type.accent)
                Text(type.displayName.uppercased())
                    .monoFont(9, weight: .bold)
                    .tracking(1.2)
                    .foregroundStyle(type.accent.opacity(0.75))
                Spacer()
                if let url = prefill.sourceURL {
                    Text(url)
                        .monoFont(9)
                        .lineLimit(1)
                        .foregroundStyle(Palette.textMuted)
                }
            }

            pixelField {
                TextField("", text: $title, prompt: Text(placeholder(.title)).foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(12, weight: .medium)
                    .foregroundStyle(Palette.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if allowsExpansion {
                    HStack {
                        Text(isExpanded ? "⠿ EXPANDED EDITOR" : "⠂ COMPACT EDITOR")
                            .monoFont(8, weight: .bold)
                            .tracking(1.2)
                            .foregroundStyle(Palette.textMuted)
                        Spacer()
                        Button(action: { isExpanded.toggle() }) {
                            HStack(spacing: 3) {
                                Text(isExpanded ? "⠶" : "⣿")
                                    .monoFont(9, weight: .bold)
                                Text(isExpanded ? "COLLAPSE" : "EXPAND")
                                    .monoFont(8, weight: .bold)
                                    .tracking(1.2)
                            }
                            .foregroundStyle(Palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextEditor(text: $bodyText)
                    .scrollContentBackground(.hidden)
                    .monoFont(11)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(height: bodyHeight())
                    .padding(6)
                    .background(Palette.bubbleBg)
                    .pixelBorder(Palette.border, width: 1)
            }

            HStack(spacing: 6) {
                Text("⠿")
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(Palette.textMuted)
                TextField("", text: $tagsRaw, prompt: Text("tags (space or comma separated)").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(10)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Palette.bubbleBg)
            .pixelBorder(Palette.border, width: 1)

            HStack(spacing: 6) {
                Text("⡶")
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(Palette.textMuted)
                TextField("", text: $folder, prompt: Text(folderPlaceholder).foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(10)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Palette.bubbleBg)
            .pixelBorder(Palette.border, width: 1)

            if !folderSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(folderSuggestions, id: \.self) { suggestion in
                            Button(action: { folder = suggestion }) {
                                Text(suggestion.uppercased())
                                    .monoFont(8, weight: .bold)
                                    .tracking(1.1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(folder == suggestion ? Palette.neonViolet.opacity(0.16) : Palette.panelSlateHi)
                                    .pixelBorder(folder == suggestion ? Palette.neonViolet : Palette.border, width: 1)
                                    .foregroundStyle(folder == suggestion ? Palette.neonViolet : Palette.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 3) {
                        Text("⟵")
                            .monoFont(9, weight: .bold)
                        Text("BACK")
                            .monoFont(9, weight: .bold)
                            .tracking(1.3)
                    }
                }
                .buttonStyle(.pixel(Palette.textMuted))

                Spacer()

                Button(action: submit) {
                    HStack(spacing: 5) {
                        Text("⠿").monoFont(10, weight: .bold)
                        Text("SAVE")
                            .monoFont(11, weight: .bold)
                            .tracking(1.5)
                        Text("⏎")
                            .monoFont(9)
                            .opacity(0.7)
                    }
                }
                .buttonStyle(.pixel(Palette.neonCyan, filled: true))
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .onAppear {
            title = prefill.title
            bodyText = prefill.body
            tagsRaw = prefill.tags.joined(separator: " ")
            folder = prefill.folder
        }
    }

    @ViewBuilder
    private func pixelField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Palette.bubbleBg)
            .pixelBorder(Palette.border, width: 1)
    }

    private func placeholder(_ kind: Kind) -> String {
        switch (kind, type) {
        case (.title, .url): "title (autofilled)"
        case (.title, _): "title (optional — mardi will write one)"
        }
    }

    private func bodyHeight() -> CGFloat {
        switch type {
        case .note:
            return 100
        case .reply, .signature:
            let compactMin: CGFloat = type == .reply ? 96 : 82
            let expandedMin: CGFloat = type == .reply ? 156 : 132
            let minimum = isExpanded ? expandedMin : compactMin
            let maximum = isExpanded ? 220.0 : 140.0
            return min(max(estimatedBodyHeight(), minimum), maximum)
        case .url:
            return 40
        default:
            return 70
        }
    }

    private var allowsExpansion: Bool {
        type == .reply || type == .signature
    }

    private func estimatedBodyHeight() -> CGFloat {
        let widthEstimate = max(bodyText.count, 1)
        let wrappedLineCount = max(
            bodyText.split(separator: "\n", omittingEmptySubsequences: false)
                .map { max(1, Int(ceil(Double(max($0.count, 1)) / 38.0))) }
                .reduce(0, +),
            widthEstimate > 0 ? 1 : 0
        )
        return CGFloat(wrappedLineCount) * 18.0 + 20.0
    }

    private func submit() {
        onSubmit(title, bodyText, tagsRaw, folder)
    }

    private var folderPlaceholder: String {
        type == .url ? "folder (optional, useful for link collections)" : "folder (optional)"
    }

    private var folderSuggestions: [String] {
        env.countsByFolder
            .sorted {
                if $0.value == $1.value { return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                return $0.value > $1.value
            }
            .map(\.key)
            .prefix(6)
            .map { $0 }
    }

    private enum Kind { case title }
}
