import SwiftUI

struct GeneralView: View {

    @Environment(AppState.self) private var appState
    @State private var launchAtLoginError: String?

    var body: some View {
        @Bindable var settings = appState.settingsStore

        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2.weight(.semibold))

            GroupBox("Startup") {
                VStack(alignment: .leading) {
                    Toggle("Launch at login",
                           isOn: Binding(
                               get: { settings.settings.startAtLogin },
                               set: { newVal in
                                   settings.settings.startAtLogin = newVal
                                   do {
                                       try appState.launchAtLogin.setEnabled(newVal)
                                       launchAtLoginError = nil
                                   } catch {
                                       launchAtLoginError = error.localizedDescription
                                   }
                               }
                           ))
                    if let err = launchAtLoginError {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                    Toggle("Automatically arm confinement on launch",
                           isOn: $settings.settings.autoStartConfinementOnLaunch)
                }
                .padding(.vertical, 4)
            }

            GroupBox("System events") {
                Toggle("Pause confinement when screen locks or screen-saver runs",
                       isOn: $settings.settings.pauseWhenScreenSaverActive)
                    .padding(.vertical, 4)
            }

            Spacer()
        }
    }
}
