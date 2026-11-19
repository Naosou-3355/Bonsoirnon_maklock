import Foundation

/// Persisted user preferences.
struct AppSettings: Codable {
    /// Whether BonsoirNon protection is globally active.
    var isProtectionEnabled: Bool = true

    /// Lock apps when the Mac goes to sleep.
    var lockOnSleep: Bool = true

    /// Lock apps after idle timeout.
    var lockOnIdle: Bool = false

    /// Idle timeout in minutes before auto-lock triggers.
    var idleTimeoutMinutes: Int = 5

    /// Require authentication when a protected app is launched.
    var requireAuthOnLaunch: Bool = true

    /// Legacy "Require authentication on app switch" (replaced by `relockDelay`,
    /// kept only to migrate older settings).
    var requireAuthOnActivate: Bool = true

    /// Seconds after leaving an unlocked app before it asks again:
    /// 0 = as soon as you leave it, `RelockDelay.never` = only on quit/sleep/idle/Watch.
    var relockDelay: Int = 0

    /// Use Apple Watch proximity for auto-unlock.
    var useWatchUnlock: Bool = false

    /// Watch RSSI threshold for proximity detection.
    /// Default: -70 dBm (~2-3 meters). Higher (less negative) = stricter.
    var watchRssiThreshold: Int = -70

    /// Inactivity timeout (minutes) before auto-closing protected apps that have autoClose enabled.
    var inactiveCloseMinutes: Int = 15

    /// Launch BonsoirNon at login.
    var launchAtLogin: Bool = false

    init() {}

    /// Tolerant decoding: a missing key keeps its default instead of failing the
    /// whole decode (which would silently reset every setting after an update).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        isProtectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .isProtectionEnabled) ?? d.isProtectionEnabled
        lockOnSleep = try c.decodeIfPresent(Bool.self, forKey: .lockOnSleep) ?? d.lockOnSleep
        lockOnIdle = try c.decodeIfPresent(Bool.self, forKey: .lockOnIdle) ?? d.lockOnIdle
        idleTimeoutMinutes = try c.decodeIfPresent(Int.self, forKey: .idleTimeoutMinutes) ?? d.idleTimeoutMinutes
        requireAuthOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .requireAuthOnLaunch) ?? d.requireAuthOnLaunch
        requireAuthOnActivate = try c.decodeIfPresent(Bool.self, forKey: .requireAuthOnActivate) ?? d.requireAuthOnActivate
        // Older settings: "app switch" on = immediately, off = never.
        relockDelay = try c.decodeIfPresent(Int.self, forKey: .relockDelay)
            ?? (requireAuthOnActivate ? 0 : RelockDelay.never)
        useWatchUnlock = try c.decodeIfPresent(Bool.self, forKey: .useWatchUnlock) ?? d.useWatchUnlock
        watchRssiThreshold = try c.decodeIfPresent(Int.self, forKey: .watchRssiThreshold) ?? d.watchRssiThreshold
        inactiveCloseMinutes = try c.decodeIfPresent(Int.self, forKey: .inactiveCloseMinutes) ?? d.inactiveCloseMinutes
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    }
}
