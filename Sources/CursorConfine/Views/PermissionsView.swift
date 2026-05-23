import SwiftUI

struct PermissionsView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.semibold))

            row(
                title: "Accessibility",
                subtitle: "Required. CursorConfine installs a system-wide mouse event tap to clamp the cursor.",
                granted: appState.permissions.accessibilityGranted,
                primaryTitle: "Open System Settings",
                primaryAction: { appState.permissions.openAccessibilityPane() },
                secondaryTitle: "Prompt",
                secondaryAction: { appState.permissions.promptForAccessibility() }
            )

            row(
                title: "Screen Recording",
                subtitle: "Optional. Used only for live window thumbnails in the picker. Without it, you'll still see app names.",
                granted: appState.permissions.screenRecordingGranted,
                primaryTitle: "Open System Settings",
                primaryAction: { appState.permissions.openScreenRecordingPane() },
                secondaryTitle: "Prompt",
                secondaryAction: { appState.permissions.requestScreenRecording() }
            )

            HStack {
                Spacer()
                Button("Re-check") {
                    appState.permissions.refresh()
                }
                .controlSize(.regular)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func row(title: String,
                     subtitle: String,
                     granted: Bool,
                     primaryTitle: String,
                     primaryAction: @escaping () -> Void,
                     secondaryTitle: String,
                     secondaryAction: @escaping () -> Void) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(granted ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.headline)
                        Text(granted ? "Granted" : "Not granted")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(granted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundStyle(granted ? .green : .orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button(primaryTitle, action: primaryAction).buttonStyle(.borderedProminent)
                        Button(secondaryTitle, action: secondaryAction).buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }
}
