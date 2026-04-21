import AppKit
import SwiftUI

/// Spotlight-style translucent panel. Key-capturing (unlike the monster,
/// which stays non-activating) so the user can type the moment it appears.
final class QuickSearchPanel: NSPanel {
    init<Content: View>(rootView: Content, size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.hidesOnDeactivate = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let host = NSHostingView(rootView: rootView)
        host.autoresizingMask = [.width, .height]
        host.frame = NSRect(origin: .zero, size: size)
        self.contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func centerOnMainScreen() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let target = NSRect(
            x: f.midX - frame.width / 2,
            y: f.midY + 80,
            width: frame.width,
            height: frame.height
        )
        setFrame(target, display: false)
    }

    func showAndFocus() {
        centerOnMainScreen()
        alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        orderFrontRegardless()
        makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 1
        }
    }
}
