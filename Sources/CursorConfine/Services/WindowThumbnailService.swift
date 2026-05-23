import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Async live thumbnail capture for window-picker tiles. Requires Screen
/// Recording permission; falls back to nil if not granted.
@MainActor
final class WindowThumbnailService {

    private var cache: [CGWindowID: NSImage] = [:]
    private var inFlight: Set<CGWindowID> = []

    /// Returns a cached thumbnail synchronously if we have one, else nil.
    /// Use `requestRefresh` to (re)populate.
    func cached(_ id: CGWindowID) -> NSImage? {
        cache[id]
    }

    func clearCache() {
        cache.removeAll()
    }

    /// Kick off a capture for `windowID`. Calls `completion` on the main actor.
    /// No-op if already in flight or if Screen Recording permission missing.
    func requestRefresh(windowID: CGWindowID, maxDimension: CGFloat = 320, completion: @escaping @MainActor (NSImage?) -> Void) {
        guard #available(macOS 14.0, *) else { completion(nil); return }
        if inFlight.contains(windowID) { completion(cache[windowID]); return }
        inFlight.insert(windowID)

        Task { [weak self] in
            let image = await Self.captureThumbnail(windowID: windowID, maxDimension: maxDimension)
            await MainActor.run {
                guard let self else { return }
                self.inFlight.remove(windowID)
                if let image {
                    self.cache[windowID] = image
                }
                completion(image)
            }
        }
    }

    @available(macOS 14.0, *)
    private static func captureThumbnail(windowID: CGWindowID, maxDimension: CGFloat) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else { return nil }
            let filter = SCContentFilter(desktopIndependentWindow: window)

            let cfg = SCStreamConfiguration()
            let srcW = max(window.frame.width, 1)
            let srcH = max(window.frame.height, 1)
            let scale = min(maxDimension / srcW, maxDimension / srcH, 1.0)
            cfg.width = Int(max(64, srcW * scale))
            cfg.height = Int(max(64, srcH * scale))
            cfg.showsCursor = false
            cfg.scalesToFit = true

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cfg.width, height: cfg.height))
            return nsImage
        } catch {
            return nil
        }
    }
}
