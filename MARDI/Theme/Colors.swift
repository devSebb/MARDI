import SwiftUI

/// MARDI's pixel-neon palette. Inspired by the fishbowl character:
/// void-black backgrounds, cyan water glow, magenta rim light, fiery orange fish,
/// violet ambient. Existing semantic keys (phosphor, amber, sky, magenta, rust)
/// are preserved so every call-site gets the new look without a rename.
enum Palette {
    // Surfaces — near-black with a faint violet undertone (matches web ink palette).
    static let voidBlack = Color(hex: 0x000000)
    static let charcoal = Color(hex: 0x08070B)         // app background (web: --ink)
    static let panelSlate = Color(hex: 0x0D0B13)       // primary panel (web: --ink-2)
    static let panelSlateHi = Color(hex: 0x15121D)     // raised panel (web: --ink-3)
    static let bubbleBg = Color(hex: 0x0D0B13)         // inset fields / editors

    // Borders — very dim, rule-like (matches web --rule / --rule-hi).
    static let border = Color(hex: 0x242029)
    static let borderBright = Color(hex: 0x3A3444)
    static let brailleDim = Color(hex: 0x1C1820)       // braille dot-field ink

    // Text — warm bone hierarchy (web: --bone / --bone-2 / --bone-3).
    static let textPrimary = Color(hex: 0xF3F1EC)
    static let textSecondary = Color(hex: 0xB7B3AA)
    static let textMuted = Color(hex: 0x6B6860)

    // Neon accents — the core of the fishbowl palette.
    static let neonCyan = Color(hex: 0x3EF0FF)         // primary / success / "water"
    static let neonCyanDim = Color(hex: 0x0A98B8)
    static let neonMagenta = Color(hex: 0xFF2ECC)      // selection / "rim light"
    static let neonMagentaDim = Color(hex: 0xB0208A)
    static let neonOrange = Color(hex: 0xFF7A18)       // warning / "fish"
    static let neonOrangeDim = Color(hex: 0xB54A0A)
    static let neonRed = Color(hex: 0xFF3355)          // error / destructive
    static let neonViolet = Color(hex: 0xB37BFF)       // info / secondary accent
    static let neonGold = Color(hex: 0xFFB63D)

    // Legacy semantic aliases — these map existing call-sites onto the new palette.
    // Do not remove: LibraryView, MonsterView, SettingsView, etc. all reference these.
    static let phosphor = neonCyan
    static let phosphorDim = neonCyanDim
    static let amber = neonOrange
    static let magenta = neonMagenta
    static let sky = neonViolet
    static let rust = neonRed

    // Landing-page token aliases used by the second theme pass.
    static let ink = charcoal
    static let ink2 = panelSlate
    static let ink3 = panelSlateHi
    static let bone = textPrimary
    static let bone2 = textSecondary
    static let bone3 = textMuted
    static let bone4 = Color(hex: 0x3A3832)
    static let rule = border
    static let ruleHi = borderBright
    static let pink = neonMagenta
    static let pinkDim = neonMagentaDim
    static let cyan = neonCyan
    static let violet = neonViolet
    static let gold = neonGold
    static let orange = neonOrange
    static let red = neonRed
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
