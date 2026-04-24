import SwiftUI
import AppKit

struct MemoryDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let memory: Memory
    @State private var copied: Bool = false
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if memory.type == .url, memory.thumbnailPath != nil {
                    URLPreviewHero(memory: memory)
                }
                header
                BrailleDivider(color: Palette.border)
                bodyView
                actions
                if !memory.tags.isEmpty {
                    tagChips
                }
                BrailleDivider(color: Palette.border.opacity(0.6))
                metadata
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.28, fontSize: 13, density: 0.2)
            }
        )
        .sheet(isPresented: $editing) {
            EditMemorySheet(memory: memory)
                .environmentObject(env)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(memory.type.glyph)
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                Text("[\(memory.type.shortCode)]")
                    .monoFont(10, weight: .bold)
                    .tracking(2)
                    .foregroundStyle(memory.type.accent)
                Text("⠂⠂⠂")
                    .monoFont(10)
                    .foregroundStyle(Palette.border)
                Text(memory.type.displayName.uppercased())
                    .monoFont(10, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(memory.type.accent.opacity(0.85))
                Spacer()
                Text(memory.created, style: .date)
                    .monoFont(10)
                    .foregroundStyle(Palette.textMuted)
            }
            Text(memory.title)
                .monoFont(22, weight: .bold)
                .foregroundStyle(Palette.textPrimary)
                .shadow(color: memory.type.accent.opacity(0.25), radius: 3)
            if let s = memory.summary {
                Text(s).bodyFont(13).foregroundStyle(Palette.textSecondary)
            }
            if let folder = memory.folder {
                HStack(spacing: 5) {
                    Text("⡶").monoFont(10, weight: .bold).foregroundStyle(Palette.neonOrange)
                    Text(folder.uppercased())
                        .monoFont(9, weight: .bold)
                        .tracking(1.2)
                        .foregroundStyle(Palette.neonOrange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.neonOrange.opacity(0.12))
                .pixelBorder(Palette.neonOrange.opacity(0.6), width: 1)
            }
        }
    }

    private var bodyView: some View {
        Text(memory.body)
            .monoFont(12)
            .foregroundStyle(Palette.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.bubbleBg)
            .overlay(Scanlines(opacity: 0.08, spacing: 3).allowsHitTesting(false))
            .pixelBorder(Palette.border, width: 1.5)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: copy) {
                HStack(spacing: 5) {
                    Text(copied ? "⠿" : "⢰⢸")
                        .monoFont(10, weight: .bold)
                    Text(copied ? "COPIED" : "COPY")
                        .monoFont(11, weight: .bold)
                        .tracking(1.5)
                }
            }
            .buttonStyle(.pixel(Palette.neonCyan, filled: true))

            Button {
                editing = true
            } label: {
                HStack(spacing: 5) {
                    Text("⠶")
                        .monoFont(10, weight: .bold)
                    Text("EDIT")
                        .monoFont(11, weight: .bold)
                        .tracking(1.5)
                }
            }
            .buttonStyle(.pixel(Palette.textSecondary))

            if let url = memory.sourceURL, URL(string: url) != nil {
                Button {
                    if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                } label: {
                    HStack(spacing: 5) {
                        Text("⡀⢀")
                            .monoFont(10, weight: .bold)
                        Text("OPEN URL")
                            .monoFont(11, weight: .bold)
                            .tracking(1.5)
                    }
                }
                .buttonStyle(.pixel(Palette.neonViolet))
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([env.vault.rootURL.appendingPathComponent(memory.markdownPath)])
            } label: {
                HStack(spacing: 5) {
                    Text("⡷")
                        .monoFont(10, weight: .bold)
                    Text("REVEAL")
                        .monoFont(11, weight: .bold)
                        .tracking(1.5)
                }
            }
            .buttonStyle(.pixel(Palette.textSecondary))

            Spacer()

            Button {
                Task { await env.delete(memory) }
            } label: {
                HStack(spacing: 5) {
                    Text("⡏⠯")
                        .monoFont(10, weight: .bold)
                    Text("DELETE")
                        .monoFont(11, weight: .bold)
                        .tracking(1.5)
                }
            }
            .buttonStyle(.pixel(Palette.neonRed))
        }
    }

    private var tagChips: some View {
        HStack(spacing: 6) {
            Text("⠿")
                .monoFont(10, weight: .bold)
                .foregroundStyle(Palette.neonMagenta)
            ForEach(memory.tags, id: \.self) { tag in
                Text("#\(tag)")
                    .monoFont(10, weight: .medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.panelSlate)
                    .pixelBorder(Palette.border, width: 1)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 5) {
            BrailleLabel(text: "Metadata", color: Palette.neonMagenta.opacity(0.7), size: 9)
            if let app = memory.sourceApp {
                metaLine("captured from", app)
            }
            if let folder = memory.folder {
                metaLine("folder", folder)
            }
            metaLine("id", memory.id)
            metaLine("path", memory.markdownPath)
        }
        .padding(.top, 8)
    }

    private func metaLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key.uppercased())
                .monoFont(9, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Palette.textMuted)
                .frame(width: 110, alignment: .trailing)
            Text(value).monoFont(10).foregroundStyle(Palette.textSecondary).textSelection(.enabled)
        }
    }

    private func copy() {
        ClipboardReader.copy(memory.body)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { copied = false }
        }
    }
}

