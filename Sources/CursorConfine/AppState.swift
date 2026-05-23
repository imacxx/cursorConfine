import Foundation
import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Observation

/// Top-level coordinator wired up to every service. Owns lifecycle and
/// translates UI intent + system events into engine actions.
@MainActor
@Observable
final class AppState {

    // MARK: - Services

    let settingsStore: SettingsStore
    let permissions: PermissionsService
    let windowService: WindowService
    let displayService: DisplayService
    let thumbnailService: WindowThumbnailService
    let focusMonitor: FocusMonitor
    let hotkeyManager: HotkeyManager
    let profileStore: ProfileStore
    let engine: ConfinementEngine
    let launchAtLogin: LaunchAtLoginService
    let soundNotification: SoundNotificationService
    let screenSaverMonitor: ScreenSaverMonitor
    let appIconAppearance: AppIconAppearance

    // MARK: - Observable state

    /// User has either explicitly armed confinement (via hotkey / menu / button)
    /// or a profile/auto-start armed it. While armed, the engine engages whenever
    /// focus + target conditions are satisfied.
    private(set) var isArmed: Bool = false

    /// True when a panic-release is in effect; overrides isArmed until cleared.
    private(set) var isPanicReleased: Bool = false

    /// The current target, defaulted from settings.lastTarget.
    var currentTarget: ConfinementTarget {
        didSet {
            settingsStore.settings.lastTarget = currentTarget
            recomputeEngagement(reason: "target changed")
        }
    }

    /// Last resolved windowID for the .window mode target (for stable tracking).
    private(set) var trackedWindowID: CGWindowID?

    /// Last resolved windowID for .focusedWindow mode.
    private(set) var focusedTrackedWindowID: CGWindowID?

    /// Bound observable for the overlays.
    private(set) var overlayRect: CGRect?

    /// Bound to the UI to show why we're not engaging right now.
    private(set) var engagementStatus: String = "Idle"

    // MARK: - Init

    init() {
        let settings = SettingsStore()
        let perms = PermissionsService()
        let windows = WindowService()
        let displays = DisplayService()
        let thumbs = WindowThumbnailService()
        let focus = FocusMonitor(windowService: windows)
        let hk = HotkeyManager()
        let profiles = ProfileStore(settingsStore: settings)
        let engine = ConfinementEngine()
        let lal = LaunchAtLoginService()
        let sound = SoundNotificationService()
        let screensaver = ScreenSaverMonitor()
        let appIcon = AppIconAppearance()

        self.settingsStore = settings
        self.permissions = perms
        self.windowService = windows
        self.displayService = displays
        self.thumbnailService = thumbs
        self.focusMonitor = focus
        self.hotkeyManager = hk
        self.profileStore = profiles
        self.engine = engine
        self.launchAtLogin = lal
        self.soundNotification = sound
        self.screenSaverMonitor = screensaver
        self.appIconAppearance = appIcon

        self.currentTarget = settings.settings.lastTarget
    }

    // MARK: - Bootstrap

    func bootstrap() {
        appIconAppearance.start()

        permissions.startMonitoring()
        permissions.refresh()
        // When the user grants Accessibility after launch (typical first-run
        // flow, or after an ad-hoc-signed rebuild that broke the existing
        // TCC trust), retry tap installation immediately. Without this the
        // app would silently stay in "no clamp" mode until the user quit
        // and relaunched.
        permissions.onAccessibilityGranted = { [weak self] in
            guard let self else { return }
            Log.engine.info("Accessibility granted — retrying event-tap install")
            let installed = self.engine.installTap()
            Log.engine.info("Event tap install retry: \(installed ? "success" : "failed", privacy: .public)")
            self.recomputeEngagement(reason: "accessibility granted")
        }
        permissions.onScreenRecordingGranted = { [weak self] in
            // Bust the thumbnail cache so the picker re-renders with real images.
            self?.thumbnailService.clearCache()
        }

        engine.inset = CGFloat(settingsStore.settings.edgeInset)
        engine.temporaryReleaseCheck = { [weak self] in
            guard let self else { return false }
            let mod = self.settingsStore.settings.holdToReleaseModifier
            if mod == .none { return false }
            let flags = CGEvent(source: nil)?.flags ?? []
            return flags.contains(mod.cgFlag)
        }

        // Install the event tap eagerly. If Accessibility hasn't been granted
        // yet, the tap won't install — we surface that via permissions UI and
        // auto-retry above when permission flips on.
        _ = engine.installTap()

        focusMonitor.onChange = { [weak self] in
            self?.handleFocusChange()
        }
        focusMonitor.start()

        screenSaverMonitor.onChange = { [weak self] in
            self?.recomputeEngagement(reason: "screensaver changed")
        }
        screenSaverMonitor.start()

        wireHotkeys()

        if settingsStore.settings.autoStartConfinementOnLaunch {
            arm()
        }

        soundNotification.requestNotificationAuthorizationIfNeeded()
    }

