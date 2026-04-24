import SwiftUI

struct MardiDashboardView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var workspace: MardiAgentWorkspace

    var body: some View {
        NavigationSplitView {
            List(selection: selectionBinding) {
                Section {
                    Button {
                        workspace.createThread()
                    } label: {
                        HStack(spacing: 7) {
                            Text("⣿")
                                .monoFont(10)
                                .foregroundStyle(Palette.neonMagenta)
                            Text("new conversation")
                                .monoFont(10)
                                .tracking(0.8)
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                            Text("→")
                                .monoFont(10)
                                .foregroundStyle(Palette.neonMagenta.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(Palette.neonMagenta.opacity(0.07))
                        .pixelBorder(Palette.neonMagenta.opacity(0.40), width: 1)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(workspace.threads) { thread in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(thread.title)
                                .monoFont(10)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                            Text(thread.updated, style: .relative)
                                .monoFont(9)
                                .foregroundStyle(Palette.textMuted)
                        }
                        .padding(.vertical, 2)
                        .tag(AgentSidebarItem.thread(thread.id))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("⠿").monoFont(9).foregroundStyle(Palette.neonCyan)
                        Text("conversations")
                            .monoFont(9).tracking(1.5).foregroundStyle(Palette.textMuted)
                    }
                    .padding(.bottom, 4)
                }

                Section {
                    ForEach(workspace.files) { file in
                        HStack(spacing: 8) {
                            Text(glyph(for: file.kind))
                                .monoFont(11)
                                .foregroundStyle(color(for: file.kind))
                                .frame(width: 14)
                            Text(file.title.lowercased())
                                .monoFont(10)
                                .tracking(0.8)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .tag(AgentSidebarItem.file(file.id))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("⠿").monoFont(9).foregroundStyle(Palette.neonMagenta)
                        Text("agent files")
                            .monoFont(9).tracking(1.5).foregroundStyle(Palette.textMuted)
                    }
                    .padding(.bottom, 4)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 240)
            .background(
                ZStack {
                    Palette.panelSlate
                    BrailleField(color: Palette.brailleDim, opacity: 0.50, fontSize: 11, density: 0.35)
                }
            )
        } detail: {
            detailView
        }
        .background(Palette.charcoal)
        .task {
            if workspace.selectedItem == nil {
                await workspace.load()
            }
        }
    }

    private var detailView: some View {
        Group {
            switch workspace.selectedItem {
            case .thread(let id):
                MardiChatView(workspace: workspace, threadID: id)
            case .file(let id):
                MardiSpecEditorView(workspace: workspace, fileID: id)
            case .none:
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.25, fontSize: 13, density: 0.18)
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            MardiFishBrailleView(mood: .idle, size: 240)
            SpeechBubbleView(text: "Still here.")
            VStack(spacing: 8) {
                BrailleLabel(text: "mardi · standby", color: Palette.neonMagenta, size: 11)
                Text("Select a conversation or start a new one.")
                    .monoFont(10)
                    .tracking(0.5)
                    .foregroundStyle(Palette.textSecondary)
                Text("The dashboard is where you talk to Mardi and shape its identity.")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var selectionBinding: Binding<AgentSidebarItem?> {
        Binding(
            get: { workspace.selectedItem },
            set: { workspace.selectedItem = $0 }
        )
    }

    private func glyph(for kind: AgentSpecFile.Kind) -> String {
        switch kind {
        case .identity: "⣿"
        case .style: "⠿"
        case .rules: "⡶"
        case .task: "⢰"
        }
    }

    private func color(for kind: AgentSpecFile.Kind) -> Color {
        switch kind {
        case .identity: Palette.neonViolet
        case .style: Palette.neonCyan
        case .rules: Palette.neonOrange
        case .task: Palette.neonMagenta
        }
    }
}

private struct MardiChatView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var workspace: MardiAgentWorkspace
    let threadID: String

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            BrailleDivider(color: Palette.neonMagenta.opacity(0.4))
                .padding(.horizontal, 4)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = workspace.lastError, !error.isEmpty {
                            HStack(spacing: 6) {
                                Text("⡏⠯")
                                    .monoFont(10, weight: .bold)
                                    .foregroundStyle(Palette.neonRed)
                                Text(error)
                                    .monoFont(10)
                                    .foregroundStyle(Palette.neonRed)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                        }
                        ForEach(thread?.messages ?? []) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: thread?.messages.count ?? 0) { _, _ in
                    if let last = thread?.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            BrailleDivider(color: Palette.border)
                .padding(.horizontal, 4)
            composer
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("⣿⣿")
                        .monoFont(11)
                        .foregroundStyle(Palette.neonMagenta)
                    Text((thread?.title ?? "conversation").lowercased())
                        .monoFont(12)
                        .tracking(1.2)
                        .foregroundStyle(Palette.textPrimary)
                }
                Text(env.settings.hasAPIKey ? "grounded in your vault · \(env.settings.buildProvider().displayName.lowercased())." : "set an API key in settings to enable mardi chat.")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            if workspace.sending {
                HStack(spacing: 6) {
                    Text("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
                        .monoFont(10)
                        .foregroundStyle(Palette.neonMagenta)
                    Text("thinking…")
                        .monoFont(9)
                        .tracking(1.2)
                        .foregroundStyle(Palette.neonMagenta)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.40, fontSize: 10, density: 0.28)
            }
        )
    }

    private var composer: some View {
        VStack(spacing: 10) {
            TextEditor(text: $draft)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, maxHeight: 160)
                .monoFont(12)
                .foregroundStyle(Palette.textPrimary)
                .padding(10)
                .background(Palette.bubbleBg)
                .pixelBorder(Palette.border, width: 1.5)

            HStack {
                Text("⠂ recall · organize · write from saved memories")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Button(action: send) {
                    HStack(spacing: 5) {
                        Text("⢰⢸")
                            .monoFont(10, weight: .bold)
                        Text("SEND")
                            .monoFont(11, weight: .bold)
                            .tracking(1.5)
                        Text("⏎")
                            .monoFont(10)
                            .opacity(0.7)
                    }
                }
                .buttonStyle(.pixel(Palette.neonCyan, filled: true))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || workspace.sending || !env.settings.hasAPIKey)
            }
        }
        .padding(20)
        .background(Palette.charcoal)
    }

    private var thread: AgentThread? {
        workspace.thread(for: threadID)
    }

    private func send() {
        let message = draft
        draft = ""
        Task { await workspace.send(message: message, threadID: threadID) }
    }
}

private struct MessageBubble: View {
    let message: AgentMessage

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.role == "assistant" {
                    HStack(spacing: 5) {
                        Text("⣿⣿")
                            .monoFont(10)
                            .foregroundStyle(Palette.neonMagenta)
                        Text("mardi")
                            .monoFont(10)
                            .tracking(1.5)
                            .foregroundStyle(Palette.neonMagenta)
                    }
                } else {
                    Spacer()
                    HStack(spacing: 5) {
                        Text("you")
                            .monoFont(10)
                            .tracking(1.5)
                            .foregroundStyle(Palette.textSecondary)
                        Text("⢸")
                            .monoFont(10)
                            .foregroundStyle(Palette.textMuted)
                    }
                }
            }

            Text(message.content)
                .monoFont(12)
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                .padding(14)
                .background(message.role == "user" ? Palette.neonViolet.opacity(0.10) : Palette.panelSlate)
                .pixelBorder(message.role == "user" ? Palette.neonViolet.opacity(0.55) : Palette.border, width: 1.5)

            if !message.references.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    BrailleLabel(text: "References", color: Palette.neonOrange.opacity(0.75), size: 9)
                    ForEach(message.references) { ref in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("[\(ref.type.uppercased())]")
                                    .monoFont(8, weight: .bold)
                                    .tracking(1.2)
                                    .foregroundStyle(Palette.neonOrange)
                                Text(ref.title)
                                    .monoFont(10, weight: .medium)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                            }
                            if let summary = ref.summary {
                                Text(summary)
                                    .monoFont(9)
                                    .foregroundStyle(Palette.textMuted)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Palette.panelSlateHi)
                        .pixelBorder(Palette.border, width: 1)
                    }
                }
            }
        }
    }
}