private struct URLPreviewHero: View {
    @EnvironmentObject var env: AppEnvironment
    let memory: Memory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumbnail = memory.thumbnailPath {
                    VaultThumbnailView(relativePath: thumbnail)
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Palette.neonViolet.opacity(0.35), Palette.panelSlateHi],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("⢸")
                        .monoFont(10, weight: .bold)
                        .foregroundStyle(Palette.neonViolet)
                    Text((hostname(from: memory) ?? "saved link").uppercased())
                        .monoFont(9, weight: .bold)
                        .tracking(1.8)
                        .foregroundStyle(Palette.neonViolet)
                }
                Text(memory.title)
                    .monoFont(17, weight: .bold)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .shadow(color: Palette.neonViolet.opacity(0.35), radius: 3)
            }
            .padding(16)
        }
        .background(Palette.panelSlate)
        .pixelBorder(Palette.neonViolet.opacity(0.55), width: 1.5)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let url = resolvedURL else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private func hostname(from memory: Memory) -> String? {
        guard let raw = memory.sourceURL ?? URL(string: memory.body)?.absoluteString,
              let host = URL(string: raw)?.host else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var resolvedURL: URL? {
        if let raw = memory.sourceURL, let url = URL(string: raw) {
            return url
        }
        return URL(string: memory.body)
    }
}

private struct EditMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var env: AppEnvironment

    let memory: Memory

    @State private var title: String
    @State private var bodyText: String
    @State private var tags: String
    @State private var folder: String
    @State private var saving = false

    init(memory: Memory) {
        self.memory = memory
        _title = State(initialValue: memory.title)
        _bodyText = State(initialValue: memory.body)
        _tags = State(initialValue: memory.tags.joined(separator: " "))
        _folder = State(initialValue: memory.folder ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("⣿⣿")
                    .monoFont(11, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Text("[EDIT MEMORY]")
                    .monoFont(11, weight: .bold)
                    .tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(memory.type.displayName.uppercased())
                    .monoFont(9, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(memory.type.accent)
            }

            BrailleDivider(color: Palette.border)

            pixelField("TITLE") {
                TextField("", text: $title)
                    .textFieldStyle(.plain)
                    .monoFont(12)
                    .foregroundStyle(Palette.textPrimary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("BODY")
                    .monoFont(9, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
                TextEditor(text: $bodyText)
                    .scrollContentBackground(.hidden)
                    .monoFont(12)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Palette.bubbleBg)
                    .pixelBorder(Palette.border, width: 1)
            }

            HStack(spacing: 10) {
                pixelField("TAGS") {
                    TextField("", text: $tags)
                        .textFieldStyle(.plain)
                        .monoFont(11)
                        .foregroundStyle(Palette.textPrimary)
                }
                pixelField("FOLDER") {
                    TextField("", text: $folder)
                        .textFieldStyle(.plain)
                        .monoFont(11)
                        .foregroundStyle(Palette.textPrimary)
                }
            }

            HStack {
                Spacer()
                Button("CANCEL") { dismiss() }
                    .buttonStyle(.pixel(Palette.textMuted))
                Button(action: save) {
                    HStack(spacing: 5) {
                        Text("⠿").monoFont(10, weight: .bold)
                        Text(saving ? "SAVING…" : "SAVE")
                            .monoFont(11, weight: .bold)
                            .tracking(1.5)
                    }
                }
                .buttonStyle(.pixel(Palette.neonCyan, filled: true))
                .disabled(saving)
            }
        }
        .padding(24)
        .frame(width: 580)
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.35, fontSize: 12, density: 0.3)
            }
        )
        .colorScheme(.dark)
    }

    @ViewBuilder
    private func pixelField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .monoFont(9, weight: .bold)
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Palette.bubbleBg)
                .pixelBorder(Palette.border, width: 1)
        }
    }

    private func save() {
        saving = true
        var updated = memory
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = tags
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        updated.folder = folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folder.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.type == .url && updated.sourceURL == nil {
            updated.sourceURL = updated.body
        }
        if updated.type == .url && updated.sourceURL != memory.sourceURL {
            updated.thumbnailPath = nil
        }

        Task { @MainActor in
            _ = await env.update(updated)
            saving = false
            dismiss()
        }
    }
}

struct VaultThumbnailView: View {
    @EnvironmentObject var env: AppEnvironment
    let relativePath: String

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: env.vault.rootURL.appendingPathComponent(relativePath)) {
                Image(nsImage: image)
                    .resizable()
            } else {
                Rectangle().fill(Palette.panelSlateHi)
            }
        }
    }
}
