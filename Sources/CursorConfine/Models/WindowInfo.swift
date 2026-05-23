import Foundation
import CoreGraphics

/// One window enumerated from CGWindowList.
/// `bounds` are in the global top-left-origin point space used by CGEvent/CGWarpMouse.
struct WindowInfo: Identifiable, Hashable, Sendable {
    let id: CGWindowID
    let appName: String
    let title: String
    let bounds: CGRect
    let pid: pid_t
    let bundleIdentifier: String?
    let layer: Int
    /// True if the window is currently visible (on the active Space and not
    /// fully covered). False for fullscreen games on inactive Spaces.
    let isOnScreen: Bool

    var displayLabel: String {
        if title.isEmpty {
            return appName
        }
        return "\(appName) — \(title)"
    }
}

/// A serializable reference to a window. CGWindowID is volatile across restarts,
/// so we re-match on bundleID + title at runtime.
struct WindowSelection: Codable, Equatable, Hashable, Sendable {
    var bundleIdentifier: String?
    var appName: String
    var windowTitle: String

    init(from info: WindowInfo) {
        self.bundleIdentifier = info.bundleIdentifier
        self.appName = info.appName
        self.windowTitle = info.title
    }

    init(bundleIdentifier: String?, appName: String, windowTitle: String) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
    }

    /// Score how well a candidate window matches this selection. Higher = better; 0 = no match.
    func matchScore(against w: WindowInfo) -> Int {
        var score = 0
        if let bid = bundleIdentifier, let wbid = w.bundleIdentifier, bid == wbid {
            score += 100
        } else if w.appName == appName {
            score += 50
        } else {
            return 0
        }
        if w.title == windowTitle {
            score += 50
        } else if !windowTitle.isEmpty && w.title.contains(windowTitle) {
            score += 20
        } else if !w.title.isEmpty && windowTitle.contains(w.title) {
            score += 10
        }
        return score
    }
}
