import AppKit
import SwiftUI

/// Full-screen overlay that lets the user click-and-drag a rectangle to confine
/// to. ESC cancels. Calls completion with the rect in CG global (top-left).
@MainActor
final class RegionPickerController {

    private var window: NSWindow?
    private var hosting: NSHostingView<RegionPickerView>?
    private let completion: (CGRect?) -> Void

    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
    }

    func begin() {
        let totalCG = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        // We want to cover the desktop in AppKit coords (since we're using NSWindow).
        let frame = totalCG

        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.acceptsMouseMovedEvents = true

        let view = RegionPickerView { [weak self] rectAppKit, cancelled in
            guard let self else { return }
            if cancelled || rectAppKit == nil {
                self.finish(rect: nil)
            } else if let rectAppKit {
                let rectCG = Geometry.cgRect(fromAppKit: rectAppKit)
                self.finish(rect: rectCG)
            }
        }
        let hv = NSHostingView(rootView: view)
        hv.frame = win.contentView?.bounds ?? .zero
        hv.autoresizingMask = [.width, .height]
        win.contentView = hv
        hosting = hv
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(rect: CGRect?) {
        window?.orderOut(nil)
        window = nil
        hosting = nil
        completion(rect)
    }
}

private struct RegionPickerView: View {

    /// Reports (rect-in-AppKit-coords, wasCancelled).
    var onComplete: (CGRect?, Bool) -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        ZStack {
            // Background scrim.
            Color.black.opacity(0.001) // transparent but hit-test-able

            if let r = currentRect {
                // Hole in the scrim
                GeometryReader { proxy in
                    let path = Path { p in
                        p.addRect(CGRect(origin: .zero, size: proxy.size))
                        p.addRect(r)
                    }
                    path.fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))

                    Path { p in p.addRect(r) }
                        .stroke(Color.accentColor, lineWidth: 2)

                    Text("\(Int(r.width)) × \(Int(r.height))")
                        .font(.system(.callout, design: .monospaced))
                        .padding(6)
                        .background(.regularMaterial)
                        .cornerRadius(6)
                        .position(x: r.midX, y: max(20, r.minY - 16))
                }
            }

            VStack {
                Text("Drag to select a region. Press Esc to cancel.")
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    .padding(.top, 24)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    let start = dragStart ?? value.startLocation
                    let end = value.location
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    dragStart = nil
                    dragCurrent = nil
                    if rect.width >= 16 && rect.height >= 16 {
                        onComplete(rect, false)
                    } else {
                        onComplete(nil, true)
                    }
                }
        )
        .background(EscapeKeyCatcher(onEscape: { onComplete(nil, true) }))
    }

    private var currentRect: CGRect? {
        guard let s = dragStart, let c = dragCurrent else { return nil }
        return CGRect(
            x: min(s.x, c.x), y: min(s.y, c.y),
            width: abs(c.x - s.x), height: abs(c.y - s.y)
        )
    }
}

/// NSViewRepresentable that watches for the Escape key while the picker is up.
private struct EscapeKeyCatcher: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onEscape = onEscape
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyView)?.onEscape = onEscape
    }

    final class KeyView: NSView {
        var onEscape: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 /* kVK_Escape */ {
                onEscape?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
