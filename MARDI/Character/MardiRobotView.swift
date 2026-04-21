import SwiftUI

/// Procedurally-rendered Mardi robot. All animation driven by `mood` + time.
/// Designed to render crisply at ~96–160pt. Uses SwiftUI `Canvas` for the chassis
/// and overlays for animated extras (spinner, particles, ZZZ).
struct MardiRobotView: View {
    var mood: MardiMood
    var size: CGFloat = 128
    var cursorOffset: CGSize = .zero   // subtle pupil tracking toward cursor

    @State private var startDate = Date()
    @State private var blinkPhase: Double = 0
    @State private var particleSeed: Int = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            ZStack {
                body(t: t)
                spinnerOverlay(t: t)
                particleOverlay(t: t)
                sleepingOverlay(t: t)
            }
            .frame(width: size, height: size)
            .compositingGroup()
            .scaleEffect(popScale(t: t))
            .offset(y: bobOffset(t: t))
        }
        .onChange(of: mood) { _, newValue in
            if newValue == .success {
                particleSeed = Int.random(in: 0...9999)
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func body(t: TimeInterval) -> some View {
        Canvas { ctx, canvasSize in
            let W = canvasSize.width
            let H = canvasSize.height

            // Drop shadow underneath
            let shadowRect = CGRect(x: W * 0.15, y: H * 0.90, width: W * 0.70, height: H * 0.06)
            ctx.fill(
                Path(ellipseIn: shadowRect),
                with: .color(.black.opacity(0.35))
            )

            // Chassis (body) — chunky rounded rect with gradient
            let bodyRect = CGRect(x: W * 0.12, y: H * 0.30, width: W * 0.76, height: H * 0.60)
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: H * 0.14)

            ctx.fill(
                bodyPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0x2A303A),
                        Color(hex: 0x1A1D23),
                    ]),
                    startPoint: CGPoint(x: bodyRect.minX, y: bodyRect.minY),
                    endPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY)
                )
            )

            // Chassis border
            ctx.stroke(
                bodyPath,
                with: .color(Color(hex: 0x3B4250)),
                lineWidth: 2
            )

            // Inner highlight stripe
            let stripeRect = CGRect(x: bodyRect.minX + 4, y: bodyRect.minY + 4, width: bodyRect.width - 8, height: 2)
            ctx.fill(Path(stripeRect), with: .color(Color(hex: 0x3B4250).opacity(0.6)))

            // Face plate (inner darker area where eyes live)
            let faceRect = CGRect(
                x: W * 0.22, y: H * 0.38,
                width: W * 0.56, height: H * 0.32
            )
            let facePath = Path(roundedRect: faceRect, cornerRadius: H * 0.08)
            ctx.fill(facePath, with: .color(Color(hex: 0x0B0D10)))
            ctx.stroke(facePath, with: .color(Color(hex: 0x2C313A)), lineWidth: 1.5)

            // Speaker grille mouth
            let mouthTop = H * 0.72
            let mouthLeft = W * 0.34
            let mouthWidth = W * 0.32
            for i in 0..<3 {
                let y = mouthTop + CGFloat(i) * (H * 0.022)
                let lineRect = CGRect(x: mouthLeft, y: y, width: mouthWidth, height: H * 0.010)
                ctx.fill(Path(roundedRect: lineRect, cornerRadius: 1), with: .color(Color(hex: 0x2C313A)))
            }

            // Antenna — with rotation when thinking
            let antennaBaseX = W * 0.50
            let antennaBaseY = H * 0.30
            let antennaAngle = (mood == .thinking) ? (t * 2.0) : 0
            let antennaLen: CGFloat = H * 0.20
            let tipX = antennaBaseX + CGFloat(sin(antennaAngle)) * (antennaLen * 0.25)
            let tipY = antennaBaseY - antennaLen + CGFloat(cos(antennaAngle)) * (antennaLen * 0.05)

            var antennaPath = Path()
            antennaPath.move(to: CGPoint(x: antennaBaseX, y: antennaBaseY))
            antennaPath.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.stroke(antennaPath, with: .color(Color(hex: 0x5C6370)), lineWidth: 2)

            // Antenna tip — phosphor when idle/summoned/listening; amber when thinking; rust on error
            let tipColor: Color = {
                switch mood {
                case .error: return Palette.rust
                case .thinking: return Palette.amber
                case .success: return Palette.phosphor
                default: return Palette.phosphor
                }
            }()
            let tipPulse = 1.0 + 0.25 * sin(t * 2.5)
            let tipRadius: CGFloat = (mood == .listening ? 3.5 : 3.0) * tipPulse
            let tipRect = CGRect(
                x: tipX - tipRadius, y: tipY - tipRadius,
                width: tipRadius * 2, height: tipRadius * 2
            )
            ctx.fill(Path(ellipseIn: tipRect), with: .color(tipColor))
            // tip glow
            ctx.fill(
                Path(ellipseIn: tipRect.insetBy(dx: -3, dy: -3)),
                with: .color(tipColor.opacity(0.25))
            )

            // Eyes
            drawEyes(ctx: &ctx, W: W, H: H, t: t)

            // Side bolts (decorative)
            let boltY = H * 0.50
            for x in [W * 0.14, W * 0.82] {
                let r: CGFloat = 2.5
                let boltRect = CGRect(x: x - r, y: boltY - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: boltRect), with: .color(Color(hex: 0x3B4250)))
            }
        }
        .drawingGroup()
    }

    private func drawEyes(ctx: inout GraphicsContext, W: CGFloat, H: CGFloat, t: TimeInterval) {
        let eyeY = H * 0.52
        let eyeRadius: CGFloat = W * 0.06
        let leftX = W * 0.36
        let rightX = W * 0.64

        // Blink math: a short blink every ~3-5 seconds, triggered by a smooth cosine pulse
        let period = 4.0
        let phase = t.truncatingRemainder(dividingBy: period) / period
        let blink: Double = phase > 0.96 ? sin((phase - 0.96) / 0.04 * .pi) : 0
        let eyeHScale: CGFloat = 1.0 - CGFloat(blink) * 0.9

        // Success = happy squint (horizontal ovals)
        let squintScale: CGFloat = (mood == .success) ? 0.3 : 1.0
        let finalHScale = eyeHScale * squintScale

        let pupilOffsetX = max(-2.5, min(2.5, cursorOffset.width))
        let pupilOffsetY = max(-2.0, min(2.0, cursorOffset.height))

        for (cx, cy) in [(leftX, eyeY), (rightX, eyeY)] {
            let eyeRect = CGRect(
                x: cx - eyeRadius,
                y: cy - eyeRadius * finalHScale,
                width: eyeRadius * 2,
                height: eyeRadius * 2 * finalHScale
            )
            ctx.fill(Path(ellipseIn: eyeRect), with: .color(Palette.phosphor))
            ctx.stroke(Path(ellipseIn: eyeRect), with: .color(.black.opacity(0.5)), lineWidth: 0.8)

            // Pupil
            if mood == .selectMode {
                // Crosshair reticle
                var cross = Path()
                cross.move(to: CGPoint(x: cx - eyeRadius * 0.7, y: cy))
                cross.addLine(to: CGPoint(x: cx + eyeRadius * 0.7, y: cy))
                cross.move(to: CGPoint(x: cx, y: cy - eyeRadius * 0.7))
                cross.addLine(to: CGPoint(x: cx, y: cy + eyeRadius * 0.7))
                ctx.stroke(cross, with: .color(.black), lineWidth: 1.5)
                let dotRect = CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(.black))
            } else {
                let pupilR: CGFloat = eyeRadius * 0.35
                let pupilRect = CGRect(
                    x: cx - pupilR + pupilOffsetX,
                    y: cy - pupilR * finalHScale + pupilOffsetY,
                    width: pupilR * 2,
                    height: pupilR * 2 * finalHScale
                )
                ctx.fill(Path(ellipseIn: pupilRect), with: .color(.black))
            }
        }

        // Error: angry eyebrow slashes
        if mood == .error {
            for (cx, inward) in [(leftX, 1.0), (rightX, -1.0)] {
                var brow = Path()
                let y1 = eyeY - eyeRadius * 1.5
                let y2 = eyeY - eyeRadius * 0.7
                let x1 = cx - eyeRadius * 1.1 * inward
                let x2 = cx + eyeRadius * 0.2 * inward
                brow.move(to: CGPoint(x: x1, y: y1))
                brow.addLine(to: CGPoint(x: x2, y: y2))
                ctx.stroke(brow, with: .color(Palette.rust), lineWidth: 2.5)
            }
        }

        // Sleeping: closed eyes (short horizontal lines)
        if mood == .sleeping {
            for cx in [leftX, rightX] {
                var lid = Path()
                lid.move(to: CGPoint(x: cx - eyeRadius, y: eyeY))
                lid.addLine(to: CGPoint(x: cx + eyeRadius, y: eyeY))
                ctx.stroke(lid, with: .color(Palette.textMuted), lineWidth: 2)
            }
        }
    }

    @ViewBuilder
    private func spinnerOverlay(t: TimeInterval) -> some View {
        if mood == .thinking {
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Palette.phosphor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.radians(t * 4))
                .frame(width: size * 0.75, height: size * 0.75)
                .opacity(0.7)
        }
    }

    @ViewBuilder
    private func particleOverlay(t: TimeInterval) -> some View {
        if mood == .success {
            // Simple radial burst using a small number of procedural dots
            let particleCount = 8
            let age = min(1.0, t.truncatingRemainder(dividingBy: 1.2))
            ZStack {
                ForEach(0..<particleCount, id: \.self) { i in
                    let angle = Double(i) / Double(particleCount) * .pi * 2
                    let dist = 30.0 + age * 30.0
                    Circle()
                        .fill(Palette.phosphor)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: CGFloat(cos(angle) * dist),
                            y: CGFloat(sin(angle) * dist)
                        )
                        .opacity(1.0 - age)
                }
            }
        }
    }

    @ViewBuilder
    private func sleepingOverlay(t: TimeInterval) -> some View {
        if mood == .sleeping {
            let phase = (t.truncatingRemainder(dividingBy: 2.5)) / 2.5
            Text("z")
                .monoFont(12, weight: .bold)
                .foregroundStyle(Palette.textSecondary)
                .offset(x: size * 0.22 + CGFloat(phase * 4), y: -size * 0.35 - CGFloat(phase * 12))
                .opacity(1.0 - phase)
        }
    }

    // MARK: - Motion helpers

    private func popScale(t: TimeInterval) -> CGFloat {
        switch mood {
        case .summoned:
            // Spring overshoot from 0.3 to 1.0 in ~0.35s
            let elapsed = min(1.0, t / 0.35)
            let damp = 1.0 - exp(-6.0 * elapsed)
            let osc = cos(elapsed * .pi * 2) * exp(-3.0 * elapsed) * 0.15
            return 0.3 + CGFloat(damp) * 0.7 + CGFloat(osc)
        default:
            return 1.0
        }
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
                MardiRobotView(mood: m, size: 88)
                Text(String(describing: m))
                    .monoFont(10)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
    .padding()
    .background(Palette.charcoal)
}
