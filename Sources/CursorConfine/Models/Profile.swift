import Foundation

/// A per-app rule that automatically applies a confinement when that app becomes frontmost.
struct Profile: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var bundleIdentifier: String
    var appName: String
    var mode: ConfinementMode
    /// For .window mode: substring of window title to prefer (e.g. "League of Legends (TM) Client").
    /// Empty = any window of the app.
    var windowTitleHint: String
    /// For .rectangle mode.
    var rectangle: SavedRect?
    /// Whether this rule auto-engages on app focus.
    var autoActivate: Bool
    /// Whether overlay/border should apply for this profile.
    var enableOverlay: Bool

    init(id: UUID = UUID(),
         name: String,
         bundleIdentifier: String,
         appName: String,
         mode: ConfinementMode = .focusedWindow,
         windowTitleHint: String = "",
         rectangle: SavedRect? = nil,
         autoActivate: Bool = true,
         enableOverlay: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.mode = mode
        self.windowTitleHint = windowTitleHint
        self.rectangle = rectangle
        self.autoActivate = autoActivate
        self.enableOverlay = enableOverlay
    }

    func toTarget(matching windows: [WindowInfo]) -> ConfinementTarget {
        switch mode {
        case .window:
            // pick the best matching window of this app
            let candidates = windows.filter { $0.bundleIdentifier == bundleIdentifier }
            let picked: WindowInfo? = {
                if !windowTitleHint.isEmpty {
                    return candidates.first(where: { $0.title.contains(windowTitleHint) }) ?? candidates.first
                }
                return candidates.first
            }()
            if let picked {
                return ConfinementTarget(mode: .window, windowSelection: WindowSelection(from: picked))
            }
            return ConfinementTarget(mode: .focusedWindow)
        case .focusedWindow:
            return ConfinementTarget(mode: .focusedWindow)
        case .rectangle:
            return ConfinementTarget(mode: .rectangle, rectangle: rectangle)
        case .display:
            return ConfinementTarget(mode: .focusedWindow)
        }
    }
}
