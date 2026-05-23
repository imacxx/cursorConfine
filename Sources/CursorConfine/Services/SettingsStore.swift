import Foundation
import Observation

/// Owns the persisted `Settings` document. Writes are debounced via UserDefaults.
@MainActor
@Observable
final class SettingsStore {

    private static let key = "CursorConfine.Settings.v1"

    var settings: Settings {
        didSet { scheduleSave() }
    }

    private var saveWorkItem: DispatchWorkItem?

    init() {
        if let data = UserDefaults.standard.data(forKey: SettingsStore.key),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .defaults
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.save()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Force an immediate flush (used on app quit).
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: SettingsStore.key)
        } catch {
            Log.main.error("Failed to encode settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
