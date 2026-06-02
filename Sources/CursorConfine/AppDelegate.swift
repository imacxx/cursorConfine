import AppKit
import SwiftUI
import Observation

/// App-lifecycle owner. `appState` is constructed eagerly in `init` so the
/// SwiftUI MenuBarExtra label can render the real state on the first body
/// evaluation; lazy/Optional construction would never propagate to SwiftUI
/// since AppDelegate isn't an `ObservableObject` and a plain `var` change
/// wouldn't invalidate the scene.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let appState: AppState

    // Overlay windows are managed here (they need NSPanel-level control that
    // SwiftUI scenes don't make easy).
    private var dimOverlayController: DimOverlayController?
    private var borderOverlayController: BorderOverlayController?
    private var clickShieldOverlayController: ClickShieldOverlayController?
    private var regionPickerController: RegionPickerController?
    private var windowPickerController: WindowPickerWindowController?

    override init() {
        self.appState = AppState()   // lightweight: no side effects, no observers
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular activation policy = shows in Dock + Cmd-Tab. The user wants
        // a visible "is it running" indicator, and the menu-bar icon stays
        // there alongside.
        NSApp.setActivationPolicy(.regular)

        let state = appState
        state.bootstrap()

        // Overlays.
        let dim = DimOverlayController()
        let border = BorderOverlayController()
        let shield = ClickShieldOverlayController()
        self.dimOverlayController = dim
        self.borderOverlayController = border
        self.clickShieldOverlayController = shield
        wireOverlayUpdates(state: state, dim: dim, border: border, shield: shield)

        // SwiftUI-window-friendly intent bus.
        NotificationCenter.default.addObserver(forName: .cursorConfineOpenWindowPicker,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.openWindowPicker() }
        }
        NotificationCenter.default.addObserver(forName: .cursorConfineStartRegionPicker,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.startRegionPicker() }
        }
        NotificationCenter.default.addObserver(forName: .cursorConfineOpenMain,
                                               object: nil, queue: .main) { _ in
            NSApp.activate(ignoringOtherApps: true)
            // Window scene "main" — re-show via openWindow not available here;
            // we rely on the SwiftUI MenuBarExtra "Open Main Window" item.
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdown()
    }

    /// Clicking the Dock icon when no windows are open should open the main
    /// window. Without this, Dock clicks are no-ops once the user closes the
    /// last window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .cursorConfineOpenMain, object: nil)
        }
        return true
    }

    // MARK: - Overlays
    // Re-render overlays whenever the engine's active rect changes by polling
    // every frame via DisplayLink-ish timer. We use a 60Hz timer for simplicity.

    private var overlayTimer: Timer?

    private func wireOverlayUpdates(
        state: AppState,
        dim: DimOverlayController,
        border: BorderOverlayController,
        shield: ClickShieldOverlayController
    ) {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak state, weak dim, weak border, weak shield] _ in
            Task { @MainActor in
                guard let state, let dim, let border, let shield else { return }
                let s = state.settingsStore.settings
                let rect = state.overlayRect

                if let shieldRect = state.clickShieldRect {
                    shield.show(protectedRect: shieldRect)
                } else {
                    shield.hide()
                }

                if s.dimOverlayEnabled, let rect {
                    dim.show(rect: rect, opacity: s.dimOverlayOpacity)
                } else {
                    dim.hide()
                }

                if s.borderOverlayEnabled, let rect {
                    border.show(rect: rect, color: s.borderColor.swiftUIColor, width: CGFloat(s.borderWidth))
                } else {
                    border.hide()
                }
            }
        }
    }

    // MARK: - Window picker

    func openWindowPicker() {
        if windowPickerController == nil {
            windowPickerController = WindowPickerWindowController(appState: appState)
        }
        windowPickerController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Region picker

    func startRegionPicker() {
        let state = appState
        let controller = RegionPickerController { [weak self] rect in
            guard let rect else { return }
            state.setRectangleTarget(rect)
            state.arm()
            self?.regionPickerController = nil
        }
        regionPickerController = controller
        controller.begin()
    }
}
