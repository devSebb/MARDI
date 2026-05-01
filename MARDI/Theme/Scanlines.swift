import SwiftUI

/// Pixel-neon scanlines — tighter, more saturated than the old CRT effect.
/// Draws alternating 1px lines in near-black, leaving the base surface showing.
/// Keep opacity low (≤ 0.14) so it reads as texture, not a pattern.
struct Scanlines: View {
    var opacity: Double = 0.05
    var spacing: CGFloat = 2

    /// Hermes-pass cap. Scanlines are texture, not pattern — anything above
    /// 0.06 reads as a visible stripe and breaks readability.
    private static let opacityCap: Double = 0.06

    var body: some View {
        let effOpacity = min(opacity, Self.opacityCap)
        return GeometryReader { geo in
            Canvas { context, size in
                let color = Color.black.opacity(effOpacity)
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(color))
                    y += spacing
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }
}

/// Neon glow — multi-layered shadow that feels like a bloom halo.
/// Used on interactive chrome (focused inputs, active buttons, character).
/// Multi-layered bloom halo. Hermes-pass: reserved for the fishbowl character
/// and explicit accent moments. Becomes a no-op below `radius < 3` so legacy
/// chrome glow call-sites silently flatten instead of producing tiny halos.
struct NeonGlow: ViewModifier {
    var color: Color = Palette.neonMagenta
    var radius: CGFloat = 5
    var intensity: Double = 0.45

    func body(content: Content) -> some View {
        if radius < 3 {
            content
        } else {
            content
                .shadow(color: color.opacity(intensity), radius: radius * 0.4)
                .shadow(color: color.opacity(intensity * 0.55), radius: radius)
        }
    }
}

// Backwards-compat: legacy `crtGlow` call-sites now render neon bloom.
struct CRTGlow: ViewModifier {
    var color: Color = Palette.neonCyan
    var radius: CGFloat = 4
    var intensity: Double = 0.35

    func body(content: Content) -> some View {
        content.modifier(NeonGlow(color: color, radius: radius, intensity: intensity))
    }
}

extension View {
    func neonGlow(color: Color = Palette.neonCyan, radius: CGFloat = 5, intensity: Double = 0.45) -> some View {
        modifier(NeonGlow(color: color, radius: radius, intensity: intensity))
    }

    func crtGlow(color: Color = Palette.neonCyan, radius: CGFloat = 4, intensity: Double = 0.35) -> some View {
        modifier(CRTGlow(color: color, radius: radius, intensity: intensity))
    }

    func scanlines(opacity: Double = 0.10, spacing: CGFloat = 2) -> some View {
        overlay(Scanlines(opacity: opacity, spacing: spacing))
    }

    // Compatibility overload for the second theme pass call-sites. The primary
    // pixel border implementation lives in PixelChrome.swift.
    func pixelBorder(color: Color = Palette.rule, glow: Color? = nil, cornerRadius: CGFloat = 2) -> some View {
        pixelBorder(color, width: 1, lit: glow != nil, radius: cornerRadius)
    }

    // Compatibility shorthand for older call-sites. The concrete BrailleField
    // implementation lives in PixelChrome.swift.
    func brailleField(opacity: Double = 0.10) -> some View {
        overlay(BrailleField(color: Palette.brailleDim, opacity: opacity, fontSize: 11, density: 0.35))
    }
}
