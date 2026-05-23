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

    /// Optional pre-confinement check. If this returns false the tap passes
    /// events through (used for the hold-to-release modifier).
    var temporaryReleaseCheck: (@MainActor () -> Bool)?

    // MARK: - Internals

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // The mouse event types we observe. Keys/buttons are never trapped.
    private static let eventsOfInterest: CGEventMask =
        (1 << CGEventType.mouseMoved.rawValue) |
        (1 << CGEventType.leftMouseDragged.rawValue) |
        (1 << CGEventType.rightMouseDragged.rawValue) |
        (1 << CGEventType.otherMouseDragged.rawValue) |
        (1 << CGEventType.leftMouseDown.rawValue) |
        (1 << CGEventType.rightMouseDown.rawValue) |
        (1 << CGEventType.otherMouseDown.rawValue)

    // MARK: - Lifecycle

    /// Try to install the tap. Returns true on success; sets `lastError` on failure.
    /// Safe to call multiple times — if already installed it's a no-op.
    @discardableResult
    func installTap() -> Bool {
        if eventTap != nil { isTapInstalled = true; return true }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
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

        // Pass-through when not actively confining.
        guard let rect = activeRect else { return Unmanaged.passUnretained(event) }

        // Hold-to-release: if the registered modifier is being held, pass events through.
        if let check = temporaryReleaseCheck, check() {
            return Unmanaged.passUnretained(event)
        }

        let loc = event.location
        let clamped = Geometry.clamp(point: loc, to: rect)
        if clamped != loc {
            event.location = clamped
            // CGWarpMouseCursorPosition forces the system cursor sprite to follow,
            // which matters for games that read the cursor position from HID directly.
            // It can suppress mouse movement briefly; that's actually desirable here.
            CGWarpMouseCursorPosition(clamped)
        }
        return Unmanaged.passUnretained(event)
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