private struct MardiSpecEditorView: View {
    @ObservedObject var workspace: MardiAgentWorkspace
    let fileID: String

    @State private var draft = ""
    @State private var didLoad = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("⠿⠿")
                            .monoFont(11)
                            .foregroundStyle(Palette.neonMagenta)
                        Text((file?.title ?? "agent file").lowercased())
                            .monoFont(12)
                            .tracking(1.2)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Text(file?.relativePath ?? "")
                        .monoFont(9)
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
                Button(action: save) {
                    HStack(spacing: 5) {
                        Text("⢰")
                            .monoFont(10, weight: .bold)
                        Text("SAVE")
                            .monoFont(11, weight: .bold)
                            .tracking(1.5)
                    }
                }
                .buttonStyle(.pixel(Palette.neonCyan, filled: true))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Palette.panelSlate
                    BrailleField(color: Palette.brailleDim, opacity: 0.45, fontSize: 10, density: 0.3)
                }
            )

            BrailleDivider(color: Palette.neonMagenta.opacity(0.4))
                .padding(.horizontal, 4)

            TextEditor(text: $draft)
                .scrollContentBackground(.hidden)
                .monoFont(12)
                .foregroundStyle(Palette.textPrimary)
                .padding(20)
                .background(Palette.charcoal)
        }
        .onAppear {
            if let file {
                draft = file.content
                didLoad = true
            }
        }
        .onChange(of: fileID) { _, _ in
            if let file {
                draft = file.content
            }
        }
    }

    private var file: AgentSpecFile? {
        workspace.files.first(where: { $0.id == fileID })
    }

    private func save() {
        workspace.save(fileID: fileID, content: draft)
    }
}
