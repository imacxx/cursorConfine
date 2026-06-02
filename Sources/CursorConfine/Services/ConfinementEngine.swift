import Foundation
import CoreGraphics
import AppKit
import Observation

/// Installs a low-level CGEventTap on mouse motion events and clamps every
/// event location into the current confinement rect. Designed for an
/// allocation-free hot path: the callback only reads two stored properties
/// (`activeRect`, `inset`) and one volatile flag (`temporaryRelease`).
@MainActor
@Observable
final class ConfinementEngine {

    // MARK: - Observable state

    /// True when the tap is installed and we have a non-nil active rect AND
    /// confinement is not paused by focus/hold/panic.
    private(set) var isConfining: Bool = false

    /// The rect we are currently clamping into, in CG global top-left coords.
    /// nil = pass-through (no clamping).
    private(set) var activeRect: CGRect?

    /// True when the tap is installed and listening for events.
    private(set) var isTapInstalled: Bool = false

    /// Last error message, surfaced to the UI.
    private(set) var lastError: String?

    // MARK: - Configuration

    /// Inset (in points) shrinks the clamp rect on all four sides.
    var inset: CGFloat = 0

    /// Modifier mask that temporarily releases confinement when held. Empty
    /// = disabled. Reading `event.flags` directly inside the tap callback is
    /// dramatically cheaper than instantiating a new CGEvent to query the
    /// system flag state per mouse move (the previous closure-based design
    /// did that allocation thousands of times per second during edge slides).
    var holdToReleaseMask: CGEventFlags = []

    /// Fired when the user invokes the system app switcher. This is treated as
    /// intentional, unlike a leaked outside mouse click in windowed games.
    var onIntentionalAppSwitch: (@MainActor () -> Void)?

    // MARK: - Internals

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // The mouse event types we observe. Keys are never trapped.
    private static let eventsOfInterest: CGEventMask =
        (1 << CGEventType.mouseMoved.rawValue) |
        (1 << CGEventType.leftMouseDragged.rawValue) |
        (1 << CGEventType.rightMouseDragged.rawValue) |
        (1 << CGEventType.otherMouseDragged.rawValue) |
        (1 << CGEventType.leftMouseDown.rawValue) |
        (1 << CGEventType.rightMouseDown.rawValue) |
        (1 << CGEventType.otherMouseDown.rawValue) |
        (1 << CGEventType.leftMouseUp.rawValue) |
        (1 << CGEventType.rightMouseUp.rawValue) |
        (1 << CGEventType.otherMouseUp.rawValue) |
        (1 << CGEventType.keyDown.rawValue)

    private struct MouseButtons: OptionSet {
        let rawValue: UInt8

        static let left = MouseButtons(rawValue: 1 << 0)
        static let right = MouseButtons(rawValue: 1 << 1)
        static let other = MouseButtons(rawValue: 1 << 2)
    }

    /// Mouse downs cancelled because they began outside the confinement rect.
    /// Matching ups are cancelled too so we do not emit a stray button-up into
    /// the target window.
    private var suppressedMouseButtons: MouseButtons = []

    // MARK: - Lifecycle

    /// Try to install the tap. Returns true on success; sets `lastError` on failure.
    /// Safe to call multiple times — if already installed it's a no-op.
    @discardableResult
    func installTap() -> Bool {
        if eventTap != nil { isTapInstalled = true; return true }

        // The default 250 ms post-warp local-events suppression is what made
        // the user's cursor feel "stuck" against edges — every warp blocked
        // the next batch of mouse moves long enough for visible jitter.
        // The legacy `CGSetLocalEventsSuppressionInterval(0)` is gone on
        // modern macOS; the replacement is a per-source setter. Setting it
        // on the HID system source covers the global warp path.
        if let hidSource = CGEventSource(stateID: .hidSystemState) {
            hidSource.localEventsSuppressionInterval = 0
        }
        if let combinedSource = CGEventSource(stateID: .combinedSessionState) {
            combinedSource.localEventsSuppressionInterval = 0
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let tap = CGEvent.tapCreate(
            // Intercept at the HID boundary, before WindowServer uses an
            // outside mouse-down to activate another app/window.
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventsOfInterest,
            callback: ConfinementEngine.eventTapCallback,
            userInfo: selfPtr
        )
        guard let tap else {
            lastError = "Couldn't install the global mouse event tap. Grant Accessibility access in System Settings → Privacy & Security → Accessibility, then relaunch CursorConfine."
            isTapInstalled = false
            Log.engine.error("CGEvent.tapCreate failed (Accessibility not granted?)")
            return false
        }
        self.eventTap = tap

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        self.runLoopSource = src
        CGEvent.tapEnable(tap: tap, enable: true)

        isTapInstalled = true
        lastError = nil
        Log.engine.info("Event tap installed")
        return true
    }

    func uninstallTap() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        isTapInstalled = false
        activeRect = nil
        isConfining = false
    }

