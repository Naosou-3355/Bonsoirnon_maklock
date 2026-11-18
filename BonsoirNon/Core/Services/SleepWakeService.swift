import Foundation
import AppKit

/// Monitors system sleep/wake events and triggers auto-lock on sleep.
final class SleepWakeService {
    static let shared = SleepWakeService()

    /// Callback when the system is about to sleep.
    var onSleep: (() -> Void)?

    /// Callback when the system wakes from sleep.
    var onWake: (() -> Void)?

    private var isObserving = false

    private init() {}

    /// Begin observing sleep/wake notifications.
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Display sleep (screen turns off without the Mac sleeping)
        center.addObserver(self, selector: #selector(handleScreenLocked),
                           name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(handleScreenWake),
                           name: NSWorkspace.screensDidWakeNotification, object: nil)

        // Session lock (lock screen, screen saver with password, Ctrl+Cmd+Q)
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(handleScreenLocked),
                                name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(handleScreenUnlocked),
                                name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)

        NSLog("[BonsoirNon] Sleep/wake observer started")
    }

    /// Callback when the screen turns off or the session is locked.
    var onScreenLocked: (() -> Void)?

    /// Callback when the user is back at an unlocked, awake screen.
    var onScreenUnlocked: (() -> Void)?

    /// Whether the login window / lock screen is currently shown.
    private var isSessionLocked: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    @objc private func handleScreenLocked(_ notification: Notification) {
        NSLog("[BonsoirNon] Screen locked or asleep (%@)", notification.name.rawValue)
        onScreenLocked?()
    }

    @objc private func handleScreenWake(_ notification: Notification) {
        // If the lock screen is up, wait for screenIsUnlocked instead.
        guard !isSessionLocked else { return }
        NSLog("[BonsoirNon] Screen woke without lock screen")
        onScreenUnlocked?()
    }

    @objc private func handleScreenUnlocked(_ notification: Notification) {
        NSLog("[BonsoirNon] Screen unlocked")
        onScreenUnlocked?()
    }

    /// Stop observing sleep/wake notifications.
    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NSLog("[BonsoirNon] Sleep/wake observer stopped")
    }

    // MARK: - Handlers

    @objc private func handleSleep(_ notification: Notification) {
        NSLog("[BonsoirNon] System going to sleep")
        onSleep?()
    }

    @objc private func handleWake(_ notification: Notification) {
        NSLog("[BonsoirNon] System woke from sleep")
        onWake?()
    }
}
