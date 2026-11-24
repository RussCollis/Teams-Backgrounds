import Foundation

/// UserDefaults keys for the PKG identifier and signing identity.
///
/// "Default" values are set in Settings. "Last" values are what was typed in the
/// main window, saved as they change so the next launch can pick them up.
nonisolated enum PreferenceKey {
    static let rememberLastSession = "rememberLastSession"
    static let defaultPackageIdentifier = "defaultPackageIdentifier"
    static let defaultSigningIdentity = "defaultSigningIdentity"
    static let lastPackageIdentifier = "lastPackageIdentifier"
    static let lastSigningIdentity = "lastSigningIdentity"

    static let fallbackPackageIdentifier = "com.company.teams-backgrounds"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [rememberLastSession: true])
    }

    /// The value a new window starts with: the last-used value when remembering is on,
    /// otherwise the Settings default, otherwise `fallback`.
    static func startingValue(last lastKey: String, default defaultKey: String, fallback: String, in defaults: UserDefaults = .standard) -> String {
        if defaults.bool(forKey: rememberLastSession),
           let last = defaults.string(forKey: lastKey), !last.isEmpty {
            return last
        }
        if let value = defaults.string(forKey: defaultKey), !value.isEmpty {
            return value
        }
        return fallback
    }

    /// Forgets the values saved from the last session.
    static func clearLastSession(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastPackageIdentifier)
        defaults.removeObject(forKey: lastSigningIdentity)
    }
}
