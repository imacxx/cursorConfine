import Foundation
import os

/// Thin wrapper around `os.Logger` so the rest of the code does not have to know
/// about subsystems.
enum Log {
    static let main      = Logger(subsystem: "com.cursorconfine.app", category: "main")
    static let engine    = Logger(subsystem: "com.cursorconfine.app", category: "engine")
    static let windows   = Logger(subsystem: "com.cursorconfine.app", category: "windows")
    static let focus     = Logger(subsystem: "com.cursorconfine.app", category: "focus")
    static let hotkey    = Logger(subsystem: "com.cursorconfine.app", category: "hotkey")
    static let perms     = Logger(subsystem: "com.cursorconfine.app", category: "permissions")
    static let profiles  = Logger(subsystem: "com.cursorconfine.app", category: "profiles")
    static let overlay   = Logger(subsystem: "com.cursorconfine.app", category: "overlay")
}
