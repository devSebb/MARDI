import Foundation
import AppKit
import Combine

/// Polls `NSEvent.mouseLocation` at ~30Hz and fires a `triggered` publisher
/// when the cursor dwells inside the configured hot corner for `dwellMs`.
/// Uses NO Accessibility permission — just polling + foundation math.
@MainActor
final class HotCornerWatcher: ObservableObject {
    @Published var enabled: Bool = true
    @Published var corner: HotCornerPosition = .topRight
    @Published var dwellMs: Int = 400
    @Published var cornerSize: CGFloat = 12

    private var timer: Timer?
    private var dwellStart: Date?
    private var cooldownUntil: Date = .distantPast

    /// Emits `()` when the cursor has dwelled in the hot corner long enough.
    let triggered = PassthroughSubject<Void, Never>()

    func start() {
        stop()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        dwellStart = nil
    }

    func coolDown(for seconds: TimeInterval = 2.0) {
        cooldownUntil = Date().addingTimeInterval(seconds)
        dwellStart = nil
    }

    private func tick() {
        guard enabled else { return }
        if Date() < cooldownUntil { return }
        let loc = NSEvent.mouseLocation
        // AppKit gives screen coordinates with origin bottom-left of the main screen.

        guard inCorner(loc) else {
            dwellStart = nil
            return
        }

        if let start = dwellStart {
            if Date().timeIntervalSince(start) * 1000 >= Double(dwellMs) {
                triggered.send(())
                coolDown(for: 1.0)
            }
        } else {
            dwellStart = Date()
        }
    }

    private func inCorner(_ p: NSPoint) -> Bool {
        guard let screen = containingScreen(for: p) ?? NSScreen.main else { return false }
        let f = screen.frame
        let size = cornerSize
        switch corner {
        case .topLeft:
            return p.x <= f.minX + size && p.y >= f.maxY - size
        case .topRight:
            return p.x >= f.maxX - size && p.y >= f.maxY - size
        case .bottomLeft:
            return p.x <= f.minX + size && p.y <= f.minY + size
        case .bottomRight:
            return p.x >= f.maxX - size && p.y <= f.minY + size
        }
    }

    private func containingScreen(for point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) { return screen }
        }
        return nil
    }

    /// Compute the panel's top-left origin in screen coords when anchored to
    /// the hot corner, given the panel's size.
    func panelOrigin(for panelSize: CGSize, margin: CGFloat = 12) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else {
            return .zero
        }
        let f = screen.visibleFrame
        switch corner {
        case .topLeft:
            return NSPoint(x: f.minX + margin, y: f.maxY - panelSize.height - margin)
        case .topRight:
            return NSPoint(x: f.maxX - panelSize.width - margin, y: f.maxY - panelSize.height - margin)
        case .bottomLeft:
            return NSPoint(x: f.minX + margin, y: f.minY + margin)
        case .bottomRight:
            return NSPoint(x: f.maxX - panelSize.width - margin, y: f.minY + margin)
        }
    }
}
