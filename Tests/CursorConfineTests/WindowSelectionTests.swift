import XCTest
import CoreGraphics
@testable import CursorConfine

final class WindowSelectionTests: XCTestCase {

    private func makeWindow(bundle: String?, app: String, title: String, id: CGWindowID = 1) -> WindowInfo {
        WindowInfo(
            id: id,
            appName: app,
            title: title,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            pid: 100,
            bundleIdentifier: bundle,
            layer: 0,
            isOnScreen: true
        )
    }

    func testBundleIDExactMatchWinsOverAppName() {
        let sel = WindowSelection(bundleIdentifier: "com.example.app", appName: "Other", windowTitle: "Doc")
        let w1 = makeWindow(bundle: "com.example.app", app: "Other", title: "Doc")
        XCTAssertGreaterThan(sel.matchScore(against: w1), 0)
    }

    func testNoBundleFallsBackToAppName() {
        let sel = WindowSelection(bundleIdentifier: nil, appName: "MyApp", windowTitle: "Foo")
        let w = makeWindow(bundle: nil, app: "MyApp", title: "Foo")
        XCTAssertGreaterThan(sel.matchScore(against: w), 0)
    }

    func testDifferentAppReturnsZero() {
        let sel = WindowSelection(bundleIdentifier: "com.a", appName: "A", windowTitle: "Doc")
        let w = makeWindow(bundle: "com.b", app: "B", title: "Doc")
        XCTAssertEqual(sel.matchScore(against: w), 0)
    }

    func testTitleExactMatchScoresHigherThanSubstring() {
        let sel = WindowSelection(bundleIdentifier: "com.a", appName: "A", windowTitle: "Game Window")
        let exact = makeWindow(bundle: "com.a", app: "A", title: "Game Window", id: 1)
        let sub   = makeWindow(bundle: "com.a", app: "A", title: "Game Window — Patch 14.1", id: 2)
        XCTAssertGreaterThan(sel.matchScore(against: exact), sel.matchScore(against: sub))
    }
}
