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
            VStack(spacing: 12) {
                MardiFishView(mood: .thinking, size: 128)
                Text("Booting Mardi…").monoFont(11).foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.charcoal)
            .colorScheme(.dark)
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
