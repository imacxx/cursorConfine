import AppKit
import SwiftUI

/// Draws a thin colored stroke around the confinement rect, mouse-transparent.
@MainActor
final class BorderOverlayController {

    private var window: NSWindow?
    private var hostingView: NSHostingView<BorderOverlayView>?

    func show(rect: CGRect, color: Color, width: CGFloat) {
        // Pad the window slightly so the stroke isn't clipped.
        let pad = max(2, width * 2)
        let outerCG = rect.insetBy(dx: -pad, dy: -pad)
        let outerAppKit = Geometry.appKitRect(fromCG: outerCG)

        if window == nil {
            createWindow(frame: outerAppKit)
        } else {
            window?.setFrame(outerAppKit, display: false, animate: false)
        }

        let view = BorderOverlayView(strokeColor: color, lineWidth: width, padding: pad)

        if let hostingView {
            hostingView.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.frame = window?.contentView?.bounds ?? .zero
            hv.autoresizingMask = [.width, .height]
            window?.contentView = hv
            hostingView = hv
        }

        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
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
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window = win
    }
}

private struct BorderOverlayView: View {
    let strokeColor: Color
    let lineWidth: CGFloat
    let padding: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let inset = padding
            let inner = CGRect(
                x: inset,
                y: inset,
                width: max(0, proxy.size.width  - inset * 2),
                height: max(0, proxy.size.height - inset * 2)
            )
            Path { p in
                p.addRect(inner)
            }
            .stroke(strokeColor, lineWidth: lineWidth)
        }
        .ignoresSafeArea()
    }
}
