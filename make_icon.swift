#!/usr/bin/env swift
// Renders the CursorConfine app icon as a 1024×1024 PNG using CoreGraphics.
// Usage: swift make_icon.swift <mode> <output-path>
//   <mode>: light | dark | tinted
//
// "light" / "dark" produce colored variants. "tinted" produces a luminance
// map (dark background, light foreground) that macOS Sequoia+ uses as the
// source for system-tint-coloured icons.
import AppKit
import CoreGraphics

let SIZE: CGFloat = 1024

enum Mode: String { case light, dark, tinted }

struct Palette {
    let bgTopLeft:     NSColor
    let bgBottomRight: NSColor
    let highlight:     NSColor    // soft radial highlight in the upper-left
    let bracket:       NSColor
    let cursorFill:    NSColor
    let cursorStroke:  NSColor

    static let light = Palette(
        bgTopLeft:     NSColor(red: 0.26, green: 0.52, blue: 1.00, alpha: 1.00),
        bgBottomRight: NSColor(red: 0.04, green: 0.10, blue: 0.45, alpha: 1.00),
        highlight:     NSColor(white: 1.0, alpha: 0.30),
        bracket:       NSColor(white: 1.0, alpha: 0.96),
        cursorFill:    NSColor(white: 1.0, alpha: 1.00),
        cursorStroke:  NSColor(white: 0.0, alpha: 0.18)
    )

    static let dark = Palette(
        bgTopLeft:     NSColor(red: 0.16, green: 0.20, blue: 0.42, alpha: 1.00),
        bgBottomRight: NSColor(red: 0.02, green: 0.03, blue: 0.12, alpha: 1.00),
        highlight:     NSColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 0.22),
        bracket:       NSColor(red: 0.78, green: 0.90, blue: 1.00, alpha: 0.98),
        cursorFill:    NSColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1.00),
        cursorStroke:  NSColor(red: 0.10, green: 0.18, blue: 0.40, alpha: 0.35)
    )

    /// Luminance-keyed: dark base → stays dark, light foreground → picks up
    /// the system tint color. No saturation.
    static let tinted = Palette(
        bgTopLeft:     NSColor(white: 0.16, alpha: 1.00),
        bgBottomRight: NSColor(white: 0.04, alpha: 1.00),
        highlight:     NSColor(white: 1.0,  alpha: 0.08),
        bracket:       NSColor(white: 1.0,  alpha: 1.00),
        cursorFill:    NSColor(white: 1.0,  alpha: 1.00),
        cursorStroke:  NSColor(white: 0.0,  alpha: 0.0)   // none
    )
}

