import Foundation
import AppKit

/// Reads the current tab's URL + title from the frontmost supported browser
/// via AppleScript. Triggers macOS Automation permission prompt the first
/// time per-browser. Firefox is not supported — surface a friendly message.
enum BrowserURLReader {
    struct Result {
        let url: String
        let title: String
        let bundleID: String
    }

    enum ReaderError: LocalizedError {
        case unsupportedBrowser(String)
        case scriptFailed(String)
        case noFrontmost

        var errorDescription: String? {
            switch self {
            case .unsupportedBrowser(let name):
                "\(name) doesn't support URL capture. Copy the URL and use Snippet instead."
            case .scriptFailed(let s):
                "Couldn't read the browser: \(s)"
            case .noFrontmost:
                "No browser is active."
            }
        }
    }

    static func readFromFrontmost() throws -> Result {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bid = app.bundleIdentifier
        else {
            throw ReaderError.noFrontmost
        }
        return try readFromBrowser(bundleID: bid, appName: app.localizedName ?? bid)
    }

    static func readFromBrowser(bundleID: String, appName: String) throws -> Result {
        let browser = ActiveAppWatcher.browserKind(for: bundleID)
        switch browser {
        case .safari:
            return try runSafari(bundleID: bundleID)
        case .chrome, .arc, .brave, .edge:
            return try runChromium(bundleID: bundleID, appName: chromiumAppName(bundleID: bundleID, fallback: appName))
        case .firefox:
            throw ReaderError.unsupportedBrowser("Firefox")
        case .none:
            throw ReaderError.unsupportedBrowser(appName)
        }
    }

    private static func chromiumAppName(bundleID: String, fallback: String) -> String {
        switch bundleID.lowercased() {
        case "com.google.chrome": "Google Chrome"
        case "company.thebrowser.browser": "Arc"
        case "com.brave.browser": "Brave Browser"
        case "com.microsoft.edgemac": "Microsoft Edge"
        default: fallback
        }
    }

    private static func runSafari(bundleID: String) throws -> Result {
        let script = """
        tell application "Safari"
            set theURL to URL of current tab of front window
            set theTitle to name of front window
            return theURL & "\\n" & theTitle
        end tell
        """
        let (url, title) = try runAppleScriptTwoLines(script)
        return Result(url: url, title: title, bundleID: bundleID)
    }

    private static func runChromium(bundleID: String, appName: String) throws -> Result {
        let script = """
        tell application "\(appName)"
            set theURL to URL of active tab of front window
            set theTitle to title of active tab of front window
            return theURL & "\\n" & theTitle
        end tell
        """
        let (url, title) = try runAppleScriptTwoLines(script)
        return Result(url: url, title: title, bundleID: bundleID)
    }

    private static func runAppleScriptTwoLines(_ source: String) throws -> (String, String) {
        guard let script = NSAppleScript(source: source) else {
            throw ReaderError.scriptFailed("could not compile AppleScript")
        }
        var errInfo: NSDictionary?
        let result = script.executeAndReturnError(&errInfo)
        if let err = errInfo {
            let msg = err[NSAppleScript.errorMessage] as? String ?? "unknown AppleScript error"
            throw ReaderError.scriptFailed(msg)
        }
        guard let text = result.stringValue else {
            throw ReaderError.scriptFailed("empty AppleScript result")
        }
        let parts = text.components(separatedBy: "\n")
        let url = parts.first ?? ""
        let title = parts.count > 1 ? parts[1] : ""
        return (url, title)
    }
}
