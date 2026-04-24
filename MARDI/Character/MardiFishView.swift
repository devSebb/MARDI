import SwiftUI

/// Compatibility wrapper for older call-sites. Mardi is rendered by the
/// procedural braille model, not by a bundled image asset.
struct MardiFishView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero

    var body: some View {
        MardiFishBrailleView(mood: mood, size: size, cursorOffset: cursorOffset)
    }
}
