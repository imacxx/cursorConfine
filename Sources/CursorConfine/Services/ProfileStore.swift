import Foundation

/// Profile lookup + matching helpers. The list of profiles itself lives in
/// `Settings.profiles`; this service is the read-side logic.
@MainActor
final class ProfileStore {

    private unowned let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    var profiles: [Profile] { settingsStore.settings.profiles }

    /// First profile that matches `bundleID` and has `autoActivate == true`.
    /// nil if no rule applies.
    func profile(for bundleID: String?) -> Profile? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return profiles.first { $0.bundleIdentifier == bundleID && $0.autoActivate }
    }

    func add(_ profile: Profile) {
        var s = settingsStore.settings
        s.profiles.append(profile)
        settingsStore.settings = s
    }

    func update(_ profile: Profile) {
        var s = settingsStore.settings
        if let idx = s.profiles.firstIndex(where: { $0.id == profile.id }) {
            s.profiles[idx] = profile
            settingsStore.settings = s
        }
    }

    func remove(id: UUID) {
        var s = settingsStore.settings
        s.profiles.removeAll(where: { $0.id == id })
        settingsStore.settings = s
    }
}
