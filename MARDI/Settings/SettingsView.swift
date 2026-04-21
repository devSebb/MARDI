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
        .frame(width: 560, height: 420)
        .onAppear {
            claudeKey = settings.claudeAPIKey
            openRouterKey = settings.openRouterAPIKey
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Picker("Hot corner", selection: $settings.hotCorner) {
                ForEach(HotCornerPosition.allCases, id: \.self) { c in
                    Text(c.displayName).tag(c)
                }
            }
            Stepper("Dwell: \(settings.dwellMs) ms", value: $settings.dwellMs, in: 200...1500, step: 50)
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .help("Not yet wired — coming soon.")
        }
        .padding()
    }

    private var modelTab: some View {
        Form {
            Picker("Provider", selection: $settings.provider) {
                ForEach(LLMProviderKind.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }

            if settings.provider == .claude {
                Picker("Model", selection: $settings.claudeModel) {
                    Text("claude-haiku-4-5 (fast, cheap)").tag("claude-haiku-4-5")
                    Text("claude-sonnet-4-6").tag("claude-sonnet-4-6")
                    Text("claude-opus-4-7 (best quality)").tag("claude-opus-4-7")
                }
                SecureField("Anthropic API key", text: $claudeKey)
                    .onSubmit { settings.claudeAPIKey = claudeKey }
                Button("Save key") { settings.claudeAPIKey = claudeKey }
            } else {
                HStack {
                    TextField("Model slug (e.g. anthropic/claude-haiku-4.5)", text: $settings.openRouterModel)
                    Button(loadingModels ? "…" : "Fetch list") {
                        Task { await fetchOpenRouterModels() }
                    }.disabled(settings.openRouterAPIKey.isEmpty || loadingModels)
                }
                if !openRouterModels.isEmpty {
                    Picker("Available models", selection: $settings.openRouterModel) {
                        ForEach(openRouterModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                }
                SecureField("OpenRouter API key", text: $openRouterKey)
                    .onSubmit { settings.openRouterAPIKey = openRouterKey }
                Button("Save key") { settings.openRouterAPIKey = openRouterKey }
            }

            Divider()

            HStack {
                Button(isTesting ? "Testing…" : "Test connection") {
                    Task { await test() }
                }.disabled(isTesting)
                Text(pingResult)
                    .foregroundStyle(pingResult.hasPrefix("✓") ? Palette.phosphor : Palette.rust)
                    .monoFont(11)
            }
        }
        .padding()
    }

    private var vaultTab: some View {
        Form {
            HStack {
                TextField("Vault path", text: $settings.vaultPath)
                    .disabled(true)
                Button("Choose…") { chooseVault() }
            }
            HStack {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([settings.vaultURL])
                }
                Button("Open in Obsidian") {
                    let name = settings.vaultURL.lastPathComponent
                    if let url = URL(string: "obsidian://open?vault=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding()
    }

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MARDI keeps its permission footprint minimal:")
                .monoFont(11)
                .foregroundStyle(Palette.textSecondary)

            permissionRow(
                title: "Automation",
                detail: "Requested per-browser the first time you save a URL."
            ) {
                openSettings("com.apple.preference.security?Privacy_Automation")
            }
            permissionRow(
                title: "Screen Recording",
                detail: "Only needed when using Select Mode."
            ) {
                openSettings("com.apple.preference.security?Privacy_ScreenCapture")
            }
            permissionRow(
                title: "Notifications",
                detail: "For “Saved ✓” toasts."
            ) {
                openSettings("com.apple.preference.notifications")
            }
            Spacer()
        }
        .padding()
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MARDI").monoFont(24, weight: .bold).foregroundStyle(Palette.phosphor)
            Text("v0.1.0 · retro-future second brain").monoFont(11).foregroundStyle(Palette.textMuted)
            Divider().padding(.vertical, 6)
            Text("Embedding model: NLEmbedding.sentenceEmbedding (Apple NaturalLanguage)")
                .monoFont(10).foregroundStyle(Palette.textSecondary)
            Text("Vector store: sqlite-vec (SQLiteVec by jkrukowski)")
                .monoFont(10).foregroundStyle(Palette.textSecondary)
            Text("Vault format: Obsidian-compatible markdown + YAML frontmatter")
                .monoFont(10).foregroundStyle(Palette.textSecondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private func permissionRow(title: String, detail: String, open: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).monoFont(12, weight: .bold).foregroundStyle(Palette.textPrimary)
                Text(detail).monoFont(10).foregroundStyle(Palette.textMuted)
            }
            Spacer()
            Button("Open System Settings", action: open)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Palette.panelSlateHi))
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
        if p.runModal() == .OK, let url = p.url {
            settings.vaultPath = url.path
        }
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
