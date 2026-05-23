import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

/// Enumerates on-screen windows and resolves a `WindowSelection` to a current
/// `WindowInfo`. Also exposes async thumbnail capture via ScreenCaptureKit when
/// Screen Recording permission has been granted.
@MainActor
final class WindowService {

    /// Bundle-ID prefixes we never want to surface in the picker, even though
    /// they technically own on-screen windows.
    private static let systemUIPrefixes: [String] = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.WindowManager",
        "com.apple.notificationcenter",
        "com.apple.Spotlight",
        "com.apple.loginwindow",
        "com.apple.PowerChime",
        "com.apple.universalcontrol",
    ]

    /// Snapshot of windows that *could* be confined to.
    /// - Uses `.optionAll` instead of `.optionOnScreenOnly` so that fullscreen
    ///   games on inactive macOS Spaces still show up (League of Legends in
    ///   particular puts its game window on its own Space, so onscreen-only
    ///   would hide it).
    /// - No layer cap by default: LoL's in-game window sits at layer 1000
    ///   (`kCGScreenSaverWindowLevel`). High-layer system overlays are
    ///   excluded by the bundle-ID denylist and the empty-title rule.
    /// - Without Screen Recording permission macOS masks normal window titles
    ///   to "". Those still appear as "<App> — Untitled window".
    func enumerate() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var out: [WindowInfo] = []
        out.reserveCapacity(infoList.count)
        // Dedup: per (pid, title) keep one. Same app may report several
        // identical-looking transient windows; we want the picker tidy.
        var seen = Set<String>()

        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer >= 0 else { continue }
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let appName = info[kCGWindowOwnerName as String] as? String else { continue }
            let title = (info[kCGWindowName as String] as? String) ?? ""
            let pid = (info[kCGWindowOwnerPID as String] as? Int32) ?? 0
            if pid == myPID { continue }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any] else { continue }
            guard let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Require a reasonable size — drops tiny palettes, badges, etc.
            guard bounds.width >= 200, bounds.height >= 150 else { continue }

            // High-layer windows with empty titles are almost certainly system
            // overlays (cursor sprites, dragging windows, screensaver chrome,
            // status-bar popovers). Allow high layers only when there's a
            // title — that catches games like LoL at layer 1000.
            if layer > 25 && title.isEmpty { continue }

            // Owner-process bundle-ID denylist for system UI.
            let running = NSRunningApplication(processIdentifier: pid_t(pid))
            if let bid = running?.bundleIdentifier,
               Self.systemUIPrefixes.contains(where: { bid.hasPrefix($0) }) {
                continue
            }

            let isOnScreen = (info[kCGWindowIsOnscreen as String] as? Bool) ?? false

            // Dedup on (pid + title + size) — same app windows with identical
            // attributes are almost always artifacts of the same logical
            // window enumerated multiple times.
            let key = "\(pid)|\(title)|\(Int(bounds.width))x\(Int(bounds.height))"
            if !seen.insert(key).inserted { continue }

            out.append(WindowInfo(
                id: windowID,
                appName: appName,
                title: title,
                bounds: bounds,
                pid: pid_t(pid),
                bundleIdentifier: running?.bundleIdentifier,
                layer: layer,
                isOnScreen: isOnScreen
            ))
        }

        // Visible-first ordering, then app name, then largest first.
        out.sort { a, b in
            if a.isOnScreen != b.isOnScreen { return a.isOnScreen }
            if a.appName != b.appName       { return a.appName < b.appName }
            return a.bounds.width * a.bounds.height > b.bounds.width * b.bounds.height
        }
        return out
    }

    /// Best-match resolution for a persisted selection (window IDs are volatile).
    func resolve(selection: WindowSelection, in windows: [WindowInfo]) -> WindowInfo? {
        let scored = windows
            .map { (w: $0, score: selection.matchScore(against: $0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
        return scored.first?.w
    }

    /// The window the user is currently looking at — the *visually* topmost
    /// on-screen window. We deliberately don't match by `NSWorkspace
    /// .frontmostApplication.pid` because multi-process apps (League of
    /// Legends ships separate `GameClient` and `LeagueClient` processes,
    /// Chromium-based apps split tabs across helpers, etc.) often disagree
    /// with macOS about which pid "owns" the visible window. CGWindowList's
    /// natural ordering is front-to-back z-order — index 0 is by definition
    /// what the user is interacting with.
    func frontmostWindow() -> WindowInfo? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let myPID = ProcessInfo.processInfo.processIdentifier

        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer >= 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != myPID else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 200, bounds.height >= 150 else { continue }

            let running = NSRunningApplication(processIdentifier: pid_t(pid))
            if let bid = running?.bundleIdentifier,
               Self.systemUIPrefixes.contains(where: { bid.hasPrefix($0) }) { continue }

            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            let appName = (info[kCGWindowOwnerName as String] as? String) ?? ""
            let title   = (info[kCGWindowName as String] as? String) ?? ""
            let isOnScreen = (info[kCGWindowIsOnscreen as String] as? Bool) ?? true

            return WindowInfo(
                id: windowID, appName: appName, title: title, bounds: bounds,
                pid: pid_t(pid), bundleIdentifier: running?.bundleIdentifier,
                layer: layer, isOnScreen: isOnScreen
            )
        }
        return nil
    }

    /// Returns the current bounds for a specific window ID, or nil if it's gone.
    func currentBounds(forWindowID id: CGWindowID) -> CGRect? {
        // `.optionIncludingWindow` only adds the named window IF a co-option
        // makes it eligible. Combine with `.optionAll` so we still find the
        // bounds when the window is on a different Space / minimized.
        let options: CGWindowListOption = [.optionAll, .optionIncludingWindow]
        guard let info = CGWindowListCopyWindowInfo(options, id) as? [[String: Any]] else { return nil }
        guard let first = info.first else { return nil }
        guard let boundsDict = first[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }
        return bounds
    }
}
