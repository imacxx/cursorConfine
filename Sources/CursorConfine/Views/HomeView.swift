import SwiftUI

struct HomeView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settingsStore

        VStack(alignment: .leading, spacing: 20) {
            statusHeader

            GroupBox("Confinement mode") {
                modeSelector
                    .padding(.vertical, 6)
            }

            GroupBox("Target") {
                targetEditor
                    .padding(.vertical, 6)
            }

            GroupBox("Edge inset") {
                edgeInset
                    .padding(.vertical, 6)
            }

            Spacer()
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(appState.engine.isConfining ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.18))
                    .frame(width: 72, height: 72)
                Image(systemName: appState.engine.isConfining ? "lock.fill" : (appState.isArmed ? "lock.open" : "lock.slash"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(appState.engine.isConfining ? Color.accentColor : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.engagementStatus)
                    .font(.title3.weight(.semibold))
                Text(appState.currentTarget.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(appState.isArmed ? "Release" : "Lock cursor") {
                    appState.toggleArmed()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(appState.isArmed ? .red : .accentColor)
                .keyboardShortcut(.defaultAction)

                Button("Panic release") {
                    appState.panicRelease()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var modeSelector: some View {
        @Bindable var settings = appState.settingsStore
        Picker("Mode", selection: Binding(
            get: { appState.currentTarget.mode },
            set: { newMode in
                var t = appState.currentTarget
                t.mode = newMode
                appState.currentTarget = t
            }
        )) {
            ForEach(ConfinementMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private var targetEditor: some View {
        switch appState.currentTarget.mode {
        case .window:
            HStack {
                if let sel = appState.currentTarget.windowSelection {
                    VStack(alignment: .leading) {
                        Text(sel.appName).font(.headline)
                        Text(sel.windowTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("No window chosen").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Pick window…") {
                    appState.openWindowPicker()
                }
                .buttonStyle(.borderedProminent)
            }
        case .focusedWindow:
            HStack {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text("Follow active window").font(.headline)
                    Text("CursorConfine will lock the cursor to whichever window currently has focus.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        case .rectangle:
            HStack {
                if let rect = appState.currentTarget.rectangle {
                    VStack(alignment: .leading) {
                        Text("Custom region").font(.headline)
                        Text("\(Int(rect.width))×\(Int(rect.height)) at (\(Int(rect.x)), \(Int(rect.y)))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No region drawn yet").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Draw region…") {
                    NotificationCenter.default.post(name: .cursorConfineStartRegionPicker, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        case .display:
            displayPicker
        }
    }

    private var displayPicker: some View {
        let displays = appState.displayService.enumerate()
        return Picker("Display", selection: Binding<String>(
            get: { appState.currentTarget.displayUUID ?? "" },
            set: { uuid in
                var t = appState.currentTarget
                t.displayUUID = uuid.isEmpty ? nil : uuid
                appState.currentTarget = t
            }
        )) {
            Text("None").tag("")
            ForEach(displays) { display in
                Text("\(display.name) (\(Int(display.boundsCG.width))×\(Int(display.boundsCG.height)))")
                    .tag(display.uuid)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    @ViewBuilder
    private var edgeInset: some View {
        @Bindable var settings = appState.settingsStore
        HStack {
            Text("Inset")
            Slider(value: Binding(
                get: { settings.settings.edgeInset },
                set: {
                    settings.settings.edgeInset = $0
                    appState.recomputeEngagement(reason: "inset")
                }
            ), in: 0...50, step: 1)
            Text("\(Int(settings.settings.edgeInset)) pt")
                .frame(width: 60, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
