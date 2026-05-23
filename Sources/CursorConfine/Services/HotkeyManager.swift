import Foundation
import Carbon.HIToolbox
import AppKit

/// Registers global hotkeys via Carbon's RegisterEventHotKey. Each registered
/// hotkey is invisible to other apps (events are swallowed at the system level),
/// so the key combo never types.
@MainActor
final class HotkeyManager {

    /// Logical roles the app cares about.
    enum Role: UInt32, CaseIterable {
        case toggle = 1
        case pickWindow = 2
        case panic = 3
    }

    private struct Registered {
        var ref: EventHotKeyRef
        var hotkey: Hotkey
    }

    private var registered: [Role: Registered] = [:]
    private var handlerInstalled = false
    private var handlerRef: EventHandlerRef?
    private var handlers: [Role: @MainActor () -> Void] = [:]

    init() {
        installHandler()
    }
    // No deinit: HotkeyManager lives for the whole process lifetime.
    // Cleaning up the Carbon handler from a nonisolated deinit would require
    // crossing the actor boundary with a non-Sendable EventHandlerRef.

    func setHandler(_ role: Role, _ handler: @escaping @MainActor () -> Void) {
        handlers[role] = handler
    }

    /// Replace whatever is currently registered for `role` with `hotkey`.
    /// Unregisters when `hotkey` is `.unset`.
    func register(_ role: Role, hotkey: Hotkey) {
        unregister(role)
        guard hotkey.isSet else { return }

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4343_5246 /* 'CCRF' */), id: role.rawValue)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            registered[role] = Registered(ref: ref, hotkey: hotkey)
            Log.hotkey.info("Registered \(String(describing: role)) -> \(hotkey.description, privacy: .public)")
        } else {
            Log.hotkey.error("RegisterEventHotKey failed for \(String(describing: role)) status=\(status)")
        }
    }

    func unregister(_ role: Role) {
        if let reg = registered[role] {
            UnregisterEventHotKey(reg.ref)
            registered.removeValue(forKey: role)
        }
    }

    func unregisterAll() {
        for role in Array(registered.keys) {
            unregister(role)
        }
    }

    // MARK: - Carbon handler

    private func installHandler() {
        guard !handlerInstalled else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            HotkeyManager.carbonHotKeyHandler,
            1,
            &eventSpec,
            selfPtr,
            &handlerRef
        )
        if status == noErr {
            handlerInstalled = true
        } else {
            Log.hotkey.error("InstallEventHandler failed status=\(status)")
        }
    }

    fileprivate func dispatch(roleRaw: UInt32) {
        guard let role = Role(rawValue: roleRaw) else { return }
        handlers[role]?()
    }

    private static let carbonHotKeyHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
        var hkID = EventHotKeyID()
        let err = GetEventParameter(eventRef,
                                    EventParamName(kEventParamDirectObject),
                                    EventParamType(typeEventHotKeyID),
                                    nil,
                                    MemoryLayout<EventHotKeyID>.size,
                                    nil,
                                    &hkID)
        if err != noErr { return err }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            manager.dispatch(roleRaw: hkID.id)
        }
        return noErr
    }
}
