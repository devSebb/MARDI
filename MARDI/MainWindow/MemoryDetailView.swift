import SwiftUI
import AppKit

struct MemoryDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let memory: Memory
    @State private var copied: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider().background(Palette.border)
                bodyView
                actions
                if !memory.tags.isEmpty {
                    tagChips
                }
                metadata
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Palette.charcoal)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(memory.type.brailleGlyph)
                    .monoFont(14, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                Text(memory.type.displayName.uppercased())
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(memory.type.accent)
                Spacer()
                Text(memory.created, style: .date)
                    .monoFont(10)
                    .foregroundStyle(Palette.textMuted)
            }
            Text(memory.title)
                .monoFont(22, weight: .bold)
                .foregroundStyle(Palette.textPrimary)
            if let s = memory.summary {
                Text(s).bodyFont(13).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var bodyView: some View {
        Text(memory.body)
            .monoFont(12)
            .foregroundStyle(Palette.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.panelSlate)
                    .brailleField(opacity: 0.035)
                    .pixelBorder(color: Palette.ruleHi, cornerRadius: 2)
            )
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: copy) {
                HStack(spacing: 5) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy")
                        .monoFont(11, weight: .bold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.pink.opacity(0.14))
                        .pixelBorder(color: Palette.pink, glow: Palette.pink, cornerRadius: 2)
                )
                .foregroundStyle(Palette.bone)
            }
            .buttonStyle(.plain)

            if let url = memory.sourceURL, URL(string: url) != nil {
                Button {
                    if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open URL").monoFont(11)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Palette.panelSlateHi)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                    )
                    .foregroundStyle(Palette.sky)
                }
                .buttonStyle(.plain)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([env.vault.rootURL.appendingPathComponent(memory.markdownPath)])
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text("Reveal").monoFont(11)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.panelSlateHi)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                )
                .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await env.delete(memory) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                    Text("Delete").monoFont(11)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(Palette.rust.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private var tagChips: some View {
        HStack(spacing: 5) {
            ForEach(memory.tags, id: \.self) { tag in
                Text(tag).monoFont(10)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.panelSlate).overlay(Capsule().stroke(Palette.rule, lineWidth: 0.5)))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("METADATA").monoFont(9, weight: .bold).foregroundStyle(Palette.textMuted)
            if let app = memory.sourceApp {
                metaLine("captured from", app)
            }
            metaLine("id", memory.id)
            metaLine("path", memory.markdownPath)
        }
        .padding(.top, 10)
    }

    private func metaLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key).monoFont(10).foregroundStyle(Palette.textMuted).frame(width: 90, alignment: .trailing)
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
