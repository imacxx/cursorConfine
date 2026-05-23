#!/usr/bin/env swift
// Convert a source PNG (the dark icon) into a luminance-keyed grayscale
// variant suitable for macOS Sequoia+ "tinted" app icons. The system uses
// pixel brightness as the alpha for the user's accent color, so:
//   – bright pixels (cursor)        → tinted to accent
//   – dark pixels (window chrome)   → stay dark
// Squircle mask is preserved from the source.
// Usage: swift make_tinted.swift <source.png> <out.png>
import AppKit
import CoreGraphics

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make_tinted.swift <source.png> <out.png>\n".utf8))
    exit(2)
}
let inPath  = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

guard let src = NSImage(contentsOfFile: inPath),
      let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write(Data("FAIL: load \(inPath)\n".utf8)); exit(1)
}

let SIZE = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: SIZE, pixelsHigh: SIZE,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: SIZE, height: SIZE)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Use a CoreImage grayscale filter to desaturate.
let ciImage = CIImage(cgImage: srcCG)
let grayFilter = CIFilter(name: "CIColorControls")!
grayFilter.setValue(ciImage,  forKey: kCIInputImageKey)
grayFilter.setValue(0.0,      forKey: kCIInputSaturationKey)
grayFilter.setValue(0.0,      forKey: kCIInputBrightnessKey)
grayFilter.setValue(1.0,      forKey: kCIInputContrastKey)
let ciContext = CIContext()
guard let outCI = grayFilter.outputImage,
      let grayCG = ciContext.createCGImage(outCI, from: ciImage.extent)
else {
    FileHandle.standardError.write(Data("FAIL: desaturate\n".utf8)); exit(1)
}

ctx.draw(grayCG, in: CGRect(x: 0, y: 0, width: SIZE, height: SIZE))
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("FAIL: png encode\n".utf8)); exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) (\(png.count) bytes, grayscale tint source)")
