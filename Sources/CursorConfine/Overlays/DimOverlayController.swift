import AppKit
import SwiftUI

/// Borderless transparent window covering all displays; draws a dimmed sheet
/// with a transparent cut-out for the confinement rect.
@MainActor
final class DimOverlayController {

    private var window: NSWindow?
    private var hostingView: NSHostingView<DimOverlayView>?
    private var lastRect: CGRect?
    private var lastOpacity: Double = 0

    func show(rect: CGRect, opacity: Double) {
        let totalCG = totalBoundsCG()
        if window == nil {
            createWindow(frame: Geometry.appKitRect(fromCG: totalCG))
        }
        // Keep the window covering the whole desktop, even if displays moved.
        let windowFrameAppKit = Geometry.appKitRect(fromCG: totalCG)
        window?.setFrame(windowFrameAppKit, display: false, animate: false)

        let view = DimOverlayView(
            rect: rect,
            globalBoundsCG: totalCG,
            primaryHeightAppKit: Geometry.primaryScreenFrameAppKit().maxY,
            opacity: opacity
        )

        if let hostingView {
            hostingView.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.frame = window?.contentView?.bounds ?? .zero
            hv.autoresizingMask = [.width, .height]
            window?.contentView = hv
            hostingView = hv
        }

        lastRect = rect
        lastOpacity = opacity
        window?.orderFrontRegardless()
    }

    func hide() {
        guard window != nil else { return }
        window?.orderOut(nil)
        lastRect = nil
    }

    private func createWindow(frame: NSRect) {
        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = .screenSaver  // above normal app windows
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.alphaValue = 1.0
        window = win
    }

    private func totalBoundsCG() -> CGRect {
        // Union of all NSScreens, in CG (top-left) space.
        let appKit = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        return Geometry.cgRect(fromAppKit: appKit)
    }
}

/// SwiftUI canvas drawing the dim sheet with a transparent cut-out.
private struct DimOverlayView: View {

    let rect: CGRect            // confinement rect in CG global (top-left)
    let globalBoundsCG: CGRect  // union of displays in CG global
    let primaryHeightAppKit: CGFloat  // primary screen's maxY in AppKit; not used directly here
    let opacity: Double

    var body: some View {
        Canvas { ctx, size in
            // The hosting view's geometry runs bottom-left within `size`; the
            // confinement rect is in CG (top-left) global space relative to
            // `globalBoundsCG`. Convert by flipping Y.
            let local = CGRect(
                x: rect.origin.x - globalBoundsCG.origin.x,
                y: (globalBoundsCG.height - (rect.origin.y - globalBoundsCG.origin.y + rect.height)),
                width: rect.width,
                height: rect.height
            )
            // Draw a full-bounds dim layer, then cut out the rect using even-odd.
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRect(local)
            ctx.fill(path, with: .color(.black.opacity(opacity)), style: FillStyle(eoFill: true))
        }
        .ignoresSafeArea()
    }
}
