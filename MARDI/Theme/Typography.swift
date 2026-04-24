import SwiftUI
import AppKit

/// MARDI typography. Mono is the dominant face (all chrome, titles, ids).
/// A bundled pixel font (Press Start 2P / Silkscreen) is preferred if the user
/// has it installed; we fall back to the system monospaced face so builds never
/// fail for missing fonts.
enum Typeface {
    /// Preferred pixel-art font for big display chrome. Falls through to mono
    /// if no pixel font is installed.
    static let pixel: String = {
        let candidates = [
            "PressStart2P-Regular", "Press Start 2P",
            "Silkscreen-Regular", "Silkscreen",
            "MondayPixel-Regular",
            "VT323-Regular"
        ]
        for name in candidates {
            if NSFont(name: name, size: 12) != nil { return name }
        }
        return ""
    }()

    /// Monospace for all chrome, titles, ids.
    static let mono: String = {
        let candidates = ["BerkeleyMono-Regular", "Berkeley Mono", "JetBrainsMono-Regular", "JetBrains Mono"]
        for name in candidates {
            if NSFont(name: name, size: 12) != nil { return name }
        }
        return ""
    }()

    static let body: String = ""

    static func pixelFont(size: CGFloat) -> Font {
        if !pixel.isEmpty {
            return .custom(pixel, size: size)
        }
        // Fallback: heavy monospaced gives a similar chunky feel.
        return .system(size: size, weight: .heavy, design: .monospaced)
    }

    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if !mono.isEmpty {
            return .custom(mono, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func pixelFont(_ size: CGFloat) -> some View {
        font(Typeface.pixelFont(size: size))
    }

    func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(Typeface.monoFont(size: size, weight: weight))
    }

    func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(Typeface.bodyFont(size: size, weight: weight))
    }
}
