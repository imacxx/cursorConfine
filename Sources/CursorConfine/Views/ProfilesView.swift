import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProfilesView: View {

    @Environment(AppState.self) private var appState
    @State private var selectedID: UUID?

    var body: some View {
        let profiles = appState.profileStore.profiles
        let selected = profiles.first(where: { $0.id == selectedID })

        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(profiles) { p in
                        HStack {
                            Image(systemName: p.mode.symbolName)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(p.name).font(.body)
                                Text(p.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if p.autoActivate {
                                Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                            }
                        }
                        .tag(p.id)
                    }
                }
                .listStyle(.inset)

                HStack {
                    Button(action: addProfile) { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                    Button(action: removeSelected) { Image(systemName: "minus") }
                        .buttonStyle(.borderless)
                        .disabled(selectedID == nil)
                    Spacer()
                    Button("Pick app…", action: pickApp)
                        .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.bar)
            }
            .frame(minWidth: 240, idealWidth: 280)

            if let selected {
                ProfileDetailView(profile: Binding<Profile>(
                    get: { selected },
                    set: { newValue in appState.profileStore.update(newValue) }
                ))
                .padding(16)
            } else {
                ContentUnavailableView(
                    "No profile selected",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("Profiles auto-apply confinement when a specific app gets focus. Pick an app to get started.")
                )
            }
        }
    }

    private func addProfile() {
        let p = Profile(name: "New profile", bundleIdentifier: "", appName: "Unknown")
        appState.profileStore.add(p)
        selectedID = p.id
    }

    private func removeSelected() {
        if let id = selectedID {
            appState.profileStore.remove(id: id)
            selectedID = nil
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Pick an .app to create a profile for"
        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            let bid = bundle?.bundleIdentifier ?? ""
            let name = (bundle?.infoDictionary?["CFBundleName"] as? String) ??
                       url.deletingPathExtension().lastPathComponent
            let p = Profile(name: name, bundleIdentifier: bid, appName: name, mode: .focusedWindow)
            appState.profileStore.add(p)
            selectedID = p.id
        }
    }
}

struct ProfileDetailView: View {

    @Binding var profile: Profile

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $profile.name)
                TextField("App name", text: $profile.appName)
                TextField("Bundle identifier", text: $profile.bundleIdentifier)
            }
            Section("Behavior") {
                Picker("Mode", selection: $profile.mode) {
                    ForEach(ConfinementMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                    }
                }
                if profile.mode == .window {
                    TextField("Window title contains…", text: $profile.windowTitleHint, prompt: Text("optional"))
                }
                Toggle("Auto-activate when this app is focused", isOn: $profile.autoActivate)
                Toggle("Enable overlay for this profile", isOn: $profile.enableOverlay)
            }
        }
        .formStyle(.grouped)
    }
}
