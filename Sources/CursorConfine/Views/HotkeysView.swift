import SwiftUI
import Carbon.HIToolbox
import AppKit

struct HotkeysView: View {

    @Environment(AppState.self) private var appState
    @State private var capturingFor: HotkeyManager.Role?

    var body: some View {
        @Bindable var settings = appState.settingsStore

        VStack(alignment: .leading, spacing: 16) {
            Text("Global Hotkeys")
                .font(.title2.weight(.semibold))

            Text("These work anywhere on the system. The key combo is swallowed so it never types into another app.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(spacing: 8) {
                    hotkeyRow(label: "Toggle confinement",
                              role: .toggle,
                              hotkey: $settings.settings.toggleHotkey)
                    Divider()
                    hotkeyRow(label: "Pick window…",
                              role: .pickWindow,
                              hotkey: $settings.settings.pickWindowHotkey)
                    Divider()
                    hotkeyRow(label: "Panic release",
                              role: .panic,
                              hotkey: $settings.settings.panicHotkey)
                }
                .padding(.vertical, 4)
            }

            GroupBox("Hold-to-release modifier") {
                Picker("Modifier to hold to temporarily free the cursor", selection: $settings.settings.holdToReleaseModifier) {
                    ForEach(ModifierKey.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .background(
            HotkeyCaptureBridge(capturingFor: $capturingFor,
                                onCapture: { role, hotkey in
                                    apply(role: role, hotkey: hotkey)
                                })
        )
    }

    private func hotkeyRow(label: String, role: HotkeyManager.Role, hotkey: Binding<Hotkey>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                capturingFor = role
            } label: {
                Text(capturingFor == role ? "Press combo…" : hotkey.wrappedValue.description)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            Button {
                hotkey.wrappedValue = .unset
                appState.wireHotkeys()
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Clear hotkey")
        }
    }

    private func apply(role: HotkeyManager.Role, hotkey: Hotkey) {
        @Bindable var settings = appState.settingsStore
        switch role {
        case .toggle:     settings.settings.toggleHotkey = hotkey
        case .pickWindow: settings.settings.pickWindowHotkey = hotkey
        case .panic:      settings.settings.panicHotkey = hotkey
        }
        appState.wireHotkeys()
        capturingFor = nil
    }
}

/// Invisible NSView that hosts a local key monitor while a row is in "capture" mode.
struct HotkeyCaptureBridge: NSViewRepresentable {
    @Binding var capturingFor: HotkeyManager.Role?
    var onCapture: (HotkeyManager.Role, Hotkey) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install(in: v)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator {
        var parent: HotkeyCaptureBridge
        private var monitor: Any?

        init(parent: HotkeyCaptureBridge) {
            self.parent = parent
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        func install(in view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
                guard let self else { return ev }
                guard let role = self.parent.capturingFor else { return ev }
                // Ignore plain modifiers / no-key events.
                let keyCode = UInt32(ev.keyCode)
                let mods = Self.carbonModifiers(from: ev.modifierFlags)
                // Need at least one non-shift modifier OR a function key
                // OR escape (used by panic combo).
                let isFunctionish = (kVK_F1...kVK_F20).contains(Int(keyCode))
                if mods == 0 && !isFunctionish && keyCode != UInt32(kVK_Escape) {
                    return ev
                }
                let hk = Hotkey(keyCode: keyCode, modifiers: mods)
                self.parent.onCapture(role, hk)
                return nil // swallow the event so it doesn't type
            }
        }

        static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var m: UInt32 = 0
            if flags.contains(.command)  { m |= UInt32(cmdKey) }
            if flags.contains(.option)   { m |= UInt32(optionKey) }
            if flags.contains(.control)  { m |= UInt32(controlKey) }
            if flags.contains(.shift)    { m |= UInt32(shiftKey) }
            return m
        }
    }
}
