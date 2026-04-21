import SwiftUI

/// CRT-terminal-style speech bubble with typewriter text reveal. Tail points at the robot.
struct SpeechBubbleView: View {
    let text: String
    var tailSide: Edge = .leading   // tail on the left side, pointing at robot
    var revealSpeed: Double = 0.025 // seconds per character

    @State private var revealed: Int = 0
    @State private var lastText: String = ""
    @State private var blink: Bool = false

    private var displayed: String {
        let end = min(revealed, text.count)
        return String(text.prefix(end))
    }

    private var isRevealing: Bool { revealed < text.count }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if tailSide == .leading {
                tailView
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("> ")
                        .monoFont(12, weight: .bold)
                        .foregroundStyle(Palette.phosphorDim)
                    Text(displayed)
                        .monoFont(12)
                        .foregroundStyle(Palette.phosphor)
                    if blink {
                        Rectangle()
                            .fill(Palette.phosphor)
                            .frame(width: 7, height: 12)
                            .opacity(isRevealing ? 0.9 : (blink ? 0.9 : 0.2))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.bubbleBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Palette.phosphorDim, lineWidth: 1.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.clear)
                    .scanlines(opacity: 0.08, spacing: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 8)
                    )
            )
            .crtGlow(color: Palette.phosphor, radius: 5, intensity: 0.18)

            if tailSide == .trailing {
                tailView
            }
        }
        .onAppear { startReveal() }
        .onTapGesture { revealed = text.count }
        .onChange(of: text) { _, newValue in
            if newValue != lastText {
                lastText = newValue
                revealed = 0
                startReveal()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                blink.toggle()
            }
        }
    }

    private var tailView: some View {
        Triangle(pointing: tailSide == .leading ? .left : .right)
            .fill(Palette.bubbleBg)
            .overlay(
                Triangle(pointing: tailSide == .leading ? .left : .right)
                    .stroke(Palette.phosphorDim, lineWidth: 1.5)
            )
            .frame(width: 10, height: 14)
    }

    private func startReveal() {
        lastText = text
        Task {
            let total = text.count
            guard total > 0 else { return }
            while revealed < total {
                try? await Task.sleep(nanoseconds: UInt64(revealSpeed * 1_000_000_000))
                await MainActor.run {
                    revealed = min(revealed + 1, total)
                }
            }
        }
    }
}

private struct Triangle: Shape {
    enum Direction { case left, right }
    var pointing: Direction

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch pointing {
        case .left:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 16) {
        SpeechBubbleView(text: "Hi. I'm Mardi. I'll remember things for you.")
        SpeechBubbleView(text: "Got it. Saved to Signatures.")
    }
    .padding()
    .background(Palette.charcoal)
}
