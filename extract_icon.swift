#!/usr/bin/env swift
// Extracts the dark + light icon halves from a Gemini-generated source PNG,
// scales them to 1024×1024, and (optionally) applies a soft alpha mask
// outside the squircle so the corners are transparent.
// Usage:
//   swift extract_icon.swift <source.png> <dark-out.png> <light-out.png>
import AppKit
import CoreGraphics

guard CommandLine.arguments.count >= 4 else {
    FileHandle.standardError.write(Data("usage: extract_icon.swift <source.png> <dark-out.png> <light-out.png>\n".utf8))
    exit(2)
}
let sourcePath = CommandLine.arguments[1]
let darkOut   = CommandLine.arguments[2]
let lightOut  = CommandLine.arguments[3]

guard let src = NSImage(contentsOfFile: sourcePath),
      let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write(Data("FAIL: load \(sourcePath)\n".utf8)); exit(1)
}

let W = CGFloat(srcCG.width)
let H = CGFloat(srcCG.height)
print("Source: \(Int(W)) × \(Int(H))")

// Two icons side-by-side in the source. Empirically the icon squircles sit
// near the top half, centered in their respective halves, with labels below.
// We crop a square slightly larger than the visible squircle so we capture
// the gloss + shadow halo, then resize to 1024.
let iconSide: CGFloat = H * 0.62          // ~62% of the source height
let yOriginCG = H * 0.10                  // small top margin (CG origin = top-left for cgImage)
let leftCenterX  = W * 0.25
let rightCenterX = W * 0.75

let leftRect  = CGRect(x: leftCenterX  - iconSide / 2, y: yOriginCG,
                       width: iconSide, height: iconSide)
let rightRect = CGRect(x: rightCenterX - iconSide / 2, y: yOriginCG,
                       width: iconSide, height: iconSide)

func crop(_ image: CGImage, _ rect: CGRect) -> CGImage? {
    return image.cropping(to: rect)
}

func scaleAndExportSquircle(_ image: CGImage, to size: Int, outPath: String) {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Squircle clip: macOS Big Sur+ uses corner radius ≈ 22.37% of side.
    let r = s * 0.2237
    let squircle = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                          cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle); ctx.clip()
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: s, height: s))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("FAIL: encode \(outPath)\n".utf8)); exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath) (\(png.count) bytes, \(rep.pixelsWide)×\(rep.pixelsHigh))")
}

guard let leftCG = crop(srcCG, leftRect) else {
    FileHandle.standardError.write(Data("FAIL: crop left\n".utf8)); exit(1)
}
guard let rightCG = crop(srcCG, rightRect) else {
    FileHandle.standardError.write(Data("FAIL: crop right\n".utf8)); exit(1)
}

scaleAndExportSquircle(leftCG,  to: 1024, outPath: darkOut)
scaleAndExportSquircle(rightCG, to: 1024, outPath: lightOut)
