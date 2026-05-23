import Foundation
import AppKit
import CoreGraphics

/// Coordinate-space helpers. Everything CursorConfine works with at runtime is in
/// the **global top-left-origin point space** used by CGEvent locations,
/// CGWarpMouseCursorPosition, CGWindowList bounds, and the AX API.
/// AppKit/NSScreen uses a bottom-left origin tied to NSScreen.screens[0]; we
/// only convert when we have to (e.g. positioning an NSWindow).
enum Geometry {

    /// Clamp a point so it stays within `rect`. The cursor is allowed to touch
    /// the exact edges (so games' edge-pan still works) but not cross them.
    /// Empty / inverted rects pass the point through unchanged.
    static func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        // Use raw `size.width` / `size.height` so we treat inverted rects
        // (negative w/h) as degenerate and skip clamping rather than silently
        // clamping into a region the caller didn't intend.
        guard rect.size.width > 0 && rect.size.height > 0 else { return point }
        // maxX/maxY are exclusive in CGRect; the largest legal coordinate is
        // maxX - 1 so the cursor sits on the last in-bounds pixel rather than
        // technically being one past it.
        let maxX = rect.origin.x + max(0, rect.size.width  - 1)
        let maxY = rect.origin.y + max(0, rect.size.height - 1)
        return CGPoint(
            x: min(max(point.x, rect.origin.x), maxX),
            y: min(max(point.y, rect.origin.y), maxY)
        )
    }

    /// Insets a rect on all four sides by `inset`. Negative insets grow the rect;
    /// zero-or-smaller dimensions are clamped so the result still has a tiny extent
    /// the cursor can hit.
    static func insetting(_ rect: CGRect, by inset: CGFloat) -> CGRect {
        guard inset != 0 else { return rect }
        let r = rect.insetBy(dx: inset, dy: inset)
        if r.width <= 0 || r.height <= 0 {
            // Don't let the user deadlock the cursor on a one-pixel point that
            // could be off-screen on a display gone away. Fall back to the
            // original rect.
            return rect
        }
        return r
    }

    /// Returns the union of all NSScreen frames in the AppKit (bottom-left) space.
    static func appKitGlobalBounds() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    /// Returns the `frame` of the screen that contains the menu bar (CGDisplay's primary).
    /// This is the origin reference for AppKit↔CG conversion.
    static func primaryScreenFrameAppKit() -> CGRect {
        // NSScreen.screens[0] is the screen containing the menu bar.
        NSScreen.screens.first?.frame ?? .zero
    }

    /// AppKit (bottom-left) point → CG global (top-left) point.
    /// y_cg = primary.maxY - y_appkit.
    static func cgPoint(fromAppKit p: CGPoint) -> CGPoint {
        let primary = primaryScreenFrameAppKit()
        return CGPoint(x: p.x, y: primary.maxY - p.y)
    }

    /// CG global (top-left) point → AppKit (bottom-left) point.
    static func appKitPoint(fromCG p: CGPoint) -> CGPoint {
        let primary = primaryScreenFrameAppKit()
        return CGPoint(x: p.x, y: primary.maxY - p.y)
    }

    /// AppKit (bottom-left) rect → CG global (top-left) rect.
    static func cgRect(fromAppKit r: CGRect) -> CGRect {
        let primary = primaryScreenFrameAppKit()
        let topLeftY = primary.maxY - r.maxY
        return CGRect(x: r.origin.x, y: topLeftY, width: r.width, height: r.height)
    }

    /// CG global (top-left) rect → AppKit (bottom-left) rect.
    static func appKitRect(fromCG r: CGRect) -> CGRect {
        let primary = primaryScreenFrameAppKit()
        let bottomLeftY = primary.maxY - r.maxY
        return CGRect(x: r.origin.x, y: bottomLeftY, width: r.width, height: r.height)
    }

    /// Find the NSScreen that best contains a CG-global rect.
    static func screenContainingCGRect(_ r: CGRect) -> NSScreen? {
        var best: (screen: NSScreen, overlap: CGFloat)?
        for screen in NSScreen.screens {
            let screenCG = cgRect(fromAppKit: screen.frame)
            let inter = screenCG.intersection(r)
            let area = inter.isNull ? 0 : inter.width * inter.height
            if area > (best?.overlap ?? 0) {
                best = (screen, area)
            }
        }
        return best?.screen ?? NSScreen.main
    }
}
