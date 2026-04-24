import SwiftUI

/// The app-facing Mardi character. This is intentionally procedural and
/// braille-native: no bitmap or PNG sampling is required to render the model.
struct MardiFishBrailleView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero

    var body: some View {
        MardiRobotView(mood: mood, size: size, cursorOffset: cursorOffset)
    }
}

#Preview("Braille Mardi", traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        ForEach(
            [MardiMood.idle, .summoned, .thinking, .success, .error, .sleeping],
            id: \.self
        ) { mood in
            MardiFishBrailleView(mood: mood, size: 96)
        }
    }
    .padding(20)
    .background(Palette.charcoal)
}
