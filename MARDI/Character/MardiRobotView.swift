import SwiftUI

/// Procedurally-rendered Mardi character. This intentionally avoids bitmap
/// assets: the fishbowl, body, moods, and texture are all SwiftUI shapes/text.
struct MardiRobotView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            ZStack {
                glow(t: t)
                bowl
                brailleBody(t: t)
                moodMark(t: t)
                statusRail(t: t)
            }
            .frame(width: size, height: size)
            .scaleEffect(popScale(t: t))
            .offset(y: bobOffset(t: t))
            .accessibilityLabel("Mardi")
        }
    }

    private func glow(t: TimeInterval) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        moodColor.opacity(0.24 + 0.04 * sin(t * 2.4)),
                        Palette.bone.opacity(0.06),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.08,
                    endRadius: size * 0.54
                )
            )
            .blur(radius: size * 0.07)
    }

    private var bowl: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Palette.ink2)
                .brailleField(opacity: 0.07)
                .pixelBorder(color: Palette.ruleHi, glow: moodColor, cornerRadius: size * 0.06)

            RoundedRectangle(cornerRadius: size * 0.03)
                .stroke(Palette.bone.opacity(0.08), lineWidth: 1)
                .padding(size * 0.08)

            VStack {
                HStack {
                    Text("⣿⣿ mardi")
                        .monoFont(max(7, size * 0.065), weight: .bold)
                        .foregroundStyle(Palette.bone3)
                    Spacer()
                    Text(moodLabel)
                        .monoFont(max(7, size * 0.06))
                        .foregroundStyle(moodColor)
                }
                Spacer()
                Text("⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒⠒")
                    .monoFont(max(7, size * 0.06))
                    .foregroundStyle(Palette.bone4)
                    .lineLimit(1)
            }
            .padding(size * 0.08)
        }
    }

    private func brailleBody(t: TimeInterval) -> some View {
        VStack(spacing: -size * 0.012) {
            ForEach(Array(glyphRows.enumerated()), id: \.offset) { index, row in
                Text(row)
                    .monoFont(size * 0.105, weight: .bold)
                    .foregroundStyle(index == accentRow ? moodColor : Palette.bone)
                    .opacity(index == accentRow ? 1 : 0.9)
            }
        }
        .tracking(size * 0.008)
        .shadow(color: moodColor.opacity(0.22), radius: size * 0.05)
        .offset(x: CGFloat(cursorOffset.width) * 0.35, y: sin(t * 1.1) * size * 0.008)
    }

    @ViewBuilder
    private func moodMark(t: TimeInterval) -> some View {
        switch mood {
        case .thinking:
            Circle()
                .trim(from: 0.05, to: 0.32)
                .stroke(Palette.cyan, style: StrokeStyle(lineWidth: max(1.5, size * 0.018), lineCap: .square))
                .rotationEffect(.radians(t * 3.8))
                .frame(width: size * 0.72, height: size * 0.72)
        case .success:
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * .pi * 2
                Text("⠿")
                    .monoFont(size * 0.08, weight: .bold)
                    .foregroundStyle(Palette.pink)
                    .offset(
                        x: cos(angle) * size * 0.38,
                        y: sin(angle) * size * 0.38
                    )
                    .opacity(0.85)
            }
        case .error:
            Text("!!")
                .monoFont(size * 0.10, weight: .bold)
                .foregroundStyle(Palette.red)
                .offset(x: size * 0.31, y: -size * 0.29)
        case .sleeping:
            Text("z")
                .monoFont(size * 0.12, weight: .bold)
                .foregroundStyle(Palette.bone2)
                .offset(x: size * 0.28, y: -size * 0.30 - CGFloat(t.truncatingRemainder(dividingBy: 1.6)) * size * 0.04)
        default:
            EmptyView()
        }
    }

    private func statusRail(t: TimeInterval) -> some View {
        HStack(spacing: size * 0.025) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(i == activeRail(t: t) ? moodColor : Palette.bone4)
                    .frame(width: size * 0.035, height: size * 0.035)
            }
        }
        .offset(y: size * 0.32)
    }

    private var glyphRows: [String] {
        switch mood {
        case .sleeping:
            return [" ⣶⣶⣶ ", "⣾⠁ ⠈⣷", "⣿ ⠒⠒ ⣿", "⣷ ⠤⠤ ⣾", " ⠿⠿⠿ "]
        case .error:
            return [" ⣶⣶⣶ ", "⣾⣉ ⣉⣷", "⣿  ⣯ ⣿", "⣷ ⠶⠶ ⣾", " ⠿⠿⠿ "]
        case .success:
            return [" ⣶⣶⣶ ", "⣾⠿ ⠿⣷", "⣿  ⣶ ⣿", "⣷ ⠿⠿ ⣾", " ⠿⠿⠿ "]
        case .selectMode:
            return [" ⣶⣶⣶ ", "⣾⠿ ⠿⣷", "⣿ ⠿⠿ ⣿", "⣷ ⣶⣶ ⣾", " ⠿⠿⠿ "]
        default:
            return [" ⣶⣶⣶ ", "⣾⠿ ⠿⣷", "⣿  ⣷ ⣿", "⣷ ⠶⠶ ⣾", " ⠿⠿⠿ "]
        }
    }

    private var accentRow: Int {
        switch mood {
        case .thinking, .listening: 2
        case .success: 3
        case .error: 1
        default: 0
        }
    }

    private var moodColor: Color {
        switch mood {
        case .thinking, .listening: Palette.cyan
        case .success: Palette.pink
        case .error: Palette.red
        case .selectMode: Palette.gold
        case .sleeping: Palette.bone3
        default: Palette.pink
        }
    }

    private var moodLabel: String {
        switch mood {
        case .idle: "idle"
        case .summoned: "summoned"
        case .listening: "listening"
        case .thinking: "thinking"
        case .success: "saved"
        case .error: "error"
        case .selectMode: "select"
        case .sleeping: "sleeping"
        }
    }

    private func activeRail(t: TimeInterval) -> Int {
        mood == .thinking || mood == .listening ? Int(t * 5).isMultiple(of: 4) ? 0 : Int(t * 5) % 4 : 0
    }

    private func popScale(t: TimeInterval) -> CGFloat {
        guard mood == .summoned else { return 1 }
        let elapsed = min(1.0, t / 0.35)
        let damp = 1.0 - exp(-6.0 * elapsed)
        let osc = cos(elapsed * .pi * 2) * exp(-3.0 * elapsed) * 0.12
        return 0.5 + CGFloat(damp) * 0.5 + CGFloat(osc)
    }

    private func bobOffset(t: TimeInterval) -> CGFloat {
        switch mood {
        case .idle, .sleeping: return CGFloat(sin(t * 1.2) * 2.0)
        case .listening: return CGFloat(sin(t * 2.4) * 1.5)
        default: return 0
        }
    }
}

#Preview("All Moods", traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        ForEach([MardiMood.idle, .summoned, .listening, .thinking, .success, .error, .selectMode, .sleeping], id: \.self) { m in
            VStack(spacing: 4) {
                MardiRobotView(mood: m, size: 96)
                Text(String(describing: m))
                    .monoFont(10)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
    .padding()
    .background(Palette.charcoal)
}
