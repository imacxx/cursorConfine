import SwiftUI

/// The dropdown content shown when the user clicks the menu-bar icon.
struct MenuBarContent: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let status = appState.engagementStatus

        Text(status)
            .font(.system(.body, weight: .semibold))

        Divider()

        Button(appState.isArmed ? "Release cursor" : "Lock cursor") {
            appState.toggleArmed()
        }
        .keyboardShortcut(.defaultAction)

        Button("Panic release") {
            appState.panicRelease()
        }

        Divider()

        Menu("Mode") {
            ForEach(ConfinementMode.allCases) { mode in
                Button {
                    var t = appState.currentTarget
                    t.mode = mode
                    appState.currentTarget = t
                } label: {
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .labelStyle(.titleAndIcon)
                }
                .disabled(appState.currentTarget.mode == mode)
            }
        }

        Button("Pick window…") {
            appState.openWindowPicker()
        }

        Button("Draw region…") {
            NotificationCenter.default.post(name: .cursorConfineStartRegionPicker, object: nil)
        }

        Divider()

        if appState.profileStore.profiles.isEmpty {
            Text("No profiles")
                .foregroundStyle(.secondary)
        } else {
            Menu("Profiles") {
                ForEach(appState.profileStore.profiles) { profile in
                    Button(profile.name) {
                        let windows = appState.windowService.enumerate()
                        appState.currentTarget = profile.toTarget(matching: windows)
                        appState.arm()
                    }
                }
            }
        }

        Divider()

        Button("Open CursorConfine…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Button("Quit CursorConfine") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
