import Foundation
import AppKit
import Combine

/// Observes the frontmost app's bundle identifier and classifies it so the
/// monster + main window can tailor their defaults (Mail → signatures first,
/// Terminal → SSH first, etc.). Requires no permissions.
@MainActor
final class ActiveAppWatcher: ObservableObject {
    @Published private(set) var frontmostBundleID: String?
    @Published private(set) var context: AppContext = .other

    enum AppContext: Equatable {
        case mail
        case terminal
        case ai
        case browser(BrowserKind)
        case other

        var searchFilter: [MemoryType] {
            switch self {
            case .mail: return [.signature, .reply]
            case .terminal: return [.ssh, .snippet]
            case .ai: return [.prompt, .snippet]
            case .browser: return [.url, .select]
            case .other: return MemoryType.allCases
            }
        }

        var primaryCaptureTypes: [MemoryType] {
            switch self {
            case .mail: return [.signature, .reply, .note]
            case .terminal: return [.ssh, .snippet]
            case .ai: return [.prompt, .snippet]
            case .browser: return [.url, .select]
            case .other: return [.note, .snippet, .url]
            }
        }

        var label: String {
            switch self {
            case .mail: "Mail"
            case .terminal: "Terminal"
            case .ai: "AI tool"
            case .browser(let k): k.displayName
            case .other: "App"
            }
        }
    }

    enum BrowserKind: Equatable {
        case safari, chrome, arc, brave, edge, firefox
        var displayName: String {
            switch self {
            case .safari: "Safari"
            case .chrome: "Chrome"
            case .arc: "Arc"
            case .brave: "Brave"
            case .edge: "Edge"
            case .firefox: "Firefox"
            }
        }
        var bundleID: String {
            switch self {
            case .safari: "com.apple.Safari"
            case .chrome: "com.google.Chrome"
            case .arc: "company.thebrowser.Browser"
            case .brave: "com.brave.Browser"
            case .edge: "com.microsoft.edgemac"
            case .firefox: "org.mozilla.firefox"
            }
        }
    }

    init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        refresh()
    }

    private func refresh() {
        let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        self.frontmostBundleID = bid
        self.context = Self.classify(bid)
    }

    nonisolated static func classify(_ bundleID: String?) -> AppContext {
        guard let b = bundleID?.lowercased() else { return .other }
        let mail = ["com.apple.mail", "com.readdle.smartemail-mac", "com.microsoft.outlook", "com.airmailapp.airmail2"]
        let terminal = ["com.apple.terminal", "com.googlecode.iterm2", "dev.warp.warp-stable", "com.github.wez.wezterm", "net.kovidgoyal.kitty"]
        let ai = ["com.anthropic.claudefordesktop", "com.openai.chat", "com.todesktop.230313mzl4w4u92", "com.microsoft.vscode", "com.cursor.cursor"]
        if mail.contains(b) { return .mail }
        if terminal.contains(b) { return .terminal }
        if ai.contains(b) { return .ai }
        if let bk = browserKind(for: b) { return .browser(bk) }
        return .other
    }

    nonisolated static func browserKind(for bundleID: String) -> BrowserKind? {
        switch bundleID.lowercased() {
        case "com.apple.safari": return .safari
        case "com.google.chrome": return .chrome
        case "company.thebrowser.browser": return .arc
        case "com.brave.browser": return .brave
        case "com.microsoft.edgemac": return .edge
        case "org.mozilla.firefox": return .firefox
        default: return nil
        }
    }
}
