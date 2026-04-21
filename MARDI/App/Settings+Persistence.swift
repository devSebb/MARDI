import Foundation
import KeychainAccess

/// User-configurable settings persisted to UserDefaults (and Keychain for
/// secrets). Everything non-sensitive is plain UD so Obsidian-style power
/// users can poke at it.
enum LLMProviderKind: String, Codable, CaseIterable, Sendable {
    case claude
    case openrouter

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .openrouter: "OpenRouter"
        }
    }
}

enum HotCornerPosition: String, Codable, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    var displayName: String {
        switch self {
        case .topLeft: "Top-left"
        case .topRight: "Top-right"
        case .bottomLeft: "Bottom-left"
        case .bottomRight: "Bottom-right"
        }
    }
}

final class AppSettings: ObservableObject, @unchecked Sendable {
    static let shared = AppSettings()

    private let ud: UserDefaults
    private let keychain = Keychain(service: "com.mardi.app")

    @Published var provider: LLMProviderKind {
        didSet { ud.set(provider.rawValue, forKey: Keys.provider) }
    }

    @Published var claudeModel: String {
        didSet { ud.set(claudeModel, forKey: Keys.claudeModel) }
    }

    @Published var openRouterModel: String {
        didSet { ud.set(openRouterModel, forKey: Keys.openRouterModel) }
    }

    @Published var vaultPath: String {
        didSet { ud.set(vaultPath, forKey: Keys.vaultPath) }
    }

    @Published var hotCorner: HotCornerPosition {
        didSet { ud.set(hotCorner.rawValue, forKey: Keys.hotCorner) }
    }

    @Published var dwellMs: Int {
        didSet { ud.set(dwellMs, forKey: Keys.dwellMs) }
    }

    @Published var launchAtLogin: Bool {
        didSet { ud.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private init() {
        self.ud = .standard
        self.provider = LLMProviderKind(rawValue: ud.string(forKey: Keys.provider) ?? "") ?? .claude
        self.claudeModel = ud.string(forKey: Keys.claudeModel) ?? "claude-haiku-4-5"
        self.openRouterModel = ud.string(forKey: Keys.openRouterModel) ?? "anthropic/claude-haiku-4.5"
        self.vaultPath = ud.string(forKey: Keys.vaultPath) ?? Vault.defaultPath.path
        self.hotCorner = HotCornerPosition(rawValue: ud.string(forKey: Keys.hotCorner) ?? "") ?? .topRight
        self.dwellMs = (ud.object(forKey: Keys.dwellMs) as? Int) ?? 400
        self.launchAtLogin = ud.bool(forKey: Keys.launchAtLogin)
    }

    // MARK: - Keys in Keychain

    var claudeAPIKey: String {
        get { (try? keychain.get("claude_api_key")) ?? "" }
        set { try? keychain.set(newValue, key: "claude_api_key") }
    }

    var openRouterAPIKey: String {
        get { (try? keychain.get("openrouter_api_key")) ?? "" }
        set { try? keychain.set(newValue, key: "openrouter_api_key") }
    }

    var activeAPIKey: String {
        switch provider {
        case .claude: return claudeAPIKey
        case .openrouter: return openRouterAPIKey
        }
    }

    var hasAPIKey: Bool { !activeAPIKey.isEmpty }

    func buildProvider() -> LLMProvider {
        switch provider {
        case .claude:
            return ClaudeProvider(apiKey: claudeAPIKey, model: claudeModel)
        case .openrouter:
            return OpenRouterProvider(apiKey: openRouterAPIKey, model: openRouterModel)
        }
    }

    var vaultURL: URL {
        URL(fileURLWithPath: vaultPath)
    }

    private enum Keys {
        static let provider = "mardi.provider"
        static let claudeModel = "mardi.claude.model"
        static let openRouterModel = "mardi.openrouter.model"
        static let vaultPath = "mardi.vault.path"
        static let hotCorner = "mardi.hotCorner"
        static let dwellMs = "mardi.dwellMs"
        static let launchAtLogin = "mardi.launchAtLogin"
    }
}
