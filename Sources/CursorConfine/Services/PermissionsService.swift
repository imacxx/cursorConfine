import Foundation
import AppKit
import ApplicationServices
import Observation
@preconcurrency import CoreGraphics

/// Tracks Accessibility and Screen Recording permission status. Accessibility is
/// required to install the event tap; Screen Recording is optional and only
/// affects window thumbnails.
@MainActor
@Observable
final class PermissionsService {

    private(set) var accessibilityGranted: Bool = false {
        didSet {
            if !oldValue && accessibilityGranted {
                onAccessibilityGranted?()
            }
        }
    }
    private(set) var screenRecordingGranted: Bool = false {
        didSet {
            if !oldValue && screenRecordingGranted {
                onScreenRecordingGranted?()
            }
        }
    }

    /// Fired the first time `accessibilityGranted` transitions from false to true.
    /// Used by AppState to re-install the event tap mid-run (tap creation fails
    /// silently when Accessibility isn't granted at boot; the engine never
    /// retries on its own).
    var onAccessibilityGranted: (@MainActor () -> Void)?

    /// Fired when Screen Recording flips on (used to refresh window thumbnails).
    var onScreenRecordingGranted: (@MainActor () -> Void)?

    private var timer: Timer?

    init() {
        refresh()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = checkScreenRecording()
    }

    /// Prompts for Accessibility access by passing the standard "prompt" option.
    /// macOS shows the system dialog on first call; on later calls it's a no-op.
    func promptForAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts: CFDictionary = [key: kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        refresh()
    }

    /// Best-effort probe: a one-pixel screenshot triggers the Screen Recording
    /// permission consent dialog on first call. CGPreflightScreenCaptureAccess
    /// is the modern way to check without prompting.
    private func checkScreenRecording() -> Bool {
        if #available(macOS 11.0, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    func requestScreenRecording() {
        if #available(macOS 11.0, *) {
            _ = CGRequestScreenCaptureAccess()
        }
        refresh()
    }

    /// Open the relevant Privacy pane in System Settings.
    func openAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openScreenRecordingPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
