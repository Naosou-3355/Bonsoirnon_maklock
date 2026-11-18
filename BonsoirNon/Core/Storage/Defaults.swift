import Foundation

/// Centralized settings storage.
///
/// The protected-apps list and the app settings live in the Keychain, not in
/// UserDefaults: `defaults write com.bonsoirnon.app …` from Terminal (which can
/// never be locked) must not be able to empty the list or turn protection off.
/// Values are cached in memory; the Keychain is read once at launch.
/// Older installs are migrated from UserDefaults on first launch.
final class Defaults {
    static let shared = Defaults()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key: String {
        case protectedApps
        case appSettings
        case hasCompletedOnboarding
        case backupPasswordSet
    }

    /// Keychain accounts holding the secured values.
    private enum SecureKey: String {
        case protectedApps = "protected-apps"
        case appSettings = "app-settings"
    }

    private var cachedApps: [ProtectedApp]
    private var cachedSettings: AppSettings

    private init() {
        cachedApps = []
        cachedSettings = AppSettings()
        cachedApps = load([ProtectedApp].self, secure: .protectedApps, legacy: .protectedApps) ?? []
        cachedSettings = load(AppSettings.self, secure: .appSettings, legacy: .appSettings) ?? AppSettings()
    }

    /// Read from the Keychain; if absent, migrate the old UserDefaults value once.
    private func load<T: Codable>(_ type: T.Type, secure: SecureKey, legacy: Key) -> T? {
        if let data = keychain.data(forAccount: secure.rawValue) {
            return try? decoder.decode(type, from: data)
        }
        guard let data = defaults.data(forKey: legacy.rawValue),
              let value = try? decoder.decode(type, from: data) else { return nil }
        if keychain.setData(data, forAccount: secure.rawValue) {
            defaults.removeObject(forKey: legacy.rawValue)
            NSLog("[BonsoirNon] Migrated %@ from UserDefaults to the Keychain", legacy.rawValue)
        }
        return value
    }

    private func store<T: Codable>(_ value: T, secure: SecureKey) {
        guard let data = try? encoder.encode(value) else { return }
        if !keychain.setData(data, forAccount: secure.rawValue) {
            NSLog("[BonsoirNon] Failed to save %@ to the Keychain", secure.rawValue)
        }
    }

    // MARK: - Protected Apps

    /// Persisted list of protected applications.
    var protectedApps: [ProtectedApp] {
        get { cachedApps }
        set {
            cachedApps = newValue
            store(newValue, secure: .protectedApps)
        }
    }

    // MARK: - App Settings

    /// User preferences for BonsoirNon behavior.
    var appSettings: AppSettings {
        get { cachedSettings }
        set {
            cachedSettings = newValue
            store(newValue, secure: .appSettings)
        }
    }

    // MARK: - Flags

    /// Whether the user has completed first-launch onboarding.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    /// Whether a backup password has been configured.
    var isBackupPasswordSet: Bool {
        get { defaults.bool(forKey: Key.backupPasswordSet.rawValue) }
        set { defaults.set(newValue, forKey: Key.backupPasswordSet.rawValue) }
    }
}