    func shutdown() {
        disarm()
        engine.uninstallTap()
        focusMonitor.stop()
        screenSaverMonitor.stop()
        hotkeyManager.unregisterAll()
        settingsStore.saveNow()
    }

    // MARK: - Hotkeys

    func wireHotkeys() {
        hotkeyManager.unregisterAll()
        hotkeyManager.register(.toggle, hotkey: settingsStore.settings.toggleHotkey)
        hotkeyManager.register(.pickWindow, hotkey: settingsStore.settings.pickWindowHotkey)
        hotkeyManager.register(.panic, hotkey: settingsStore.settings.panicHotkey)

        hotkeyManager.setHandler(.toggle) { [weak self] in
            self?.toggleArmed()
        }
        hotkeyManager.setHandler(.pickWindow) { [weak self] in
            self?.openWindowPicker()
        }
        hotkeyManager.setHandler(.panic) { [weak self] in
            self?.panicRelease()
        }
    }

    // MARK: - Arm / disarm / panic

    func arm() {
        isPanicReleased = false
        isArmed = true
        recomputeEngagement(reason: "armed")
    }

    func disarm() {
        isArmed = false
        engine.disengage()
        overlayRect = nil
        engagementStatus = "Off"
        if settingsStore.settings.soundOnUnlock { soundNotification.playUnlockSound() }
        if settingsStore.settings.notifyOnUnlock {
            soundNotification.notify(title: "CursorConfine", body: "Cursor released")
        }
    }

    func toggleArmed() {
        if isArmed { disarm() } else { arm() }
    }

    /// Emergency release — always frees the cursor regardless of state. Stays
    /// released until the user re-arms. Distinct from disarm so a future "hold
    /// to re-arm" feature can be layered on top.
    func panicRelease() {
        isPanicReleased = true
        isArmed = false
        engine.disengage()
        overlayRect = nil
        engagementStatus = "Released (panic key)"
        if settingsStore.settings.notifyOnUnlock {
            soundNotification.notify(title: "CursorConfine", body: "Panic-released")
        }
    }

    // MARK: - Picking

    /// Set the target to a specific window enumerated from the picker.
    func selectWindow(_ w: WindowInfo) {
        var t = currentTarget
        t.mode = .window
        t.windowSelection = WindowSelection(from: w)
        currentTarget = t
        trackedWindowID = w.id
    }

