import SwiftUI

@main
struct MARDIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        // Main dashboard
        Window("MARDI", id: "MARDI-Dashboard") {
            DashboardContainer()
                .environmentObject(appDelegate)
                .onAppear {
                    // Inject env once boot finishes. If appDelegate.env isn't
                    // ready yet, DashboardContainer handles the loading state.
                }
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New capture") {
                    appDelegate.showMonster()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandGroup(after: .appSettings) {
                Button("Toggle quick search") {
                    appDelegate.toggleQuickSearch()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        // Menu bar extra (always visible)
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appDelegate)
        } label: {
            Image(systemName: "sparkles.square.filled.on.square")
        }
        .menuBarExtraStyle(.menu)

        // Standard preferences window
        Settings {
            SettingsContainer()
                .environmentObject(appDelegate)
        }
    }
}

// MARK: - Containers

/// Bridges AppDelegate (NSApplicationDelegate-owned AppEnvironment) into the
/// SwiftUI scene graph so views can use @EnvironmentObject cleanly.
struct DashboardContainer: View {
    @EnvironmentObject var delegate: AppDelegate

    var body: some View {
        if let env = delegate.env {
            MainWindowView()
                .environmentObject(env)
        } else {
            BootScreen()
        }
    }
}

struct SettingsContainer: View {
    @EnvironmentObject var delegate: AppDelegate

    var body: some View {
        Group {
            if let env = delegate.env {
                SettingsView()
                    .environmentObject(env)
            } else {
                Text("Booting…").monoFont(11).padding()
            }
        }
    }
}

struct BootScreen: View {
    @State private var tick: Int = 0
    private let spinnerGlyphs = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    var body: some View {
        ZStack {
            Palette.charcoal
            BrailleField(color: Palette.brailleDim, opacity: 0.35, fontSize: 12, density: 0.22)
            Scanlines(opacity: 0.07, spacing: 3)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // wordmark header
                    HStack(spacing: 8) {
                        Text("⣿⣿")
                            .monoFont(12, weight: .bold)
                            .foregroundStyle(Palette.neonMagenta)
                        Text("[MARDI]")
                            .monoFont(12, weight: .bold)
                            .tracking(3)
                            .foregroundStyle(Palette.textPrimary)
                        Text("⣿⣿")
                            .monoFont(12, weight: .bold)
                            .foregroundStyle(Palette.neonMagenta)
                    }

                    MardiFishBrailleView(mood: .thinking, size: 200)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text(spinnerGlyphs[tick % spinnerGlyphs.count])
                                .monoFont(12, weight: .bold)
                                .foregroundStyle(Palette.neonMagenta)
                            Text("initializing vault…")
                                .monoFont(10)
                                .tracking(1.5)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        BrailleDivider(color: Palette.neonMagenta.opacity(0.35))
                            .frame(maxWidth: 260)
                        Text("v0 · macOS · your data, your disk")
                            .monoFont(9)
                            .tracking(1.8)
                            .foregroundStyle(Palette.textMuted)
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .colorScheme(.dark)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                tick += 1
            }
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var delegate: AppDelegate

    var body: some View {
        Button("Open MARDI") { delegate.openDashboard() }
        Button("Summon Mardi") { delegate.showMonster() }
            .keyboardShortcut("m", modifiers: [.command, .option])
        Button("Quick search") { delegate.toggleQuickSearch() }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        Divider()
        SettingsLink {
            Text("Settings…")
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: [.command])
    }
}
