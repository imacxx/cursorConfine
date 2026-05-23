import Foundation
import AppKit
import CoreGraphics
import IOKit

struct DisplayInfo: Identifiable, Hashable, Sendable {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let boundsCG: CGRect   // top-left global
}

/// Lists displays and resolves a saved displayUUID to its current bounds.
@MainActor
final class DisplayService {

    func enumerate() -> [DisplayInfo] {
        var count: UInt32 = 0
        var err = CGGetOnlineDisplayList(0, nil, &count)
        if err != .success || count == 0 { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        err = CGGetOnlineDisplayList(count, &ids, &count)
        if err != .success { return [] }

        return ids.map { id in
            DisplayInfo(
                id: id,
                uuid: Self.uuid(for: id),
                name: Self.displayName(for: id),
                boundsCG: CGDisplayBounds(id)
            )
        }
    }

    func resolve(uuid: String) -> DisplayInfo? {
        enumerate().first(where: { $0.uuid == uuid })
    }

    static func uuid(for id: CGDirectDisplayID) -> String {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return String(id)
        }
        return CFUUIDCreateString(nil, cfUUID) as String
    }

    static func displayName(for id: CGDirectDisplayID) -> String {
        if let mainID = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           mainID == id {
            return NSScreen.main?.localizedName ?? "Main Display"
        }
        for screen in NSScreen.screens {
            if let sid = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID, sid == id {
                return screen.localizedName
            }
        }
        return "Display \(id)"
    }
}
