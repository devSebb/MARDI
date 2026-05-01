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

    // Neon accents — disciplined. Magenta is THE accent; red is errors only.
    // Cyan / orange / violet exist for the fishbowl character + targeted call-sites
    // (graph edges, mood states) but are demoted everywhere else to bone tints
    // via the muted aliases below.
    static let neonMagenta = Color(hex: 0xFF2ECC)      // the one accent — selection, focus, brand, primary CTA
    static let neonMagentaDim = Color(hex: 0xB0208A)
    static let neonRed = Color(hex: 0xFF3355)          // errors only — never decorative

    // Reserved-use neons. Do NOT use for chrome. Reserved for: the fishbowl
    // character, graph edges, mood-driven character cues, and explicit Phase-5
    // overrides. Default chrome should pull from the bone hierarchy instead.
    static let neonCyan = Color(hex: 0x3EF0FF)
    static let neonOrange = Color(hex: 0xFF7A18)
    static let neonViolet = Color(hex: 0xB37BFF)
    static let neonGold = Color(hex: 0xFFB63D)

    // Legacy semantic aliases — these map existing call-sites onto the new palette.
    // The Hermes-pass demotes cyan/amber/sky to the bone hierarchy so any view
    // still naming them by their old semantic role gets a calm monochrome look
    // without an explicit edit. Magenta + red stay loud; violet stays for graph
    // strong-edges only.
    static let phosphor = textSecondary       // was neonCyan — demoted to bone
    static let phosphorDim = textMuted
    static let amber = textSecondary          // was neonOrange — demoted to bone
    static let magenta = neonMagenta
    static let sky = textSecondary            // was neonViolet — demoted to bone
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
    static let cyan = textSecondary           // demoted alongside neonCyan
    static let violet = textSecondary         // demoted alongside neonViolet
    static let gold = neonGold
    static let orange = textSecondary         // demoted alongside neonOrange
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
    /// Type accent. Hermes-pass: every type returns the same bone tint — the
    /// glyph + 3-letter shortcode already encodes the type, so color was only
    /// ever decorative. Selection state (`isActive`/selected row) is what
    /// pulls magenta, not the type itself.
    var accent: Color {
        Palette.textSecondary
    }
}
