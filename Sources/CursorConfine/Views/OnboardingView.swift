import SwiftUI

struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    var onFinish: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            Image(systemName: "lock.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.accentColor)

            Text("Welcome to CursorConfine")
                .font(.title.weight(.bold))

            Group {
                switch step {
                case 0:
                    stepIntro
                case 1:
                    stepAccessibility
                case 2:
                    stepScreenRecording
                default:
                    stepDone
                }
            }
            .frame(maxWidth: 520)
            .multilineTextAlignment(.center)

            Spacer()

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < 3 {
                    Button(step == 2 ? "Finish" : "Continue") {
                        if step == 2 {
                            onFinish()
                        } else {
                            step += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }

    private var stepIntro: some View {
        VStack(spacing: 12) {
            Text("Pin your cursor inside a window, region, or display.")
                .font(.title3)
            Text("Built for gamers and multi-monitor users who lose focus on misclicks. Two permissions are needed — let's set them up.")
                .foregroundStyle(.secondary)
        }
    }

    private var stepAccessibility: some View {
        VStack(spacing: 12) {
            Text("Accessibility")
                .font(.title3.weight(.semibold))
            Text("Required. CursorConfine installs a system-wide mouse event tap to clamp the cursor. This is how every macOS cursor-locking tool works.")
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: appState.permissions.accessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(appState.permissions.accessibilityGranted ? .green : .orange)
                Text(appState.permissions.accessibilityGranted ? "Granted" : "Not granted")
            }
            HStack {
                Button("Prompt me") { appState.permissions.promptForAccessibility() }
                    .buttonStyle(.borderedProminent)
                Button("Open System Settings") { appState.permissions.openAccessibilityPane() }
            }
            Text("You may need to add CursorConfine to the list manually in System Settings → Privacy & Security → Accessibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stepScreenRecording: some View {
        VStack(spacing: 12) {
            Text("Screen Recording (optional)")
                .font(.title3.weight(.semibold))
            Text("Only needed for live window thumbnails in the picker. Without it, you'll still see window titles and app icons.")
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: appState.permissions.screenRecordingGranted ? "checkmark.seal.fill" : "questionmark.circle")
                    .foregroundStyle(appState.permissions.screenRecordingGranted ? .green : .secondary)
                Text(appState.permissions.screenRecordingGranted ? "Granted" : "Optional")
            }
            HStack {
                Button("Prompt me") { appState.permissions.requestScreenRecording() }
                    .buttonStyle(.borderedProminent)
                Button("Open System Settings") { appState.permissions.openScreenRecordingPane() }
            }
        }
    }

    private var stepDone: some View {
        VStack {
            Text("You're set.")
                .font(.title3)
            Text("Open the menu bar icon to lock your cursor.")
                .foregroundStyle(.secondary)
        }
    }
}
