import Foundation
import AppKit

/// Observes screensaver/lock/sleep notifications so the engine can pause/resume.
@MainActor
final class ScreenSaverMonitor {

    private(set) var isScreenSaverActive = false
    private(set) var isScreenLocked = false

    var onChange: (@MainActor () -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()

        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstart"),
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenSaverActive = true
                self?.onChange?()
            }
        })
        observers.append(dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstop"),
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenSaverActive = false
                self?.onChange?()
            }
        })
        observers.append(dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = true
                self?.onChange?()
            }
        })
        observers.append(dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = false
                self?.onChange?()
            }
        })

        let wsnc = NSWorkspace.shared.notificationCenter
        observers.append(wsnc.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = true
                self?.onChange?()
            }
        })
        observers.append(wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = false
                self?.onChange?()
            }
        })
    }

    func stop() {
        for obs in observers {
            DistributedNotificationCenter.default().removeObserver(obs)
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
    }
}