func makeIcon(palette p: Palette) -> NSBitmapImageRep {
    // Render straight into a bitmap rep at the exact pixel size. Using
    // NSImage.lockFocus would multiply by the screen backing-scale factor
    // (2x on Retina) and we'd end up with a 2048×2048 master.
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(SIZE),
        pixelsHigh: Int(SIZE),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: SIZE, height: SIZE)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // 1) Squircle background with diagonal gradient.
    let bgRect = CGRect(x: 0, y: 0, width: SIZE, height: SIZE)
    let radius = SIZE * 0.2237  // macOS Big Sur+ icon corner-radius ratio
    let bgPath = CGPath(roundedRect: bgRect,
                        cornerWidth: radius, cornerHeight: radius,
                        transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()

    let space = CGColorSpaceCreateDeviceRGB()
    let colors: [CGColor] = [p.bgTopLeft.cgColor, p.bgBottomRight.cgColor]
    let gradient = CGGradient(colorsSpace: space,
                              colors: colors as CFArray,
                              locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: SIZE),
                           end:   CGPoint(x: SIZE, y: 0),
                           options: [])

    // Subtle radial highlight, upper-left, for depth.
    let highlightColors: [CGColor] = [
        p.highlight.cgColor,
        p.highlight.withAlphaComponent(0).cgColor
    ]
    if let radial = CGGradient(colorsSpace: space,
                               colors: highlightColors as CFArray,
                               locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(radial,
                               startCenter: CGPoint(x: SIZE * 0.30, y: SIZE * 0.78),
                               startRadius: 0,
                               endCenter:   CGPoint(x: SIZE * 0.30, y: SIZE * 0.78),
                               endRadius:   SIZE * 0.60,
                               options: [])
    }
    ctx.restoreGState()

    // 2) White corner-bracket "viewfinder" — the confinement metaphor.
    let inset      = SIZE * 0.175
    let armLen     = SIZE * 0.20
    let thickness  = SIZE * 0.045
    let bRadius    = thickness * 0.5

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4),
                  blur: 12,
                  color: NSColor.black.withAlphaComponent(0.30).cgColor)
    ctx.setFillColor(p.bracket.cgColor)

    func bracket(corner: CGPoint, dx: CGFloat, dy: CGFloat) {
        // AppKit context: origin is bottom-left, Y grows up.
        let hX = dx > 0 ? corner.x : corner.x - armLen
        let hY = corner.y - thickness / 2
        let hRect = CGRect(x: hX, y: hY, width: armLen, height: thickness)

        let vX = corner.x - thickness / 2
        let vY = dy > 0 ? corner.y : corner.y - armLen
        let vRect = CGRect(x: vX, y: vY, width: thickness, height: armLen)

        ctx.addPath(CGPath(roundedRect: hRect,
                           cornerWidth: bRadius, cornerHeight: bRadius, transform: nil))
        ctx.fillPath()
        ctx.addPath(CGPath(roundedRect: vRect,
                           cornerWidth: bRadius, cornerHeight: bRadius, transform: nil))
        ctx.fillPath()
    }
    bracket(corner: CGPoint(x: inset,        y: SIZE - inset), dx: +1, dy: -1)
    bracket(corner: CGPoint(x: SIZE - inset, y: SIZE - inset), dx: -1, dy: -1)
    bracket(corner: CGPoint(x: inset,        y: inset),        dx: +1, dy: +1)
    bracket(corner: CGPoint(x: SIZE - inset, y: inset),        dx: -1, dy: +1)
    ctx.restoreGState()

    // 3) Cursor arrow, centered, with subtle drop shadow.
    let cursorH: CGFloat = SIZE * 0.52
    let local: [(CGFloat, CGFloat)] = [
        (0,  0),    // tip
        (0,  22),   // bottom-left of body
        (6,  17),   // kink
        (10, 27),   // tail outer-left
        (14, 25),   // tail outer-right
        (10, 15),   // tail base inner
        (17, 12),   // right edge of body
    ]
    let localW: CGFloat = 17
    let localH: CGFloat = 27
    let scale = cursorH / localH

    let cursorPath = CGMutablePath()
    cursorPath.move(to: CGPoint(x: local[0].0, y: local[0].1))
    for pt in local.dropFirst() {
        cursorPath.addLine(to: CGPoint(x: pt.0, y: pt.1))
    }
    cursorPath.closeSubpath()

    ctx.saveGState()
    let cx = SIZE * 0.5
    let cy = SIZE * 0.5
    ctx.translateBy(x: cx - localW * scale * 0.5,
                    y: cy + localH * scale * 0.5)
    ctx.scaleBy(x: scale, y: -scale)

    ctx.setShadow(offset: CGSize(width: 0, height: 10 / scale),
                  blur: 30 / scale,
                  color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.setFillColor(p.cursorFill.cgColor)
    ctx.addPath(cursorPath); ctx.fillPath()

    if p.cursorStroke.alphaComponent > 0 {
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setStrokeColor(p.cursorStroke.cgColor)
        ctx.setLineWidth(0.6)
        ctx.setLineJoin(.round)
        ctx.addPath(cursorPath); ctx.strokePath()
    }
    ctx.restoreGState()

    return rep
}

guard CommandLine.arguments.count >= 3,
      let mode = Mode(rawValue: CommandLine.arguments[1])
else {
    FileHandle.standardError.write(Data("usage: swift make_icon.swift <light|dark|tinted> <output.png>\n".utf8))
    exit(2)
}
let outPath = CommandLine.arguments[2]
let palette: Palette = {
    switch mode {
    case .light:  return .light
    case .dark:   return .dark
    case .tinted: return .tinted
    }
}()

let rep = makeIcon(palette: palette)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("FAIL: png encode\n".utf8)); exit(1)
}
let outURL = URL(fileURLWithPath: outPath)
try pngData.write(to: outURL)
print("Wrote \(outURL.path) (\(pngData.count) bytes, mode=\(mode), \(rep.pixelsWide)×\(rep.pixelsHigh))")
