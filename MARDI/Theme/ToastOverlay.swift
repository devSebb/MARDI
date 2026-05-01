import SwiftUI

/// Bottom-anchored pixel toast. Observes `env.lastToast`; when a non-nil value
/// arrives, renders the toast for ~1.6s then clears the source so the next
/// emission re-triggers the animation.
struct ToastOverlay: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var visible: Bool = false
    @State private var current: String? = nil

    var body: some View {
        VStack {
            Spacer()
            if let current, visible {
                toast(current)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.18), value: visible)
        .onChange(of: env.lastToast) { _, new in
            guard let new, !new.isEmpty else { return }
            present(new)
        }
    }

    private func toast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Text("⣿⣿")
                .monoFont(11, weight: .bold)
                .foregroundStyle(Palette.neonMagenta)
            Text(message.uppercased())
                .monoFont(10, weight: .bold)
                .tracking(1.4)
                .foregroundStyle(Palette.textPrimary)
            Text("⣿⣿")
                .monoFont(11, weight: .bold)
                .foregroundStyle(Palette.neonMagenta)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.45, fontSize: 10, density: 0.32)
                Scanlines(opacity: 0.10, spacing: 3)
            }
        )
        .pixelBorder(Palette.neonMagenta, width: 1.5, lit: true)
        .shadow(color: Palette.neonMagenta.opacity(0.35), radius: 8)
    }

    private func present(_ message: String) {
        current = message
        visible = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            visible = false
            try? await Task.sleep(nanoseconds: 220_000_000)
            // Only clear if no newer toast was queued in the meantime.
            if current == message {
                current = nil
                env.lastToast = nil
            }
        }
    }
}