    func setRectangleTarget(_ rect: CGRect) {
        let screen = Geometry.screenContainingCGRect(rect)
        let uuid: String? = {
            guard let screen,
                  let sid = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return nil }
            return DisplayService.uuid(for: sid)
        }()
        var t = currentTarget
        t.mode = .rectangle
        t.rectangle = SavedRect(rect: rect, displayUUID: uuid)
        currentTarget = t
    }

    func setDisplayTarget(_ display: DisplayInfo) {
        var t = currentTarget
        t.mode = .display
        t.displayUUID = display.uuid
        currentTarget = t
    }

    func setFocusedWindowMode() {
        var t = currentTarget
        t.mode = .focusedWindow
        currentTarget = t
    }

    // Surfaces a UI intent; wired to the SwiftUI layer through a NotificationCenter post.
    func openWindowPicker() {
        NotificationCenter.default.post(name: .cursorConfineOpenWindowPicker, object: nil)
    }

    // MARK: - Focus / profile reactions

    private func handleFocusChange() {
        // Profile autoactivation: when the frontmost app changes, see if a
        // profile for that bundle ID is armed.
        if let bundle = focusMonitor.frontmostBundleID,
           let profile = profileStore.profile(for: bundle) {
            let windows = windowService.enumerate()
            let target = profile.toTarget(matching: windows)
            if target != currentTarget {
                currentTarget = target
                Log.profiles.info("Auto-applied profile '\(profile.name, privacy: .public)' for \(bundle, privacy: .public)")
            }
            // Profiles imply arming for that app.
            isArmed = true
            isPanicReleased = false
        }
        recomputeEngagement(reason: "focus changed")
    }

    /// Decide whether the engine should currently be engaged, and to what rect.
    /// Idempotent — safe to call from many places (focus changes, target changes,
    /// screensaver changes, settings changes, etc.).
    func recomputeEngagement(reason: String) {
        defer { Log.engine.debug("recompute(\(reason, privacy: .public)) -> \(self.engagementStatus, privacy: .public)") }

        // Re-apply runtime config
        engine.inset = CGFloat(settingsStore.settings.edgeInset)

        // Tap-not-installed is the dominant state — without it no clamping
        // can possibly happen, regardless of armed/target/focus. Surface that
        // BEFORE anything else so the UI stops claiming "Locked" while the
        // cursor can still walk off the rect.
        if !engine.isTapInstalled {
            engine.disengage()
            overlayRect = nil
            engagementStatus = "Engine not running — Accessibility required"
            return
        }

        if isPanicReleased {
            engine.disengage()
            overlayRect = nil
            engagementStatus = "Released (panic key)"
            return
        }
        if !isArmed {
            engine.disengage()
            overlayRect = nil
            engagementStatus = "Off"
            return
        }
        if settingsStore.settings.pauseWhenScreenSaverActive,
           (screenSaverMonitor.isScreenSaverActive || screenSaverMonitor.isScreenLocked) {
            engine.disengage()
            overlayRect = nil
            engagementStatus = "Paused (screen locked / saver)"
            return
        }

        guard let resolvedRect = resolveTargetRect() else {
            engine.disengage()
            overlayRect = nil
            engagementStatus = "Waiting on target…"
            return
        }

        // Focus gate: for window/focusedWindow modes, only engage when the target
        // window is frontmost.
        if requiresFocusGate {
            guard focusIsOnTarget() else {
                engine.disengage()
                overlayRect = nil
                engagementStatus = "Standby (target not focused)"
                return
            }
        }

        let wasConfining = engine.isConfining
        engine.engage(rect: resolvedRect)
        overlayRect = resolvedRect
        engagementStatus = "Locked: \(currentTarget.summary)"

        if !wasConfining {
            if settingsStore.settings.soundOnLock { soundNotification.playLockSound() }
            if settingsStore.settings.notifyOnLock {
                soundNotification.notify(title: "CursorConfine",
                                         body: "Cursor locked to \(currentTarget.summary)")
            }
        }
    }

    private var requiresFocusGate: Bool {
        switch currentTarget.mode {
        case .window, .focusedWindow: return true
        case .rectangle, .display:    return false
        }
    }

    private func focusIsOnTarget() -> Bool {
        switch currentTarget.mode {
        case .window:
            guard let sel = currentTarget.windowSelection else { return false }
            let windows = windowService.enumerate()
            guard let target = windowService.resolve(selection: sel, in: windows) else {
                return false
            }
            trackedWindowID = target.id
            return focusMonitor.frontmostPID == target.pid &&
                   focusMonitor.frontmostWindowID == target.id
        case .focusedWindow:
            return focusMonitor.frontmostWindowID != nil
        default:
            return true
        }
    }

    private func resolveTargetRect() -> CGRect? {
        switch currentTarget.mode {
        case .window:
            guard let sel = currentTarget.windowSelection else { return nil }
            let windows = windowService.enumerate()
            guard let target = windowService.resolve(selection: sel, in: windows) else {
                return nil
            }
            trackedWindowID = target.id
            return windowService.currentBounds(forWindowID: target.id) ?? target.bounds

        case .focusedWindow:
            guard let id = focusMonitor.frontmostWindowID else { return nil }
            focusedTrackedWindowID = id
            return windowService.currentBounds(forWindowID: id)

        case .rectangle:
            return currentTarget.rectangle?.cgRect

        case .display:
            guard let uuid = currentTarget.displayUUID,
                  let display = displayService.resolve(uuid: uuid)
            else { return nil }
            return display.boundsCG
        }
    }
}

extension Notification.Name {
    static let cursorConfineOpenWindowPicker = Notification.Name("cursorConfineOpenWindowPicker")
    static let cursorConfineOpenMain = Notification.Name("cursorConfineOpenMain")
    static let cursorConfineStartRegionPicker = Notification.Name("cursorConfineStartRegionPicker")
}
