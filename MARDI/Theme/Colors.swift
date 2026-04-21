import SwiftUI

/// MARDI's retro-future palette. Dark by default.
enum Palette {
    static let charcoal = Color(hex: 0x0F1115)
    static let panelSlate = Color(hex: 0x1A1D23)
    static let panelSlateHi = Color(hex: 0x23272F)
    static let bubbleBg = Color(hex: 0x0E0F10)
    static let border = Color(hex: 0x2C313A)
    static let borderBright = Color(hex: 0x3B4250)

    static let textPrimary = Color(hex: 0xE6E8EC)
    static let textSecondary = Color(hex: 0x9AA1AB)
    static let textMuted = Color(hex: 0x5C6370)

    static let phosphor = Color(hex: 0x8CF59A)        // accent / success
    static let phosphorDim = Color(hex: 0x4F8A5A)
    static let amber = Color(hex: 0xF5C26B)            // warnings
    static let magenta = Color(hex: 0xFF77AA)          // "magic" moments
    static let sky = Color(hex: 0x7DC7FF)              // links, info
    static let rust = Color(hex: 0xE58A6B)             // errors
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
        case .url: Palette.sky
        case .snippet: Palette.phosphor
        case .ssh: Palette.amber
        case .prompt: Palette.magenta
        case .signature: Palette.sky
        case .reply: Palette.phosphor
        case .note: Palette.textPrimary
        case .select: Palette.magenta
        }
    }
}
