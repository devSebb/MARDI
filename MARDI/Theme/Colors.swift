import SwiftUI

/// MARDI's landing-page palette. Dark, bone-on-ink, with pink as the primary
/// active color and cyan/violet/gold as secondary type accents.
enum Palette {
    static let ink = Color(hex: 0x08070B)
    static let ink2 = Color(hex: 0x0D0B13)
    static let ink3 = Color(hex: 0x15121D)
    static let bone = Color(hex: 0xF3F1EC)
    static let bone2 = Color(hex: 0xB7B3AA)
    static let bone3 = Color(hex: 0x6B6860)
    static let bone4 = Color(hex: 0x3A3832)
    static let rule = Color(hex: 0x242029)
    static let ruleHi = Color(hex: 0x3A3444)

    static let pink = Color(hex: 0xFF2ECC)
    static let pinkDim = Color(hex: 0xB0208A)
    static let cyan = Color(hex: 0x3EF0FF)
    static let violet = Color(hex: 0xB37BFF)
    static let gold = Color(hex: 0xFFB63D)
    static let orange = Color(hex: 0xFF7A18)
    static let red = Color(hex: 0xFF3355)

    // Compatibility aliases for the existing SwiftUI surfaces.
    static let charcoal = ink
    static let panelSlate = ink2
    static let panelSlateHi = ink3
    static let bubbleBg = ink
    static let border = rule
    static let borderBright = ruleHi

    static let textPrimary = bone
    static let textSecondary = bone2
    static let textMuted = bone3

    static let phosphor = pink
    static let phosphorDim = pinkDim
    static let amber = gold
    static let magenta = violet
    static let sky = cyan
    static let rust = red
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
        case .url: Palette.orange
        case .snippet: Palette.cyan
        case .ssh: Palette.gold
        case .prompt: Palette.pink
        case .signature: Palette.violet
        case .reply: Palette.cyan
        case .note: Palette.textPrimary
        case .select: Palette.gold
        }
    }

    var brailleGlyph: String {
        switch self {
        case .url: "⣷"
        case .snippet: "⣶"
        case .ssh: "⣯"
        case .prompt: "⣻"
        case .signature: "⣽"
        case .reply: "⣟"
        case .note: "⡿"
        case .select: "⠿"
        }
    }
}
