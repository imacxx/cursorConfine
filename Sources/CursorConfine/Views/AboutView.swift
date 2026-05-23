import SwiftUI

struct AboutView: View {

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(Color.accentColor)

            Text("CursorConfine")
                .font(.largeTitle.weight(.bold))
            Text("Lock your cursor inside a window, region, or display.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Mouse events are clamped via a CGEventTap, so the cursor can touch — but never cross — the chosen rect.", systemImage: "lock.shield")
                Label("Cmd-Tab always works: confinement auto-releases when the target loses focus.", systemImage: "rectangle.on.rectangle")
                Label("Panic key always frees the cursor — no way to get stuck.", systemImage: "exclamationmark.lock")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
