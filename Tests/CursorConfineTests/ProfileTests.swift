import XCTest
import CoreGraphics
@testable import CursorConfine

final class ProfileTests: XCTestCase {

    private func makeWindow(bundle: String, app: String, title: String, id: CGWindowID = 1) -> WindowInfo {
        WindowInfo(
            id: id, appName: app, title: title,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            pid: 100, bundleIdentifier: bundle, layer: 0, isOnScreen: true
        )
    }

    func testProfileMatchesPreferredWindowTitle() {
        let p = Profile(name: "LoL", bundleIdentifier: "com.riotgames.LeagueOfLegends",
                        appName: "League of Legends",
                        mode: .window, windowTitleHint: "League of Legends (TM) Client")
        let windows = [
            makeWindow(bundle: "com.riotgames.LeagueOfLegends", app: "League of Legends", title: "Game Patcher", id: 1),
            makeWindow(bundle: "com.riotgames.LeagueOfLegends", app: "League of Legends", title: "League of Legends (TM) Client", id: 2),
        ]
        let target = p.toTarget(matching: windows)
        XCTAssertEqual(target.mode, .window)
        XCTAssertEqual(target.windowSelection?.windowTitle, "League of Legends (TM) Client")
    }

    func testProfileFallsBackToAnyAppWindow() {
        let p = Profile(name: "LoL", bundleIdentifier: "com.riotgames.LeagueOfLegends",
                        appName: "League of Legends",
                        mode: .window, windowTitleHint: "")
        let windows = [
            makeWindow(bundle: "com.riotgames.LeagueOfLegends", app: "League of Legends", title: "Anything", id: 7)
        ]
        let target = p.toTarget(matching: windows)
        XCTAssertEqual(target.mode, .window)
        XCTAssertEqual(target.windowSelection?.windowTitle, "Anything")
    }

    func testProfileWithNoCandidateFallsBackToFocusedWindow() {
        let p = Profile(name: "Empty", bundleIdentifier: "com.nope", appName: "Nope",
                        mode: .window)
        let target = p.toTarget(matching: [])
        XCTAssertEqual(target.mode, .focusedWindow)
    }

    func testRectangleProfileCarriesRectangle() {
        let saved = SavedRect(x: 10, y: 20, width: 800, height: 600)
        let p = Profile(name: "Rect", bundleIdentifier: "com.x", appName: "X",
                        mode: .rectangle, rectangle: saved)
        let target = p.toTarget(matching: [])
        XCTAssertEqual(target.mode, .rectangle)
        XCTAssertEqual(target.rectangle, saved)
    }
}
