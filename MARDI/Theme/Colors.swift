import SwiftUI

/// MARDI's pixel-neon palette. Inspired by the fishbowl character:
/// void-black backgrounds, cyan water glow, magenta rim light, fiery orange fish,
/// violet ambient. Existing semantic keys (phosphor, amber, sky, magenta, rust)
/// are preserved so every call-site gets the new look without a rename.
enum Palette {
    // Surfaces — deep void with a violet undertone.
    static let voidBlack = Color(hex: 0x000000)
    static let charcoal = Color(hex: 0x07030F)         // app background
    static let panelSlate = Color(hex: 0x0F0822)       // primary panel
    static let panelSlateHi = Color(hex: 0x1A1038)     // raised panel
    static let bubbleBg = Color(hex: 0x04020A)         // inset fields / editors

    // Borders — dim violet that lights up to magenta when focused.
    static let border = Color(hex: 0x2A1A50)
    static let borderBright = Color(hex: 0x6B3FAA)
    static let brailleDim = Color(hex: 0x1E124A)       // braille dot-field ink

    // Text — pixel white with blue tint → muted violet-gray.
    static let textPrimary = Color(hex: 0xF0F3FF)
    static let textSecondary = Color(hex: 0x8B8FA5)
    static let textMuted = Color(hex: 0x4A4F66)

    // Neon accents — the core of the fishbowl palette.
    static let neonCyan = Color(hex: 0x3EF0FF)         // primary / success / "water"
    static let neonCyanDim = Color(hex: 0x0A98B8)
    static let neonMagenta = Color(hex: 0xFF2ECC)      // selection / "rim light"
    static let neonMagentaDim = Color(hex: 0xB0208A)
    static let neonOrange = Color(hex: 0xFF7A18)       // warning / "fish"
    static let neonOrangeDim = Color(hex: 0xB54A0A)
    static let neonRed = Color(hex: 0xFF3355)          // error / destructive
    static let neonViolet = Color(hex: 0xB37BFF)       // info / secondary accent

    // Legacy semantic aliases — these map existing call-sites onto the new palette.
    // Do not remove: LibraryView, MonsterView, SettingsView, etc. all reference these.
    static let phosphor = neonCyan
    static let phosphorDim = neonCyanDim
    static let amber = neonOrange
    static let magenta = neonMagenta
    static let sky = neonViolet
    static let rust = neonRed
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension MemoryType {
    var accent: Color {
        switch self {
        case .url: Palette.neonViolet
        case .snippet: Palette.neonCyan
        case .ssh: Palette.neonOrange
        case .prompt: Palette.neonMagenta
        case .signature: Palette.neonViolet
        case .reply: Palette.neonCyan
        case .note: Palette.textPrimary
        case .select: Palette.neonMagenta
        }
    }
}
