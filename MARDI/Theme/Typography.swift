import SwiftUI

/// MARDI uses one monospace for chrome + memory titles, and a clean sans for long-form body.
enum Typeface {
    /// Prefer Berkeley Mono if installed, fall back to JetBrains Mono, then system mono.
    static let mono: String = {
        let candidates = ["BerkeleyMono-Regular", "Berkeley Mono", "JetBrainsMono-Regular", "JetBrains Mono"]
        for name in candidates {
            if NSFont(name: name, size: 12) != nil { return name }
        }
        return ""
    }()

    /// System SF font for body prose; swap for Inter later if bundled.
    static let body: String = ""

    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if !mono.isEmpty {
            return .custom(mono, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
}

extension View {
    func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(Typeface.monoFont(size: size, weight: weight))
    }

    func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(Typeface.bodyFont(size: size, weight: weight))
    }
}
