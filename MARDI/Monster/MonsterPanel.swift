import AppKit
import SwiftUI

/// The floating NSPanel that hosts the monster. Non-activating (won't steal
/// focus from the foreground app), borderless, translucent, floats above
/// everything, joins every space.
final class MonsterPanel: NSPanel {
    private var hostingView: NSHostingView<AnyView>?

    init<Content: View>(rootView: Content, size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.worksWhenModal = true
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .utilityWindow

        let host = NSHostingView(rootView: AnyView(rootView))
        host.autoresizingMask = [.width, .height]
        host.frame = NSRect(origin: .zero, size: size)
        self.contentView = host
        self.hostingView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setContent<Content: View>(_ view: Content) {
        let host = NSHostingView(rootView: AnyView(view))
        host.autoresizingMask = [.width, .height]
        if let size = contentView?.frame.size {
            host.frame = NSRect(origin: .zero, size: size)
        }
        self.contentView = host
        self.hostingView = host
    }

    func showAt(origin: NSPoint, fadeIn: Bool = true) {
        self.setFrameOrigin(origin)
        if fadeIn {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                self.animator().alphaValue = 1.0
            }
        } else {
            orderFrontRegardless()
        }
    }

    func fadeOutAndClose() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1
        })
    }
}
