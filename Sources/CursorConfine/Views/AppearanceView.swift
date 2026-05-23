import SwiftUI

struct AppearanceView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settingsStore

        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance & Feedback")
                .font(.title2.weight(.semibold))

            GroupBox("Dim overlay") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Darken the screen outside the confinement area",
                           isOn: $settings.settings.dimOverlayEnabled)
                    HStack {
                        Text("Opacity")
                        Slider(value: $settings.settings.dimOverlayOpacity, in: 0.1...0.95)
                            .disabled(!settings.settings.dimOverlayEnabled)
                        Text("\(Int(settings.settings.dimOverlayOpacity * 100))%")
                            .frame(width: 44, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Border") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Draw a colored border around the confinement area",
                           isOn: $settings.settings.borderOverlayEnabled)
                    HStack {
                        ColorPicker("Color",
                                    selection: Binding(
                                        get: { settings.settings.borderColor.swiftUIColor },
                                        set: { newColor in
                                            settings.settings.borderColor = colorRGBA(from: newColor)
                                        }
                                    ),
                                    supportsOpacity: true)
                            .disabled(!settings.settings.borderOverlayEnabled)
                        Spacer()
                        Stepper("Width: \(Int(settings.settings.borderWidth)) pt",
                                value: $settings.settings.borderWidth,
                                in: 1...10,
                                step: 1)
                            .disabled(!settings.settings.borderOverlayEnabled)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Sounds & notifications") {
                VStack(alignment: .leading) {
                    Toggle("Play sound when locking", isOn: $settings.settings.soundOnLock)
                    Toggle("Play sound when releasing", isOn: $settings.settings.soundOnUnlock)
                    Toggle("Notify on lock",   isOn: $settings.settings.notifyOnLock)
                    Toggle("Notify on release",isOn: $settings.settings.notifyOnUnlock)
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
    }

    private func colorRGBA(from color: Color) -> ColorRGBA {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .blue
        return ColorRGBA(red: Double(ns.redComponent),
                         green: Double(ns.greenComponent),
                         blue: Double(ns.blueComponent),
                         alpha: Double(ns.alphaComponent))
    }
}
