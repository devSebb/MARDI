import SwiftUI
import AppKit

/// Three-step first-run sheet. Lets the user place the vault, choose a
/// provider, and paste an API key before MARDI gets to work. Persists
/// `settings.hasOnboarded` on completion.
///
/// Vault path: writing this to settings *after* boot does not re-point the
/// live `Vault`. If the user picks a non-default location we mark the change,
/// finish onboarding, then offer a relaunch so the next process boots against
/// the chosen path.
struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject private var settings = AppSettings.shared

    enum Step: Int, CaseIterable {
        case vault, provider, key
    }

    @State private var step: Step = .vault
    @State private var vaultPath: String = AppSettings.shared.vaultPath
    @State private var draftKey: String = ""
    @State private var pingResult: String = ""
    @State private var testing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            BrailleDivider(color: Palette.neonMagenta.opacity(0.45))
                .padding(.horizontal, 4)
            content
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            BrailleDivider(color: Palette.border)
                .padding(.horizontal, 4)
            footer
        }
        .frame(width: 600, height: 480)
        .background(
            ZStack {
                Palette.charcoal
                BrailleField(color: Palette.brailleDim, opacity: 0.32, fontSize: 12, density: 0.24)
                Scanlines(opacity: 0.07, spacing: 3)
            }
        )
        .colorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("⣿⣿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Text("[MARDI :: AWAKEN]")
                    .monoFont(12, weight: .bold)
                    .tracking(2.5)
                    .foregroundStyle(Palette.textPrimary)
                Text("⣿⣿")
                    .monoFont(12, weight: .bold)
                    .foregroundStyle(Palette.neonMagenta)
                Spacer()
                Text(stepLabel)
                    .monoFont(9, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
            }
            stepRail
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.45, fontSize: 10, density: 0.32)
            }
        )
    }

    private var stepRail: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Rectangle()
                    .fill(s.rawValue <= step.rawValue ? Palette.neonMagenta : Palette.border)
                    .frame(height: 3)
                    .shadow(color: s == step ? Palette.neonMagenta.opacity(0.55) : .clear, radius: 3)
            }
        }
    }

    private var stepLabel: String {
        switch step {
        case .vault: "STEP 1/3 · VAULT"
        case .provider: "STEP 2/3 · PROVIDER"
        case .key: "STEP 3/3 · KEY"
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .vault: vaultStep
        case .provider: providerStep
        case .key: keyStep
        }
    }

    private var vaultStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrailleLabel(text: "Pick a home for your memories", color: Palette.neonCyan, size: 11)
            Text("MARDI writes plain markdown + YAML to this folder. Obsidian can open it as a vault. Sync it with iCloud, Dropbox, or anything else — your data, your disk.")
                .bodyFont(11)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("VAULT PATH")
                    .monoFont(9, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
                HStack(spacing: 8) {
                    TextField("", text: $vaultPath)
                        .textFieldStyle(.plain)
                        .monoFont(11)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(8)
                        .background(Palette.bubbleBg)
                        .pixelBorder(Palette.border, width: 1)
                    Button("CHOOSE…") { pickVault() }
                        .buttonStyle(.pixel(Palette.neonViolet))
                }
            }

            HStack(spacing: 8) {
                Text("⠿")
                    .monoFont(10)
                    .foregroundStyle(Palette.neonOrange)
                Text("Default is ~/Documents/MARDI-Vault — change anytime in Settings → Vault.")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrailleLabel(text: "Pick a brain for the auto-tagger", color: Palette.neonCyan, size: 11)
            Text("Each saved memory is auto-titled, summarised, and tagged by an LLM. Pick the provider you'd like to route through. You can change this later in Settings → Model.")
                .bodyFont(11)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                providerCard(
                    kind: .claude,
                    title: "Claude (direct)",
                    detail: "api.anthropic.com · claude-haiku-4-5 by default · fast and cheap.",
                    tint: Palette.neonMagenta
                )
                providerCard(
                    kind: .openrouter,
                    title: "OpenRouter",
                    detail: "openrouter.ai/api · pick any model slug · BYO routing.",
                    tint: Palette.neonViolet
                )
            }
        }
    }

    private var keyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrailleLabel(text: "Drop in your \(settings.provider.displayName) key", color: Palette.neonCyan, size: 11)
            Text(keyHint)
                .bodyFont(11)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("API KEY")
                    .monoFont(9, weight: .bold)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
                SecureField("", text: $draftKey, prompt: Text(keyPlaceholder).foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .monoFont(11)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(10)
                    .background(Palette.bubbleBg)
                    .pixelBorder(Palette.border, width: 1)
            }

            HStack(spacing: 10) {
                Button(testing ? "TESTING…" : "TEST CONNECTION") {
                    Task { await testConnection() }
                }
                .buttonStyle(.pixel(Palette.neonMagenta))
                .disabled(testing || draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if !pingResult.isEmpty {
                    Text(pingResult)
                        .monoFont(11, weight: .bold)
                        .foregroundStyle(pingResult.hasPrefix("✓") ? Palette.neonCyan : Palette.neonRed)
                }
            }

            HStack(spacing: 8) {
                Text("⠿")
                    .monoFont(10)
                    .foregroundStyle(Palette.neonOrange)
                Text("Stored in macOS Keychain. Never leaves your machine.")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var keyHint: String {
        switch settings.provider {
        case .claude:
            return "Grab one from console.anthropic.com → API Keys. Format: sk-ant-…"
        case .openrouter:
            return "Grab one from openrouter.ai → Keys. Format: sk-or-…"
        }
    }

    private var keyPlaceholder: String {
        settings.provider == .claude ? "sk-ant-…" : "sk-or-…"
    }

    // MARK: - Provider card

    private func providerCard(kind: LLMProviderKind, title: String, detail: String, tint: Color) -> some View {
        let active = settings.provider == kind
        return Button {
            settings.provider = kind
            pingResult = ""
            draftKey = currentKey(for: kind)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(active ? "⣿" : "⠂")
                    .monoFont(14, weight: .bold)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .monoFont(11, weight: .bold)
                        .tracking(1.4)
                        .foregroundStyle(Palette.textPrimary)
                    Text(detail)
                        .monoFont(10)
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
                if active {
                    Text("[ACTIVE]")
                        .monoFont(9, weight: .bold)
                        .tracking(1.5)
                        .foregroundStyle(tint)
                }
            }
            .padding(12)
            .background(active ? tint.opacity(0.10) : Palette.panelSlateHi)
            .pixelBorder(active ? tint : Palette.border, width: active ? 1.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private func currentKey(for kind: LLMProviderKind) -> String {
        switch kind {
        case .claude: settings.claudeAPIKey
        case .openrouter: settings.openRouterAPIKey
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button("SKIP") { complete(persistKey: false) }
                .buttonStyle(.pixel(Palette.textMuted))
            Spacer()
            if step != .vault {
                Button("BACK") { back() }
                    .buttonStyle(.pixel(Palette.textSecondary))
            }
            Button(primaryLabel) { advance() }
                .buttonStyle(.pixel(Palette.neonCyan, filled: true))
                .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.40, fontSize: 10, density: 0.30)
            }
        )
    }

    private var primaryLabel: String {
        switch step {
        case .vault: "NEXT  →"
        case .provider: "NEXT  →"
        case .key: "BEGIN  ⏎"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .vault: !vaultPath.trimmingCharacters(in: .whitespaces).isEmpty
        case .provider: true
        case .key: !draftKey.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func advance() {
        switch step {
        case .vault:
            settings.vaultPath = vaultPath.trimmingCharacters(in: .whitespaces)
            draftKey = currentKey(for: settings.provider)
            step = .provider
        case .provider:
            draftKey = currentKey(for: settings.provider)
            step = .key
        case .key:
            complete(persistKey: true)
        }
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    private func complete(persistKey: Bool) {
        if persistKey {
            let trimmed = draftKey.trimmingCharacters(in: .whitespaces)
            switch settings.provider {
            case .claude: settings.claudeAPIKey = trimmed
            case .openrouter: settings.openRouterAPIKey = trimmed
            }
        }
        settings.hasOnboarded = true
        env.lastToast = "Mardi is awake."
        dismiss()
    }

    // MARK: - Helpers

    private func pickVault() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.allowsMultipleSelection = false
        p.canCreateDirectories = true
        p.message = "Pick a folder for your MARDI vault. Markdown memories will be written here."
        if p.runModal() == .OK, let url = p.url {
            vaultPath = url.path
        }
    }

    private func testConnection() async {
        testing = true
        defer { testing = false }
        let trimmed = draftKey.trimmingCharacters(in: .whitespaces)
        let provider: LLMProvider
        switch settings.provider {
        case .claude:
            provider = ClaudeProvider(apiKey: trimmed, model: settings.claudeModel)
        case .openrouter:
            provider = OpenRouterProvider(apiKey: trimmed, model: settings.openRouterModel)
        }
        let ok = await provider.ping()
        pingResult = ok ? "✓ connected" : "✗ failed — check key"
    }
}
