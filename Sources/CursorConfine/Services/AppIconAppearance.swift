import AppKit
import Combine

/// macOS Dock icons don't natively switch with the system appearance
/// (`Assets.car` multi-appearance variants in mac app icon sets are
/// silently dropped by actool — only iOS apps consume `luminosity`-based
/// appearance variants). This service hand-rolls the behaviour: it loads
/// the two PNGs we bundle as Resources and swaps `NSApp.applicationIconImage`
/// whenever the effective appearance changes.
@MainActor
final class AppIconAppearance {

    private let lightImage: NSImage?
    private let darkImage: NSImage?
    private var observation: NSKeyValueObservation?
    private var lastAppliedIsDark: Bool?

    init() {
        let bundle = Bundle.main
        self.lightImage = AppIconAppearance.loadImage(named: "icon-light", from: bundle)
        self.darkImage  = AppIconAppearance.loadImage(named: "icon-dark",  from: bundle)
    }

    func start() {
        apply()
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            // KVO fires on the main run loop already, but hop explicitly to
            // make the isolation contract obvious.
            Task { @MainActor in self?.apply() }
        }
    }

    func stop() {
        observation = nil
    }

    private func apply() {
        let isDark = effectiveIsDark()
        if lastAppliedIsDark == isDark { return }  // no-op redraws cause Dock flicker
        guard let image = isDark ? (darkImage ?? lightImage) : (lightImage ?? darkImage) else {
            Log.main.error("AppIconAppearance: no icon images bundled")
            return
        }
        NSApp.applicationIconImage = image
        lastAppliedIsDark = isDark
        Log.main.info("App icon set to \(isDark ? "dark" : "light", privacy: .public) variant")
    }

    private func effectiveIsDark() -> Bool {
        let name = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return name == .darkAqua
    }

    private static func loadImage(named name: String, from bundle: Bundle) -> NSImage? {
        if let url = bundle.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }
}
