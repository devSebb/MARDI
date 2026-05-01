import SwiftUI
import AppKit

/// App-wide UI zoom. Persisted in UserDefaults so it survives relaunch.
/// Read at body-eval time by every Typeface helper. Views that want live
/// updates (without a relaunch) should declare a matching `@AppStorage`
/// so SwiftUI re-renders the subtree when the value changes.
enum UIZoom {
    static let key = "mardi.uiZoom"
    static let defaultValue: Double = 1.0
    static let minValue: Double = 0.9
    static let maxValue: Double = 2.0
    static let step: Double = 0.1

    /// Body text is the only face with a comfort floor — chrome (mono/pixel)
    /// stays at its literal point size × zoom because the small chrome is
    /// part of the pixel-CRT aesthetic.
    static let bodyMinPoints: CGFloat = 11

    static var current: Double {
        let raw = UserDefaults.standard.double(forKey: key)
        return raw == 0 ? defaultValue : clamp(raw)
    }

    static func clamp(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}

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
        let scaled = size * CGFloat(UIZoom.current)
        if !pixel.isEmpty {
            return .custom(pixel, size: scaled)
        }
        // Fallback: heavy monospaced gives a similar chunky feel.
        return .system(size: scaled, weight: .heavy, design: .monospaced)
    }

    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaled = size * CGFloat(UIZoom.current)
        if !mono.isEmpty {
            return .custom(mono, size: scaled).weight(weight)
        }
        return .system(size: scaled, weight: weight, design: .monospaced)
    }

    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let floored = max(size, UIZoom.bodyMinPoints)
        let scaled = floored * CGFloat(UIZoom.current)
        return .system(size: scaled, weight: weight, design: .monospaced)
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
