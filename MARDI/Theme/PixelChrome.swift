import SwiftUI

// MARK: - Braille glyph set

/// Braille characters used for pixel-dot patterns. Every glyph is a 2x4 dot-matrix,
/// which renders as chunky pixel texture in any monospace font.
enum Braille {
    static let fullBlock = "⣿"
    static let dense = ["⣿", "⣷", "⣯", "⣽", "⣾", "⣻", "⣟", "⡿"]
    static let medium = ["⣦", "⣶", "⣴", "⣤", "⣀", "⣠", "⣄", "⣆", "⣇", "⣈"]
    static let light = ["⠁", "⠂", "⠄", "⠈", "⠐", "⠠", "⡀", "⢀"]
    static let fill = "⠿"
    static let half = "⠶"
    static let dot = "⠂"
    static let corners = ["⡏", "⢹", "⣏", "⣹", "⣇", "⣸"]
    // A chunky horizontal bar (braille full row)
    static let bar = "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿"

    /// Deterministic-ish braille glyph for a given index. Good for wallpapering
    /// big areas with varied texture without visible repeat.
    static func pseudoRandom(_ seed: Int) -> String {
        let bag = dense + medium + medium + light
        return bag[abs(seed) % bag.count]
    }
}

// MARK: - Pixel border

/// Hard-edge pixel border. Draws two concentric strokes — outer accent, inner
/// shadow — to give a chunky "pixel art" frame. Optional outer bloom when lit.
struct PixelBorder: ViewModifier {
    var color: Color = Palette.neonCyan
    var width: CGFloat = 1.5
    var lit: Bool = false
    var radius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(color, lineWidth: width)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .inset(by: width)
                    .strokeBorder(Color.black.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: lit ? color.opacity(0.45) : .clear, radius: lit ? 3 : 0)
            .shadow(color: lit ? color.opacity(0.22) : .clear, radius: lit ? 7 : 0)
    }
}

extension View {
    func pixelBorder(_ color: Color = Palette.neonCyan, width: CGFloat = 1.5, lit: Bool = false, radius: CGFloat = 0) -> some View {
        modifier(PixelBorder(color: color, width: width, lit: lit, radius: radius))
    }
}

// MARK: - Braille divider

/// A horizontal divider rendered as a strip of braille glyphs. Adds texture
/// to section breaks without a hard line. Use sparingly — it's a strong signal.
struct BrailleDivider: View {
    var color: Color = Palette.border
    var glyph: String = "⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒"
    var size: CGFloat = 9

    var body: some View {
        Text(glyph)
            .font(.system(size: size, weight: .regular, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
    }
}

// MARK: - Braille field (background texture)

/// Background field of braille dots at low opacity. Gives the illusion of a
/// pixel-grid wallpaper behind whatever it's placed under.
struct BrailleField: View {
    var color: Color = Palette.brailleDim
    var opacity: Double = 1.0
    var fontSize: CGFloat = 11
    var density: Double = 0.55   // 0 = sparse, 1 = dense

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let cellW: CGFloat = fontSize * 0.72
                let cellH: CGFloat = fontSize * 1.10
                let cols = Int(ceil(size.width / cellW)) + 1
                let rows = Int(ceil(size.height / cellH)) + 1

                for r in 0..<rows {
                    for c in 0..<cols {
                        let seed = (r &* 31) &+ c
                        let bucket = Double((seed &* 2654435761) & 0xFFFF) / 65535.0
                        guard bucket < density else { continue }
                        let glyph = Braille.pseudoRandom(seed)
                        let x = CGFloat(c) * cellW
                        let y = CGFloat(r) * cellH
                        let text = Text(glyph)
                            .font(.system(size: fontSize, design: .monospaced))
                            .foregroundColor(color.opacity(opacity))
                        ctx.draw(text, at: CGPoint(x: x, y: y), anchor: .topLeading)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Braille label

/// Leading braille marker + uppercased label. Used for section headings and
/// chrome labels. Gives every section a small pixel-agent identifier.
struct BrailleLabel: View {
    var text: String
    var prefix: String = "⠿"
    var color: Color = Palette.neonCyan
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            Text(prefix)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(text.uppercased())
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Neon panel background

/// Standard MARDI panel: deep void fill, braille-field wallpaper, pixel border,
/// scanlines on top. One-liner for every card / panel / overlay.
struct NeonPanel: ViewModifier {
    var fill: Color = Palette.panelSlate
    var border: Color = Palette.neonMagenta
    var borderWidth: CGFloat = 1.5
    var radius: CGFloat = 0
    var lit: Bool = false
    var braille: Bool = true
    var scanlines: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Rectangle().fill(fill)
                    if braille {
                        BrailleField(color: Palette.brailleDim, opacity: 0.45, fontSize: 11, density: 0.35)
                    }
                    if scanlines {
                        Scanlines(opacity: 0.08, spacing: 3)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .pixelBorder(border, width: borderWidth, lit: lit, radius: radius)
    }
}

extension View {
    func neonPanel(
        fill: Color = Palette.panelSlate,
        border: Color = Palette.neonMagenta,
        borderWidth: CGFloat = 1.5,
        radius: CGFloat = 0,
        lit: Bool = false,
        braille: Bool = true,
        scanlines: Bool = true
    ) -> some View {
        modifier(NeonPanel(fill: fill, border: border, borderWidth: borderWidth, radius: radius, lit: lit, braille: braille, scanlines: scanlines))
    }
}

// MARK: - Pixel button style

struct PixelButtonStyle: ButtonStyle {
    var tint: Color = Palette.neonCyan
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Rectangle()
                    .fill(filled ? tint.opacity(0.22) : tint.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .pixelBorder(tint, width: 1.5, lit: configuration.isPressed, radius: 0)
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(configuration.isPressed ? 0.45 : 0.2), radius: configuration.isPressed ? 6 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static func pixel(_ tint: Color = Palette.neonCyan, filled: Bool = false) -> PixelButtonStyle {
        PixelButtonStyle(tint: tint, filled: filled)
    }
}

// MARK: - Agent header

/// Hermes-agent-style titled section: `╔══⠿⠿⠿ MARDI ⠿⠿⠿══╗` feel, pixel only.
struct AgentHeader: View {
    var title: String
    var subtitle: String?
    var tint: Color = Palette.neonMagenta

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("⣿⣿")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                Text("[\(title.uppercased())]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
                Text("⣿⣿")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.textMuted)
            }
            BrailleDivider(color: tint.opacity(0.55))
        }
    }
}
