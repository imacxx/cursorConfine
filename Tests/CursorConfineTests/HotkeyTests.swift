import XCTest
import Carbon.HIToolbox
@testable import CursorConfine

final class HotkeyTests: XCTestCase {

    func testUnsetDescription() {
        XCTAssertEqual(Hotkey.unset.description, "Unset")
        XCTAssertFalse(Hotkey.unset.isSet)
    }

    func testDefaultToggleHotkey() {
        let h = Hotkey.defaultToggle
        XCTAssertTrue(h.isSet)
        XCTAssertEqual(h.keyCode, UInt32(kVK_ANSI_L))
        XCTAssertTrue(h.modifiers & UInt32(controlKey) != 0)
        XCTAssertTrue(h.modifiers & UInt32(optionKey)  != 0)
        XCTAssertTrue(h.description.contains("⌃"))
        XCTAssertTrue(h.description.contains("⌥"))
        XCTAssertTrue(h.description.contains("L"))
    }

    func testPanicHotkeyIncludesShiftAndEscape() {
        let h = Hotkey.defaultPanic
        XCTAssertTrue(h.modifiers & UInt32(shiftKey) != 0)
        XCTAssertEqual(h.keyCode, UInt32(kVK_Escape))
        XCTAssertTrue(h.description.contains("⎋"))
    }

    func testCodableRoundTrip() throws {
        let h = Hotkey(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey | shiftKey))
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(Hotkey.self, from: data)
        XCTAssertEqual(decoded, h)
    }
}
