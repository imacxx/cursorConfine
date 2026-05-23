import Foundation

enum ConfinementMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case window           // a specific window, tracked by selection
    case focusedWindow    // whatever window is frontmost
    case rectangle        // a fixed rect in global screen coords
    case display          // an entire display

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .window:        return "Specific Window"
        case .focusedWindow: return "Active Window"
        case .rectangle:     return "Custom Region"
        case .display:       return "Whole Display"
        }
    }

    var symbolName: String {
        switch self {
        case .window:        return "macwindow"
        case .focusedWindow: return "rectangle.on.rectangle"
        case .rectangle:     return "rectangle.dashed"
        case .display:       return "display"
        }
    }
}
