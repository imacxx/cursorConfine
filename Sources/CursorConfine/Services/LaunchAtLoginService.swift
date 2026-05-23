import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService.mainApp (macOS 13+).
@MainActor
final class LaunchAtLoginService {

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        let svc = SMAppService.mainApp
        if enabled {
            if svc.status != .enabled {
                try svc.register()
            }
        } else {
            if svc.status == .enabled {
                try svc.unregister()
            }
        }
    }
}
