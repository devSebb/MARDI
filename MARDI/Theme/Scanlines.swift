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

struct PixelBorder: ViewModifier {
    var color: Color = Palette.rule
    var glow: Color? = nil
    var cornerRadius: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Palette.ink.opacity(0.9), lineWidth: 1)
                    .padding(-1)
            )
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.22), radius: 18)
    }
}

struct BrailleField: View {
    var opacity: Double = 0.10
    var spacing: CGSize = CGSize(width: 9, height: 11)

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.4, height: 1.4))
                var y: CGFloat = 1
                var row = 0
                while y < size.height {
                    var x: CGFloat = row.isMultiple(of: 2) ? 1 : 5
                    while x < size.width {
                        context.translateBy(x: x, y: y)
                        context.fill(dot, with: .color(Palette.bone.opacity(opacity)))
                        context.translateBy(x: -x, y: -y)
                        x += spacing.width
                    }
                    row += 1
                    y += spacing.height
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func crtGlow(color: Color = Palette.phosphor, radius: CGFloat = 6, intensity: Double = 0.35) -> some View {
        modifier(CRTGlow(color: color, radius: radius, intensity: intensity))
    }

    func scanlines(opacity: Double = 0.06, spacing: CGFloat = 2) -> some View {
        overlay(Scanlines(opacity: opacity, spacing: spacing))
    }

    func pixelBorder(color: Color = Palette.rule, glow: Color? = nil, cornerRadius: CGFloat = 2) -> some View {
        modifier(PixelBorder(color: color, glow: glow, cornerRadius: cornerRadius))
    }

    func brailleField(opacity: Double = 0.10) -> some View {
        overlay(BrailleField(opacity: opacity))
    }
}
