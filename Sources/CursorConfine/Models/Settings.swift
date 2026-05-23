import Foundation
import SwiftUI

/// Codable RGBA color so we can persist user color choices without depending on NSColor archiving.
struct ColorRGBA: Codable, Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static let defaultBorder = ColorRGBA(red: 0.35, green: 0.78, blue: 1.0, alpha: 0.9)
}

/// The entire persisted user settings document.
struct Settings: Codable, Equatable, Sendable {
    var toggleHotkey: Hotkey
    var pickWindowHotkey: Hotkey
    var panicHotkey: Hotkey

    var holdToReleaseModifier: ModifierKey

    var lastTarget: ConfinementTarget

    /// Pixel inset on each edge; positive shrinks the allowed cursor area.
    var edgeInset: Double

    var dimOverlayEnabled: Bool
    var dimOverlayOpacity: Double

    var borderOverlayEnabled: Bool
    var borderColor: ColorRGBA
    var borderWidth: Double

    var soundOnLock: Bool
    var soundOnUnlock: Bool
    var notifyOnLock: Bool
    var notifyOnUnlock: Bool

    var startAtLogin: Bool
    var autoStartConfinementOnLaunch: Bool
    var pauseWhenScreenSaverActive: Bool

    var profiles: [Profile]
    var hasCompletedOnboarding: Bool

    static let defaults = Settings(
        toggleHotkey: .defaultToggle,
        pickWindowHotkey: .defaultPickWindow,
        panicHotkey: .defaultPanic,
        holdToReleaseModifier: .command,
        lastTarget: .none,
        edgeInset: 0,
        dimOverlayEnabled: false,
        dimOverlayOpacity: 0.55,
        borderOverlayEnabled: false,
        borderColor: .defaultBorder,
        borderWidth: 2,
        soundOnLock: false,
        soundOnUnlock: false,
        notifyOnLock: false,
        notifyOnUnlock: false,
        startAtLogin: false,
        autoStartConfinementOnLaunch: false,
        pauseWhenScreenSaverActive: true,
        profiles: [],
        hasCompletedOnboarding: false
    )
}
