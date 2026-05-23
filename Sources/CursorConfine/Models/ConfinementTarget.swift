import Foundation
import CoreGraphics

/// Persistable description of what to confine the cursor to.
struct ConfinementTarget: Codable, Equatable, Hashable, Sendable {
    var mode: ConfinementMode
    var windowSelection: WindowSelection?
    var rectangle: SavedRect?
    var displayUUID: String?

    static let none = ConfinementTarget(mode: .focusedWindow)

    init(mode: ConfinementMode,
         windowSelection: WindowSelection? = nil,
         rectangle: SavedRect? = nil,
         displayUUID: String? = nil) {
        self.mode = mode
        self.windowSelection = windowSelection
        self.rectangle = rectangle
        self.displayUUID = displayUUID
    }

    /// True if this target has enough info to attempt resolving to a rect.
    var isConfigured: Bool {
        switch mode {
        case .window:        return windowSelection != nil
        case .focusedWindow: return true
        case .rectangle:     return rectangle != nil
        case .display:       return displayUUID != nil
        }
    }

    var summary: String {
        switch mode {
        case .window:
            return windowSelection.map { "\($0.appName) — \($0.windowTitle)" } ?? "No window chosen"
        case .focusedWindow:
            return "Whichever window is active"
        case .rectangle:
            guard let r = rectangle else { return "No region chosen" }
            return "Region \(Int(r.width))×\(Int(r.height)) at (\(Int(r.x)), \(Int(r.y)))"
        case .display:
            return displayUUID.map { _ in "A specific display" } ?? "No display chosen"
        }
    }
}

/// Codable rectangle in global top-left-origin point space, with the display it lives on.
struct SavedRect: Codable, Equatable, Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var displayUUID: String?

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    init(rect: CGRect, displayUUID: String? = nil) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
        self.displayUUID = displayUUID
    }

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, displayUUID: String? = nil) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.displayUUID = displayUUID
    }
}
