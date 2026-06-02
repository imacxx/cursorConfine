import AppKit

/// Transparent non-activating panels outside the protected rect. They let the
/// cursor visually leave the game window, but swallow clicks before underlying
/// apps can use them to steal focus.
@MainActor
final class ClickShieldOverlayController {

    private var panels: [ClickShieldPanel] = []
    private var lastRect: CGRect?

    func show(protectedRect rect: CGRect) {
        let totalCG = totalBoundsCG()
        let protected = rect.intersection(totalCG)
        guard !protected.isNull, protected.width > 0, protected.height > 0 else {
            hide()
            return
        }

        if protected == lastRect, panels.allSatisfy(\.isVisible) {
            return
        }

        let shieldRects = Self.shieldRects(around: protected, within: totalCG)
        syncPanelCount(to: shieldRects.count)

        for (panel, shieldRect) in zip(panels, shieldRects) {
            let frame = Geometry.appKitRect(fromCG: shieldRect)
            panel.setFrame(frame, display: false, animate: false)
            panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
            panel.orderFrontRegardless()
        }

        lastRect = protected
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        lastRect = nil
    }

    private func syncPanelCount(to count: Int) {
        while panels.count < count {
            panels.append(Self.makePanel())
        }

        if panels.count > count {
            for panel in panels[count...] {
                panel.orderOut(nil)
            }
            panels.removeSubrange(count...)
        }
    }

    private static func makePanel() -> ClickShieldPanel {
        let panel = ClickShieldPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = ClickShieldView(frame: .zero)
        return panel
    }

    private static func shieldRects(around rect: CGRect, within total: CGRect) -> [CGRect] {
        [
            CGRect(x: total.minX, y: total.minY, width: total.width, height: rect.minY - total.minY),
            CGRect(x: total.minX, y: rect.maxY, width: total.width, height: total.maxY - rect.maxY),
            CGRect(x: total.minX, y: rect.minY, width: rect.minX - total.minX, height: rect.height),
            CGRect(x: rect.maxX, y: rect.minY, width: total.maxX - rect.maxX, height: rect.height),
        ].filter { $0.width >= 1 && $0.height >= 1 }
    }

    private func totalBoundsCG() -> CGRect {
        let appKit = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        return Geometry.cgRect(fromAppKit: appKit)
    }
}

private final class ClickShieldPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}

private final class ClickShieldView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
}
