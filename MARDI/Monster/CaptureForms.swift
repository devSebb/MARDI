import SwiftUI

/// Prefill values passed from the view-model into the capture form.
struct CapturePrefill: Equatable {
    var title: String = ""
    var body: String = ""
    var tags: [String] = []
    var sourceURL: String?
    var sourceApp: String?
}

/// Inline capture form shown in the monster. Same shape for all types, with
/// subtle per-type tweaks (lines for body, placeholder, whether to show URL).
struct CaptureFormView: View {
    let type: MemoryType
    let prefill: CapturePrefill
    let onCancel: () -> Void
    let onSubmit: (_ title: String, _ body: String, _ tags: String) -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var tagsRaw: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(type.emoji).monoFont(12)
                Text(type.displayName.uppercased())
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(type.accent)
                Spacer()
                if let url = prefill.sourceURL {
                    Text(url)
                        .monoFont(9)
                        .lineLimit(1)
                        .foregroundStyle(Palette.textMuted)
                }
            }

            TextField("", text: $title, prompt: Text(placeholder(.title)).foregroundStyle(Palette.textMuted))
                .textFieldStyle(.plain)
                .monoFont(12, weight: .medium)
                .foregroundStyle(Palette.textPrimary)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Palette.bubbleBg)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.border, lineWidth: 1))
                )

            TextEditor(text: $bodyText)
                .scrollContentBackground(.hidden)
                .monoFont(11)
                .foregroundStyle(Palette.textPrimary)
                .frame(height: bodyHeight())
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Palette.bubbleBg)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.border, lineWidth: 1))
                )

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                TextField("", text: $tagsRaw, prompt: Text("tags (space or comma separated)").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(10)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Palette.bubbleBg)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.border, lineWidth: 1))
            )

            HStack {
                Button("cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .monoFont(10)
                    .foregroundStyle(Palette.textMuted)

                Spacer()

                Button(action: submit) {
                    HStack(spacing: 4) {
                        Text("save").monoFont(11, weight: .bold)
                        Image(systemName: "return").font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5).fill(Palette.phosphor.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.phosphor, lineWidth: 1))
                    )
                    .foregroundStyle(Palette.phosphor)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .onAppear {
            title = prefill.title
            bodyText = prefill.body
            tagsRaw = prefill.tags.joined(separator: " ")
        }
    }

    private func placeholder(_ kind: Kind) -> String {
        switch (kind, type) {
        case (.title, .url): "title (autofilled)"
        case (.title, _): "title (optional — Mardi will write one)"
        }
    }

    private func bodyHeight() -> CGFloat {
        switch type {
        case .note: 100
        case .reply: 90
        case .signature: 70
        case .url: 40
        default: 70
        }
    }

    private func submit() {
        onSubmit(title, bodyText, tagsRaw)
    }

    private enum Kind { case title }
}
