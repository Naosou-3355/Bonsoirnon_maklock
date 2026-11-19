import AppKit
import UserNotifications

/// Application delegate responsible for lifecycle and menu bar setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()

    /// Set when quitting is legitimate: menu Quit (authenticated), logout, shutdown.
    private static var terminationAuthorized = false

    /// Quit for real (the only path the keep-alive agent does not undo).
    static func terminateAuthorized() {
        terminationAuthorized = true
        NSApp.terminate(nil)
    }

    /// Refuse quit requests that don't come from our menu: Activity Monitor's
    /// "Quit", `osascript -e 'quit app …'`, Cmd+Q. They exit cleanly, so the
    /// keep-alive agent would not relaunch the app. Force Quit still works and
    /// is relaunched by launchd.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.terminationAuthorized || SafetyManager.isDevMode {
            return .terminateNow
        }
        NSLog("[BonsoirNon] Blocked a quit request that did not come from the menu")
        return .terminateCancel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched by hand while the launchd agent is in charge: let it run instead.
        if KeepAliveService.shared.handOverIfNeeded() {
            exit(0)
        }

        // Logout / restart / shutdown must not be blocked by applicationShouldTerminate.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { _ in
            Self.terminationAuthorized = true
        }

        menuBarController.setup()

        // Request notification permission (for Watch unlock notifications)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()

        // Initialize safety manager and wire up panic key
        SafetyManager.shared.onPanicKeyPressed = { [weak self] in
            OverlayWindowService.shared.dismissAll()
            self?.menuBarController.iconState = .idle
        }

        // Initialize settings window controller (listens for openSettings notification)
        _ = SettingsWindowController.shared

        // Wire up app monitor → overlay
        AppMonitorService.shared.onProtectedAppDetected = { [weak self] app in
            // Auto-unlock if Watch is in range AND unlocked (on wrist).
            // If Watch is nearby but locked/off wrist, fall through to Touch ID.
            let watchCanUnlock = Defaults.shared.appSettings.useWatchUnlock
                && WatchProximityService.shared.canAutoUnlock
            if watchCanUnlock {
                AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
                WatchUnlockToast.shared.show(for: app.bundleIdentifier)
                Self.sendWatchUnlockNotification(appName: app.name)
                return
            }
            OverlayWindowService.shared.show(for: app)
            self?.menuBarController.iconState = .locked
        }

        // Update icon when overlay is dismissed after successful auth
        OverlayWindowService.shared.onUnlocked = { [weak self] appName in
            self?.menuBarController.iconState = .active
            Self.sendUnlockNotification(appName: appName)
        }

        // Start Watch proximity BEFORE app monitoring so Watch has time to connect.
        // This prevents false overlay triggers on app restart.
        if Defaults.shared.appSettings.useWatchUnlock {
            WatchProximityService.shared.startScanning()
        }

        // Start monitoring right away: after a relaunch (Force Quit, crash), already
        // open protected apps must be covered at once. If the Watch is on the wrist,
        // it dismisses the overlay as soon as it connects (onWatchInRange).
        AppMonitorService.shared.startMonitoring()

        // Start auto-close monitoring if any protected app has auto-close enabled
        if ProtectedAppsManager.shared.apps.contains(where: { $0.autoClose }) {
            AppInactivityService.shared.startMonitoring()
        }

        // Wire up idle monitor → lock/close all running protected apps
        IdleMonitorService.shared.onIdleTimeoutReached = { [weak self] in
            self?.lockOrCloseProtectedApps()
        }

        // Start idle monitoring if enabled
        if Defaults.shared.appSettings.lockOnIdle {
            IdleMonitorService.shared.startMonitoring()
        }

        // Wire up sleep → close autoClose apps, lock others if lockOnSleep enabled
        SleepWakeService.shared.onSleep = { [weak self] in
            self?.lockOrCloseProtectedApps(showOverlays: Defaults.shared.appSettings.lockOnSleep)
        }

        // On wake, terminate any auto-close apps that survived sleep
        // and dismiss their overlays if any were shown
        SleepWakeService.shared.onWake = { [weak self] in
            self?.terminateAutoCloseApps()
        }

        // Screen off / session locked → forget every unlock; the user must
        // authenticate again when they come back.
        SleepWakeService.shared.onScreenLocked = {
            guard Defaults.shared.appSettings.lockOnSleep else { return }
            AppMonitorService.shared.clearAllAuthentications()
        }

        // Back at the screen → lock the protected app that is in front (it won't
        // get a fresh activation event). Others lock when they are next activated.
        SleepWakeService.shared.onScreenUnlocked = { [weak self] in
            guard Defaults.shared.appSettings.lockOnSleep else { return }
            self?.lockFrontmostProtectedApp()
        }

        // Start sleep/wake observer
        SleepWakeService.shared.startObserving()

        // Wire up Watch proximity → auto-unlock when Watch returns in range
        WatchProximityService.shared.onWatchInRange = { [weak self] in
            guard OverlayWindowService.shared.isShowing else { return }
            // Only auto-unlock if Watch is on wrist (unlocked)
            guard WatchProximityService.shared.canAutoUnlock else { return }
            let lockedBundleID = OverlayWindowService.shared.currentBundleIdentifier
            let lockedAppName = OverlayWindowService.shared.currentAppName
            OverlayWindowService.shared.hide()
            WatchUnlockToast.shared.show(for: lockedBundleID)
            Self.sendWatchUnlockNotification(appName: lockedAppName ?? "app")
            self?.menuBarController.iconState = .active
        }

        // Wire up Watch proximity → lock/close when Watch leaves range
        WatchProximityService.shared.onWatchOutOfRange = { [weak self] in
            self?.lockOrCloseProtectedApps()
        }

    }

    // MARK: - Lock / Close Helpers

    /// Lock or close all running protected apps.
    /// Apps with autoClose → forceTerminate. Others → overlay (if showOverlays is true).
    private func lockOrCloseProtectedApps(showOverlays: Bool = true) {
        AppMonitorService.shared.clearAllAuthentications()
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
        let apps = ProtectedAppsManager.shared.apps.filter {
            $0.isEnabled && runningBundleIDs.contains($0.bundleIdentifier)
        }

        var showedOverlay = false
        for app in apps {
            if app.autoClose && !SafetyManager.isBlacklisted(app.bundleIdentifier) {
                if let running = NSWorkspace.shared.runningApplications.first(where: {
                    $0.bundleIdentifier == app.bundleIdentifier
                }) {
                    running.forceTerminate()
                    NSLog("[BonsoirNon] Auto-closed: %@ (%@)", app.name, app.bundleIdentifier)
                }
            } else if showOverlays {
                OverlayWindowService.shared.show(for: app)
                showedOverlay = true
            }
        }

        if showedOverlay {
            menuBarController.iconState = .locked
        }
    }

    /// Show the overlay for the frontmost app if it is protected and not unlocked.
    private func lockFrontmostProtectedApp() {
        guard Defaults.shared.appSettings.isProtectionEnabled,
              !OverlayWindowService.shared.isShowing,
              let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              !SafetyManager.isBlacklisted(bundleID),
              !AppMonitorService.shared.isAuthenticated(bundleID),
              let app = ProtectedAppsManager.shared.apps.first(where: {
                  $0.bundleIdentifier == bundleID && $0.isEnabled
              })
        else { return }

        NSLog("[BonsoirNon] Re-locking frontmost app after screen lock: %@", bundleID)
        OverlayWindowService.shared.show(for: app)
        menuBarController.iconState = .locked
    }

    /// Terminate any running auto-close apps (safety net for wake from sleep).
    /// Also dismisses overlay if it's showing for an auto-close app.
    private func terminateAutoCloseApps() {
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
        let autoCloseApps = ProtectedAppsManager.shared.apps.filter {
            $0.isEnabled && $0.autoClose && runningBundleIDs.contains($0.bundleIdentifier)
        }

        for app in autoCloseApps {
            guard !SafetyManager.isBlacklisted(app.bundleIdentifier) else { continue }

            // Dismiss overlay if it's showing for this app
            if OverlayWindowService.shared.currentBundleIdentifier == app.bundleIdentifier {
                OverlayWindowService.shared.dismissAll()
            }

            if let running = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == app.bundleIdentifier
            }) {
                running.forceTerminate()
                AppMonitorService.shared.clearAuthentication(for: app.bundleIdentifier)
                NSLog("[BonsoirNon] Auto-closed on wake: %@ (%@)", app.name, app.bundleIdentifier)
            }
        }
    }

    // MARK: - Notifications

    /// Post a local notification when Watch auto-unlocks an app.
    static func sendWatchUnlockNotification(appName: String) {
        sendNotification(title: "Unlocked", body: "Apple Watch unlocked \(appName)")
    }

    /// Post a local notification when Touch ID or password unlocks an app.
    static func sendUnlockNotification(appName: String) {
        sendNotification(title: "Unlocked", body: "\(appName) unlocked with Touch ID")
    }

    private static func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "bonsoirnon-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
