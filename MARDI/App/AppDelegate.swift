import AppKit
import SwiftUI
import Combine

/// Coordinates the non-SwiftUI surfaces: the monster NSPanel, the hot-corner
/// watcher, the global hotkey, and the quick-search NSPanel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var env: AppEnvironment?
    private var monsterPanel: MonsterPanel?
    private var quickSearchPanel: QuickSearchPanel?
    private var monsterVM: MonsterViewModel?

    let hotCorner = HotCornerWatcher()
    let hotkey = GlobalHotkey()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Task { @MainActor in
            env = await AppEnvironment.boot()
            guard let env else { return }
            self.monsterVM = MonsterViewModel(env: env)
            wireHotCorner(env: env)
            wireHotkey(env: env)
        }
    }

    // MARK: - Hot corner

    private func wireHotCorner(env: AppEnvironment) {
        hotCorner.corner = env.settings.hotCorner
        hotCorner.dwellMs = env.settings.dwellMs

        env.settings.$hotCorner.sink { [weak self] new in
            self?.hotCorner.corner = new
        }.store(in: &cancellables)
        env.settings.$dwellMs.sink { [weak self] new in
            self?.hotCorner.dwellMs = new
        }.store(in: &cancellables)

        hotCorner.triggered
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.toggleMonster() }
            .store(in: &cancellables)

        hotCorner.start()
    }

    func toggleMonster() {
        if let panel = monsterPanel, panel.isVisible {
            panel.fadeOutAndClose()
            return
        }
        showMonster()
    }

    func showMonster() {
        guard let env, let vm = monsterVM else { return }
        let size = CGSize(width: 360, height: 380)

        let view = MonsterView(
            vm: vm,
            onOpenDashboard: { [weak self] in
                self?.openDashboard()
                self?.monsterPanel?.fadeOutAndClose()
            },
            onDismiss: { [weak self] in self?.monsterPanel?.fadeOutAndClose() }
        )
        .environmentObject(env)

        let panel = MonsterPanel(rootView: view, size: size)
        monsterPanel = panel
        let origin = hotCorner.panelOrigin(for: size)
        panel.showAt(origin: origin, fadeIn: true)
    }

    func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.identifier?.rawValue == "MARDI-Dashboard" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Fall back to menu command that opens the main window.
        if let sel = NSSelectorFromString("newWindowForTab:") as Selector? {
            NSApp.sendAction(sel, to: nil, from: nil)
        }
    }

    // MARK: - Global hotkey ⌘⇧M

    private func wireHotkey(env: AppEnvironment) {
        let combo = GlobalHotkey.cmdShiftM()
        hotkey.onFire = { [weak self] in self?.toggleQuickSearch() }
        hotkey.register(keyCode: combo.key, modifiers: combo.mods)
    }

    func toggleQuickSearch() {
        if let p = quickSearchPanel, p.isVisible {
            p.orderOut(nil)
            quickSearchPanel = nil
            return
        }
        guard let env else { return }
        let size = CGSize(width: 560, height: 380)
        let view = QuickSearchView(
            onClose: { [weak self] in
                self?.quickSearchPanel?.orderOut(nil)
                self?.quickSearchPanel = nil
            },
            onOpenInDashboard: { [weak self] _ in
                self?.openDashboard()
                self?.quickSearchPanel?.orderOut(nil)
                self?.quickSearchPanel = nil
            }
        )
        .environmentObject(env)

        let panel = QuickSearchPanel(rootView: view, size: size)
        quickSearchPanel = panel
        panel.showAndFocus()
    }
}
