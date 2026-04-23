import SwiftUI
import AppKit

/// Renders MardiFish.png as animated Unicode braille (U+2800–U+28FF).
/// Samples the PNG once into a 64×64 dot grid, then re-encodes each 2×4 dot
/// block as a braille character every frame. Animations: idle bob, tail wave,
/// and rising bubble particles — all procedural, no extra assets needed.
struct MardiFishBrailleView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero   // API compat

    private let gridCols = 32
    private let gridRows = 16

    @State private var startDate = Date()
    @State private var dots: [[Bool]] = []   // [dotRow][dotCol], 64×64

    // Inset so top/bottom font ascenders don't clip against the canvas edge
    private let inset: CGFloat = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, canvasSize in
                guard !dots.isEmpty else { return }
                let charH = (canvasSize.height - inset * 2) / CGFloat(gridRows)
                let charW = (canvasSize.width  - inset * 2) / CGFloat(gridCols)
                let font  = Font.system(size: charH * 0.98, design: .monospaced)
                renderFish(ctx: &ctx, charH: charH, charW: charW, font: font, t: t)
                renderBubbles(ctx: &ctx, charH: charH, charW: charW, font: font, t: t)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: moodColor.opacity(0.55), radius: size * 0.06)
        .shadow(color: moodColor.opacity(0.22), radius: size * 0.15)
        .onAppear { dots = Self.loadDots(dotCols: 64, dotRows: 64) }
        .animation(.easeInOut(duration: 0.3), value: mood)
    }

    // MARK: - Fish body

    private func renderFish(
        ctx: inout GraphicsContext,
        charH: CGFloat, charW: CGFloat,
        font: Font, t: Double
    ) {
        let dotCols = gridCols * 2   // 64
        let dotRows = gridRows * 4   // 64
        let bob = Int(round(sin(t * 1.2) * 2.5))

        for row in 0..<gridRows {
            var rowStr = ""
            for col in 0..<gridCols {
                let dotX = col * 2
                let dotY = row * 4
                // Tail wave: left ~40% of image where fins/tail live, strongest at col 0
                let tailFactor = max(0.0, 1.0 - Double(col) / (Double(gridCols) * 0.40))
                let wave = tailFactor > 0.01
                    ? Int(round(sin(t * 2.5 + Double(col) * 0.5) * tailFactor * 2.0))
                    : 0
                let yOff = bob + wave
                var cp: UInt32 = 0x2800
                for (dc, dr, bit) in brailleLayout {
                    let sx = dotX + dc
                    let sy = dotY + dr + yOff
                    if sx >= 0, sx < dotCols, sy >= 0, sy < dotRows, dots[sy][sx] {
                        cp |= bit
                    }
                }
                rowStr.append(Character(UnicodeScalar(cp)!))
            }
            ctx.draw(
                Text(rowStr).font(font).foregroundStyle(moodColor),
                at: CGPoint(x: inset, y: inset + CGFloat(row) * charH),
                anchor: .topLeading
            )
        }
    }

    // MARK: - Bubbles

    private func renderBubbles(
        ctx: inout GraphicsContext,
        charH: CGFloat, charW: CGFloat,
        font: Font, t: Double
    ) {
        // Fish mouth is ~63% x, 50% y in the dot grid
        let mouthDotX = Int(Double(gridCols * 2) * 0.63)
        let mouthDotY = Int(Double(gridRows * 4) * 0.50)
        let glyphs: [Character] = ["⠂", "⠄", "⡀"]

        for i in 0..<3 {
            let phase    = (t * 0.45 + Double(i) * 0.73).truncatingRemainder(dividingBy: 2.2)
            let progress = phase / 2.2
            let opacity  = progress > 0.82 ? max(0, 1.0 - (progress - 0.82) / 0.18) : 1.0
            let dotY     = mouthDotY - Int(progress * 14.0)
            let dotX     = mouthDotX + (i == 1 ? 2 : 0)
            let charCol  = dotX / 2
            let charRow  = dotY / 4
            guard charRow >= 0, charRow < gridRows,
                  charCol >= 0, charCol < gridCols else { continue }
            ctx.draw(
                Text(String(glyphs[i % glyphs.count]))
                    .font(font)
                    .foregroundStyle(moodColor.opacity(opacity)),
                at: CGPoint(x: inset + CGFloat(charCol) * charW, y: inset + CGFloat(charRow) * charH),
                anchor: .topLeading
            )
        }
    }

    // MARK: - Braille layout
    // Each entry: (dot-column offset, dot-row offset, bit in codepoint)
    // Braille dot positions: 2 cols × 4 rows, packed as U+2800 + bitmask
    private let brailleLayout: [(Int, Int, UInt32)] = [
        (0, 0, 0x01), (1, 0, 0x08),   // row 0: dot1, dot4
        (0, 1, 0x02), (1, 1, 0x10),   // row 1: dot2, dot5
        (0, 2, 0x04), (1, 2, 0x20),   // row 2: dot3, dot6
        (0, 3, 0x40), (1, 3, 0x80),   // row 3: dot7, dot8
    ]

    // MARK: - Mood color

    private var moodColor: Color {
        switch mood {
        case .idle:      return Palette.neonCyan
        case .summoned:  return Palette.neonMagenta
        case .listening: return Palette.neonMagenta
        case .thinking:  return Palette.neonOrange
        case .success:   return Palette.neonCyan
        case .error:     return Palette.neonRed
        case .selectMode: return Palette.neonViolet
        case .sleeping:  return Palette.neonViolet.opacity(0.4)
        }
    }

    // MARK: - Pixel data

    @MainActor
    static func loadDots(dotCols: Int, dotRows: Int) -> [[Bool]] {
        let ns: NSImage? = NSImage(named: "MardiFish")
            ?? Bundle.main.path(forResource: "MardiFish", ofType: "png")
                         .flatMap { NSImage(contentsOfFile: $0) }
        guard let image = ns else { return [] }

        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return [] }

        let w = cg.width, h = cg.height
        let bpr = w * 4
        var px = [UInt8](repeating: 0, count: h * bpr)
        guard let ctx = CGContext(
            data: &px, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        // Flip Y so row 0 = visual top of image
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var result = [[Bool]](repeating: [Bool](repeating: false, count: dotCols), count: dotRows)
        for dy in 0..<dotRows {
            for dx in 0..<dotCols {
                let srcX = min(Int(Double(dx) / Double(dotCols) * Double(w)), w - 1)
                let srcY = min(Int(Double(dy) / Double(dotRows) * Double(h)), h - 1)
                let off  = srcY * bpr + srcX * 4
                let lum  = (0.299 * Double(px[off]) + 0.587 * Double(px[off+1]) + 0.114 * Double(px[off+2])) / 255.0
                result[dy][dx] = lum > 0.12
            }
        }
        return result
    }
}

#Preview("Braille Fish", traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        ForEach(
            [MardiMood.idle, .summoned, .thinking, .success, .error, .sleeping],
            id: \.self
        ) { m in
            VStack(spacing: 4) {
                MardiFishBrailleView(mood: m, size: 96)
                Text(String(describing: m))
                    .monoFont(9)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
    .padding(20)
    .background(Palette.charcoal)
}
