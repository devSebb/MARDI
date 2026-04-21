import Foundation
import AppKit

enum ClipboardReader {
    /// Returns the current clipboard as text if it looks like reasonable text
    /// to save (non-empty, ≤ 8KB, not binary).
    static func currentText(maxBytes: Int = 8192) -> String? {
        let pb = NSPasteboard.general
        guard let s = pb.string(forType: .string) else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.utf8.count > maxBytes { return nil }
        return trimmed
    }

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
