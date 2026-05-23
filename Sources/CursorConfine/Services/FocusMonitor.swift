import Foundation
import AppKit
import Observation

/// Watches frontmost-app changes (cheap, event-driven) and polls every 0.5s for
/// frontmost-window changes within the same app (CGWindowList — also cheap).
@MainActor
@Observable
final class FocusMonitor {

    /// The PID of the frontmost application (NSWorkspace).
    private(set) var frontmostPID: pid_t?
    /// The bundle identifier of the frontmost application.
    private(set) var frontmostBundleID: String?
    /// The frontmost CGWindowID belonging to the frontmost app, if any.
    private(set) var frontmostWindowID: CGWindowID?

    var onChange: (@MainActor () -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private let windowService: WindowService

    init(windowService: WindowService) {
        self.windowService = windowService
    }

    func start() {
        stop()
        let nc = NSWorkspace.shared.notificationCenter
        let activate = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                      object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let deactivate = nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observers = [activate, deactivate]

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        refresh()
    }

    func stop() {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let app = NSWorkspace.shared.frontmostApplication
        let newPID = app?.processIdentifier
        let newBundle = app?.bundleIdentifier

        var changed = false
        if newPID != frontmostPID {
            frontmostPID = newPID
            changed = true
        }
        if newBundle != frontmostBundleID {
            frontmostBundleID = newBundle
            changed = true
        }

        // Window ID is more volatile (e.g., focus jumps between two windows of
        // the same app), so always recompute it.
        let candidate = windowService.frontmostWindow()
        let newWindowID = candidate?.id
        if newWindowID != frontmostWindowID {
            frontmostWindowID = newWindowID
            changed = true
        }

        if changed {
            onChange?()
        }
    }
}
