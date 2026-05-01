import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var settings = AppSettings.shared
    @State private var claudeKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var pingResult: String = ""
    @State private var isTesting: Bool = false
    @State private var openRouterModels: [String] = []
    @State private var loadingModels = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            modelTab
                .tabItem { Label("Model", systemImage: "sparkles") }
            vaultTab
                .tabItem { Label("Vault", systemImage: "externaldrive") }
            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 580, height: 440)
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.30, fontSize: 12, density: 0.22)
            }
        )
        .colorScheme(.dark)
        .onAppear {
            claudeKey = settings.claudeAPIKey
            openRouterKey = settings.openRouterAPIKey
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        tabShell(title: "General", subtitle: "Hot corner, dwell, launch behavior.") {
            VStack(alignment: .leading, spacing: 14) {
                settingRow(label: "HOT CORNER") {
                    Picker("", selection: $settings.hotCorner) {
                        ForEach(HotCornerPosition.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .labelsHidden()
                }
                settingRow(label: "DWELL") {
                    Stepper("\(settings.dwellMs) ms", value: $settings.dwellMs, in: 200...1500, step: 50)
                        .monoFont(11)
                        .foregroundStyle(Palette.textPrimary)
                }
                settingRow(label: "LAUNCH AT LOGIN") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .labelsHidden()
                        .help("Not yet wired — coming soon.")
                }
            }
        }
    }

    private var modelTab: some View {
        tabShell(title: "Model", subtitle: "Provider and API keys for auto-tagging.") {
            VStack(alignment: .leading, spacing: 14) {
                settingRow(label: "PROVIDER") {
                    Picker("", selection: $settings.provider) {
                        ForEach(LLMProviderKind.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                }

                if settings.provider == .claude {
                    settingRow(label: "MODEL") {
                        Picker("", selection: $settings.claudeModel) {
                            Text("claude-haiku-4-5 (fast, cheap)").tag("claude-haiku-4-5")
                            Text("claude-sonnet-4-6").tag("claude-sonnet-4-6")
                            Text("claude-opus-4-7 (best quality)").tag("claude-opus-4-7")
                        }
                        .labelsHidden()
                    }
                    settingRow(label: "API KEY") {
                        VStack(alignment: .leading, spacing: 6) {
                            SecureField("", text: $claudeKey, prompt: Text("sk-ant-…").foregroundStyle(Palette.textMuted))
                                .textFieldStyle(.plain)
                                .monoFont(11)
                                .foregroundStyle(Palette.textPrimary)
                                .padding(8)
                                .background(Palette.bubbleBg)
                                .pixelBorder(Palette.border, width: 1)
                                .onSubmit { settings.claudeAPIKey = claudeKey }
                            Button("SAVE KEY") { settings.claudeAPIKey = claudeKey }
                                .buttonStyle(.pixel(Palette.neonCyan))
                        }
                    }
                } else {
                    settingRow(label: "MODEL") {
                        HStack {
                            TextField("", text: $settings.openRouterModel, prompt: Text("anthropic/claude-haiku-4.5").foregroundStyle(Palette.textMuted))
                                .textFieldStyle(.plain)
                                .monoFont(11)
                                .foregroundStyle(Palette.textPrimary)
                                .padding(8)
                                .background(Palette.bubbleBg)
                                .pixelBorder(Palette.border, width: 1)
                            Button(loadingModels ? "…" : "FETCH") {
                                Task { await fetchOpenRouterModels() }
                            }
                            .buttonStyle(.pixel(Palette.neonViolet))
                            .disabled(settings.openRouterAPIKey.isEmpty || loadingModels)
                        }
                    }
                    if !openRouterModels.isEmpty {
                        settingRow(label: "AVAILABLE") {
                            Picker("", selection: $settings.openRouterModel) {
                                ForEach(openRouterModels, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    settingRow(label: "API KEY") {
                        VStack(alignment: .leading, spacing: 6) {
                            SecureField("", text: $openRouterKey, prompt: Text("sk-or-…").foregroundStyle(Palette.textMuted))
                                .textFieldStyle(.plain)
                                .monoFont(11)
                                .foregroundStyle(Palette.textPrimary)
                                .padding(8)
                                .background(Palette.bubbleBg)
                                .pixelBorder(Palette.border, width: 1)
                                .onSubmit { settings.openRouterAPIKey = openRouterKey }
                            Button("SAVE KEY") { settings.openRouterAPIKey = openRouterKey }
                                .buttonStyle(.pixel(Palette.neonCyan))
                        }
                    }
                }

                BrailleDivider(color: Palette.border)

                HStack(spacing: 10) {
                    Button(isTesting ? "TESTING…" : "TEST CONNECTION") {
                        Task { await test() }
                    }
                    .buttonStyle(.pixel(Palette.neonMagenta))
                    .disabled(isTesting)
                    Text(pingResult)
                        .foregroundStyle(pingResult.hasPrefix("✓") ? Palette.neonCyan : Palette.neonRed)
                        .monoFont(11, weight: .bold)
                }
            }
        }
    }

    private var vaultTab: some View {
        tabShell(title: "Vault", subtitle: "Where memories are written on disk.") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow(label: "PATH") {
                    HStack {
                        TextField("", text: $settings.vaultPath)
                            .textFieldStyle(.plain)
                            .monoFont(10)
                            .foregroundStyle(Palette.textPrimary)
                            .padding(8)
                            .background(Palette.bubbleBg)
                            .pixelBorder(Palette.border, width: 1)
                        Button("CHOOSE…") { chooseVault() }
                            .buttonStyle(.pixel(Palette.neonViolet))
                    }
                }
                if settings.vaultPath != env.vault.rootURL.path {
                    HStack(spacing: 8) {
                        Text("⡏⠯")
                            .monoFont(10, weight: .bold)
                            .foregroundStyle(Palette.neonOrange)
                        Text("Vault path changed — relaunch to apply.")
                            .monoFont(10)
                            .foregroundStyle(Palette.neonOrange)
                        Spacer()
                        Button("RELAUNCH") { relaunchApp() }
                            .buttonStyle(.pixel(Palette.neonOrange, filled: true))
                    }
                    .padding(10)
                    .background(Palette.neonOrange.opacity(0.10))
                    .pixelBorder(Palette.neonOrange.opacity(0.6), width: 1)
                }
                HStack(spacing: 10) {
                    Button("REVEAL IN FINDER") {
                        NSWorkspace.shared.activateFileViewerSelecting([settings.vaultURL])
                    }
                    .buttonStyle(.pixel(Palette.textSecondary))

                    Button("OPEN IN OBSIDIAN") {
                        let name = settings.vaultURL.lastPathComponent
                        if let url = URL(string: "obsidian://open?vault=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.pixel(Palette.neonMagenta))
                }
            }
        }
    }

    private var permissionsTab: some View {
        tabShell(title: "Permissions", subtitle: "MARDI's footprint is deliberately minimal.") {
            VStack(alignment: .leading, spacing: 10) {
                permissionRow(
                    glyph: "⢸",
                    title: "Automation",
                    detail: "Requested per-browser the first time you save a URL.",
                    tint: Palette.neonViolet
                ) {
                    openSettings("com.apple.preference.security?Privacy_Automation")
                }
                permissionRow(
                    glyph: "⡟",
                    title: "Screen Recording",
                    detail: "Only needed when using Select Mode.",
                    tint: Palette.neonMagenta
                ) {
                    openSettings("com.apple.preference.security?Privacy_ScreenCapture")
                }
                permissionRow(
                    glyph: "⠿",
                    title: "Notifications",
                    detail: "For \"Saved ✓\" toasts.",
                    tint: Palette.neonCyan
                ) {
                    openSettings("com.apple.preference.notifications")
                }
                Spacer()
            }
        }
    }

    private var aboutTab: some View {
        tabShell(title: "About", subtitle: "Build info and credits.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("⣿⣿⣿⣿")
                        .monoFont(14, weight: .bold)
                        .foregroundStyle(Palette.neonMagenta)
                    Text("MARDI")
                        .pixelFont(26)
                        .tracking(4)
                        .foregroundStyle(Palette.neonCyan)
                        .shadow(color: Palette.neonCyan.opacity(0.4), radius: 3)
                }
                Text("v0.1.0 · retro-future second brain")
                    .monoFont(10, weight: .bold)
                    .tracking(1.3)
                    .foregroundStyle(Palette.textMuted)
                BrailleDivider(color: Palette.border)
                aboutLine("embedding model", "NLEmbedding.sentenceEmbedding (Apple NaturalLanguage)")
                aboutLine("vector store", "sqlite-vec (SQLiteVec by jkrukowski)")
                aboutLine("vault format", "Obsidian-compatible markdown + YAML frontmatter")
                Spacer()
            }
        }
    }

    // MARK: - Shell helpers

    @ViewBuilder
    private func tabShell<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AgentHeader(title: title, subtitle: subtitle, tint: Palette.neonMagenta)
            content()
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .monoFont(9, weight: .bold)
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
                .frame(width: 110, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }

    private func permissionRow(glyph: String, title: String, detail: String, tint: Color, open: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(glyph)
                .monoFont(14, weight: .bold)
                .foregroundStyle(tint)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .monoFont(11, weight: .bold)
                    .tracking(1.3)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail).monoFont(10).foregroundStyle(Palette.textMuted)
            }
            Spacer()
            Button("OPEN", action: open)
                .buttonStyle(.pixel(tint))
        }
        .padding(10)
        .background(Palette.panelSlateHi)
        .pixelBorder(tint.opacity(0.4), width: 1)
    }

    private func aboutLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key.uppercased())
                .monoFont(9, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Palette.textMuted)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .monoFont(10)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func openSettings(_ urlString: String) {
        if let url = URL(string: "x-apple.systempreferences:\(urlString)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func chooseVault() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.allowsMultipleSelection = false
        p.canCreateDirectories = true
        p.message = "Pick a folder for your MARDI vault. Markdown memories will be written here."
        if p.runModal() == .OK, let url = p.url {
            settings.vaultPath = url.path
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        let provider = settings.buildProvider()
        let ok = await provider.ping()
        pingResult = ok ? "✓ connected" : "✗ failed — check key/model"
    }

    private func fetchOpenRouterModels() async {
        loadingModels = true
        defer { loadingModels = false }
        do {
            openRouterModels = try await OpenRouterProvider.listModels(apiKey: settings.openRouterAPIKey)
        } catch {
            openRouterModels = []
            pingResult = "✗ \(error.localizedDescription)"
        }
    }
}
