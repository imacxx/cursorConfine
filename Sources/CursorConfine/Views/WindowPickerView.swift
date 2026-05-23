import SwiftUI
import AppKit

/// Standalone NSWindowController for the Discord-style picker so it isn't
/// constrained by the SwiftUI Window scene's lifecycle.
@MainActor
final class WindowPickerWindowController: NSWindowController {
    init(appState: AppState) {
        let hosting = NSHostingController(rootView: WindowPickerView()
            .environment(appState)
            .frame(minWidth: 640, minHeight: 480))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Pick a window"
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.setContentSize(NSSize(width: 720, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        super.init(window: win)
    }
    required init?(coder: NSCoder) { fatalError("not implemented") }
}

struct WindowPickerView: View {

    @Environment(AppState.self) private var appState
    @State private var windows: [WindowInfo] = []
    @State private var searchText = ""
    @State private var thumbVersion = 0  // forces grid to re-evaluate thumbnails

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps or window titles", text: $searchText)
                    .textFieldStyle(.plain)
                Button("Refresh") {
                    refresh(forceThumbnails: true)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(.bar)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { window in
                        WindowTileView(window: window, thumbVersion: thumbVersion)
                            .environment(appState)
                            .onTapGesture {
                                appState.selectWindow(window)
                                appState.arm()
                                NSApp.keyWindow?.close()
                            }
                    }
                }
                .padding(16)
            }

            if !appState.permissions.screenRecordingGranted {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Screen Recording isn't granted — showing app icons instead of thumbnails.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        appState.permissions.openScreenRecordingPane()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(.bar)
            }
        }
        .onAppear { refresh(forceThumbnails: true) }
    }

    private var filtered: [WindowInfo] {
        let q = searchText.lowercased()
        if q.isEmpty { return windows }
        return windows.filter {
            $0.appName.lowercased().contains(q) || $0.title.lowercased().contains(q)
        }
    }

    private func refresh(forceThumbnails: Bool) {
        windows = appState.windowService.enumerate()
        if forceThumbnails {
            appState.thumbnailService.clearCache()
            for w in windows {
                appState.thumbnailService.requestRefresh(windowID: w.id) { _ in
                    thumbVersion &+= 1
                }
            }
        }
    }
}

struct WindowTileView: View {

    @Environment(AppState.self) private var appState
    let window: WindowInfo
    let thumbVersion: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                if let img = appState.thumbnailService.cached(window.id) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(6)
                        .padding(6)
                } else {
                    VStack(spacing: 8) {
                        if let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: "macwindow")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView().controlSize(.small)
                            .opacity(appState.permissions.screenRecordingGranted ? 1 : 0)
                    }
                }
            }
            .frame(height: 130)
            .id(thumbVersion)  // re-render when thumbnail arrives

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(window.appName).font(.caption.bold()).lineLimit(1)
                    if window.layer >= 100 {
                        // Layer ≥100 is e.g. kCGOverlayWindowLevel/CGScreenSaverWindowLevel.
                        // Fullscreen games like League of Legends sit at layer
                        // 1000 — call it out so the user picks the right one.
                        Text("FULLSCREEN")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.25))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .help("This window is at a fullscreen-game layer (\(window.layer))")
                    }
                    if !window.isOnScreen {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .help("Not currently on screen — possibly fullscreen on another Space")
                    }
                }
                HStack(spacing: 6) {
                    Text(window.title.isEmpty ? "Untitled window" : window.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(Int(window.bounds.width))×\(Int(window.bounds.height))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .help("Window dimensions in points")
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .help("\(window.appName) — \(window.title)")
    }

    private var appIcon: NSImage? {
        NSRunningApplication(processIdentifier: window.pid)?.icon
    }
}
