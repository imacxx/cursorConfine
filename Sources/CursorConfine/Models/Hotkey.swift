import Foundation
import Carbon.HIToolbox

/// User-configurable global hotkey. Encodes Carbon virtual key code + modifier mask.
struct Hotkey: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt32      // Carbon kVK_* virtual key code
    var modifiers: UInt32    // Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey)

    static let unset = Hotkey(keyCode: 0, modifiers: 0)

    var isSet: Bool { keyCode != 0 || modifiers != 0 }

    /// Human-readable description, e.g. "⌃⌥L".
    var description: String {
        guard isSet else { return "Unset" }
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        parts.append(Hotkey.keyName(for: keyCode))
        return parts.joined()
    }

    /// Suggested default toggle hotkey: ⌃⌥L
    static let defaultToggle = Hotkey(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(controlKey | optionKey)
    )

    /// Default pick-window hotkey: ⌃⌥P
    static let defaultPickWindow = Hotkey(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(controlKey | optionKey)
    )

    /// Default panic-release hotkey: ⌃⌥⇧Escape
    static let defaultPanic = Hotkey(
        keyCode: UInt32(kVK_Escape),
        modifiers: UInt32(controlKey | optionKey | shiftKey)
    )

    // MARK: - Key name lookup

    static func keyName(for keyCode: UInt32) -> String {
        if let s = specialKeyNames[Int(keyCode)] { return s }
        // Attempt to translate via UCKeyTranslate for letter keys.
        if let s = translate(keyCode: keyCode) { return s.uppercased() }
        return "Key \(keyCode)"
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Escape: "⎋",
        kVK_Tab: "⇥",
        kVK_Return: "↩",
        kVK_Space: "Space",
        kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_DownArrow: "↓",
        kVK_UpArrow: "↑",
        kVK_F1: "F1",  kVK_F2: "F2",  kVK_F3: "F3",  kVK_F4: "F4",
        kVK_F5: "F5",  kVK_F6: "F6",  kVK_F7: "F7",  kVK_F8: "F8",
        kVK_F9: "F9",  kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
    ]

    private static func translate(keyCode: UInt32) -> String? {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutDataRaw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataRaw).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength = 0
        let status = layoutData.withUnsafeBytes { rawBuf -> OSStatus in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &realLength,
                &chars
            )
        }
        guard status == noErr, realLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: realLength)
    }
}

/// Single modifier choice for the "hold-to-release" feature.
enum ModifierKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, command, option, control, shift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:    return "None"
        case .command: return "⌘ Command"
        case .option:  return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift:   return "⇧ Shift"
        }
    }

    /// The CGEventFlags mask for this modifier (or empty for .none).
    var cgFlag: CGEventFlags {
        switch self {
        case .none:    return []
        case .command: return .maskCommand
        case .option:  return .maskAlternate
        case .control: return .maskControl
        case .shift:   return .maskShift
        }
    }
}
