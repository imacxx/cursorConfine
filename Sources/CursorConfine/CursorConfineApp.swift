import SwiftUI
import AppKit

@main
struct CursorConfineApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Menu-bar entry point. Icon reflects current state.
        MenuBarExtra {
            MenuBarContent()
                .environment(delegate.appState)
        } label: {
            MenuBarLabel(appState: delegate.appState)
        }
        .menuBarExtraStyle(.menu)

        // Main settings/control window. WindowGroup auto-presents one window
        // on launch (so the Dock-icon click reveals UI immediately), and the
        // CommandGroup(replacing: .newItem) {} below disables Cmd-N so the user
        // can't accidentally create extra copies.
        WindowGroup("CursorConfine", id: "main") {
            MainWindowView()
                .environment(delegate.appState)
                .frame(minWidth: 720, minHeight: 520)
                .background(MainWindowReopener())
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Hidden helper that lets AppDelegate ask SwiftUI to (re-)open the main
/// window when the user clicks the Dock icon and no window exists. Lives in
/// the WindowGroup scene so the openWindow environment is in scope.
private struct MainWindowReopener: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .cursorConfineOpenMain)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
    }
}

/// The menu-bar icon: reflects engine state (locked / standby / off / panic).
struct MenuBarLabel: View {
    let appState: AppState

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel(label)
    }

    private var symbolName: String {
        if !appState.engine.isTapInstalled { return "exclamationmark.triangle.fill" }
        if appState.isPanicReleased        { return "exclamationmark.lock" }
        if appState.engine.isConfining     { return "lock.fill" }
        if appState.isArmed                { return "lock.open" }
        return "lock.slash"
    }

    private var label: String {
        if !appState.engine.isTapInstalled { return "CursorConfine: Accessibility not granted" }
        if appState.isPanicReleased        { return "CursorConfine: panic-released" }
        if appState.engine.isConfining     { return "CursorConfine: locked" }
        if appState.isArmed                { return "CursorConfine: armed (standby)" }
        return "CursorConfine: off"
    }
}
