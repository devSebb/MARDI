import SwiftUI
import AppKit

/// Pixel-art fishbowl character. Renders the bundled `MardiFish.png` with
/// nearest-neighbor scaling so pixels stay crisp at any size.
///
/// The `mood` prop is accepted for API compatibility with the old robot view
/// and drives subtle tinting today; frame-level animation comes later when
/// sprite frames land.
struct MardiFishView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero   // accepted for API compat; unused today

    var body: some View {
        ZStack {
            image
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .overlay(moodTint)
                .shadow(color: glowColor.opacity(0.35), radius: size * 0.05)
                .shadow(color: glowColor.opacity(0.18), radius: size * 0.12)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: mood)
    }

    private var image: Image {
        if let ns = NSImage(named: "MardiFish") {
            return Image(nsImage: ns)
        }
        if let path = Bundle.main.path(forResource: "MardiFish", ofType: "png"),
           let ns = NSImage(contentsOfFile: path) {
            return Image(nsImage: ns)
        }
        // Last-ditch fallback — still renders without crashing.
        return Image(systemName: "fish.fill")
    }

    private var glowColor: Color {
        switch mood {
        case .error: return Palette.neonRed
        case .thinking: return Palette.neonOrange
        case .success: return Palette.neonCyan
        case .listening: return Palette.neonMagenta
        case .summoned: return Palette.neonMagenta
        case .selectMode: return Palette.neonViolet
        case .sleeping: return Palette.neonViolet.opacity(0.5)
        case .idle: return Palette.neonCyan
        }
    }

    @ViewBuilder
    private var moodTint: some View {
        switch mood {
        case .error:
            Rectangle().fill(Palette.neonRed.opacity(0.18)).blendMode(.screen)
        case .success:
            Rectangle().fill(Palette.neonCyan.opacity(0.14)).blendMode(.screen)
        case .sleeping:
            Rectangle().fill(Color.black.opacity(0.35))
        default:
            EmptyView()
        }
    }
}

#Preview("Fish moods", traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        ForEach([MardiMood.idle, .summoned, .listening, .thinking, .success, .error, .selectMode, .sleeping], id: \.self) { m in
            VStack(spacing: 4) {
                MardiFishView(mood: m, size: 96)
                Text(String(describing: m))
                    .monoFont(9)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
    .padding(20)
    .background(Palette.charcoal)
}