    // MARK: - Rect control

    /// Begin clamping into `rect`. `rect` must be in CG global (top-left) point space.
    func engage(rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        let inset = Geometry.insetting(rect, by: self.inset)
        self.activeRect = inset
        self.isConfining = true
        // Snap the cursor into the rect immediately, so the user gets
        // visual feedback even if they aren't moving the mouse.
        let current = currentMouseLocationCG()
        let clamped = Geometry.clamp(point: current, to: inset)
        if clamped != current {
            CGWarpMouseCursorPosition(clamped)
        }
    }

    /// Update the active rect without changing engaged/disengaged state.
    /// No-op if not currently engaged.
    func updateRect(_ rect: CGRect) {
        guard isConfining else { return }
        guard rect.width > 0, rect.height > 0 else { return }
        self.activeRect = Geometry.insetting(rect, by: self.inset)
    }

    /// Stop clamping. Tap remains installed (cheap) so re-engaging is instant.
    func disengage() {
        self.activeRect = nil
        self.isConfining = false
    }

    // MARK: - Event tap callback

    /// C-pointer callback; never allocates. Hops through Unmanaged to the instance.
    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let engine = Unmanaged<ConfinementEngine>.fromOpaque(userInfo).takeUnretainedValue()
        return engine.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The tap can be auto-disabled by the system if our callback takes too long
        // or if user input arrives during a hang. Re-enable it; macOS won't do this for us.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown, Self.isAppSwitchShortcut(event) {
            onIntentionalAppSwitch?()
            return Unmanaged.passUnretained(event)
        }

        // Pass-through when not actively confining.
        guard let rect = activeRect else { return Unmanaged.passUnretained(event) }

        // Hold-to-release modifier — read flags off the event we already have
        // instead of constructing a fresh CGEvent.
        if !holdToReleaseMask.isEmpty && event.flags.contains(holdToReleaseMask) {
            return Unmanaged.passUnretained(event)
        }

        let loc = event.location
        let clamped = Geometry.clamp(point: loc, to: rect)
        let mouseButton = Self.mouseButton(for: type)

        if let button = mouseButton, Self.isMouseDown(type), clamped != loc {
            suppressedMouseButtons.insert(button)
            CGWarpMouseCursorPosition(clamped)
            return nil
        }

        if let button = mouseButton, Self.isMouseUp(type), suppressedMouseButtons.contains(button) {
            suppressedMouseButtons.remove(button)
            if clamped != loc {
                CGWarpMouseCursorPosition(clamped)
            }
            return nil
        }

        if clamped != loc {
            event.location = clamped
            // Always warp on out-of-bounds. CGWarpMouseCursorPosition also
            // updates the system's internal HID position — without it, the
            // OS keeps accumulating mouse delta past the boundary while
            // the user pushes against it, so they later have to "drag the
            // cursor back" through that accumulated overshoot before it
            // moves at all. That presents as "the cursor is stuck to the
            // side." Dedup'ing warps avoids the WindowServer round-trip
            // but reintroduces the accumulation bug.
            CGWarpMouseCursorPosition(clamped)
        }
        return Unmanaged.passUnretained(event)
    }

    private static func mouseButton(for type: CGEventType) -> MouseButtons? {
        switch type {
        case .leftMouseDown, .leftMouseUp:
            return .left
        case .rightMouseDown, .rightMouseUp:
            return .right
        case .otherMouseDown, .otherMouseUp:
            return .other
        default:
            return nil
        }
    }

    private static func isMouseDown(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return true
        default:
            return false
        }
    }

    private static func isMouseUp(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return true
        default:
            return false
        }
    }

    private static func isAppSwitchShortcut(_ event: CGEvent) -> Bool {
        let tabKeyCode: Int64 = 48
        guard event.getIntegerValueField(.keyboardEventKeycode) == tabKeyCode else {
            return false
        }

        let flags = event.flags
        return flags.contains(.maskCommand) || flags.contains(.maskAlternate)
    }

    // MARK: - Helpers

    func currentMouseLocationCG() -> CGPoint {
        if let evLoc = CGEvent(source: nil)?.location {
            return evLoc
        }
        // Fall back via AppKit (mouseLocation is bottom-left origin).
        let p = NSEvent.mouseLocation
        return Geometry.cgPoint(fromAppKit: p)
    }
}
