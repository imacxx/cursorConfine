import XCTest
@testable import CursorConfine

final class SettingsCodableTests: XCTestCase {

    func testDefaultsRoundTrip() throws {
        let s = Settings.defaults
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, s)
    }

    func testCustomSettingsRoundTrip() throws {
        var s = Settings.defaults
        s.edgeInset = 12
        s.dimOverlayOpacity = 0.42
        s.borderColor = ColorRGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        s.profiles.append(Profile(
            name: "League",
            bundleIdentifier: "com.riotgames.LeagueOfLegends",
            appName: "League of Legends",
            mode: .window,
            windowTitleHint: "League of Legends (TM) Client"
        ))

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}
