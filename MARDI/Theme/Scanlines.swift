import SwiftUI

/// A subtle CRT-scanline overlay. Draws every other horizontal line at low opacity.
/// Keep the opacity low (≤ 0.08) so it reads as texture, not pattern.
struct Scanlines: View {
    var opacity: Double = 0.06
    var spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let color = Color.black.opacity(opacity)
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

struct CRTGlow: ViewModifier {
    var color: Color = Palette.phosphor
    var radius: CGFloat = 6
    var intensity: Double = 0.35

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.5), radius: radius * 2)
    }
}

extension View {
    func crtGlow(color: Color = Palette.phosphor, radius: CGFloat = 6, intensity: Double = 0.35) -> some View {
        modifier(CRTGlow(color: color, radius: radius, intensity: intensity))
    }

    func scanlines(opacity: Double = 0.06, spacing: CGFloat = 2) -> some View {
        overlay(Scanlines(opacity: opacity, spacing: spacing))
    }
}
