import Foundation
import AppKit
@preconcurrency import UserNotifications

/// Plays subtle system sounds and posts user notifications for lock/unlock events.
@MainActor
final class SoundNotificationService {

    private var notificationsAuthorized = false

    func requestNotificationAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        Task { @MainActor in
            do {
                let settings = await center.notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound])
                    self.notificationsAuthorized = granted
                } else {
                    self.notificationsAuthorized = (settings.authorizationStatus == .authorized)
                }
            } catch {
                self.notificationsAuthorized = false
            }
        }
    }

    func playLockSound() {
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    func playUnlockSound() {
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { _ in }
    }
}
