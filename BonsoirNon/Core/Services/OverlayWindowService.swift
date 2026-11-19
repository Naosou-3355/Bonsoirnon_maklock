import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
    static let shared = OverlayWindowService()

    private var overlayWindows: [LockOverlayWindow] = []
    private var timeoutTimer: Timer?
    private var currentApp: ProtectedApp?

    /// Callback when overlay is dismissed after successful authentication.
    /// Passes the name of the unlocked app.
    var onUnlocked: ((String) -> Void)?

    private init() {
        // Observe screen configuration changes (connect/disconnect monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Show the lock overlay for a protected app on all screens.
    func show(for app: ProtectedApp) {
        // Don't show duplicate overlays
        guard overlayWindows.isEmpty else { return }

        currentApp = app

        createOverlayWindows(for: app)
        startTimeoutTimer()
        KeyboardGuard.shared.startIfPossible()   // in case the permission was granted since launch

        // Hide the locked app while the overlay is up: its windows leave Mission
        // Control / App Exposé and it stops receiving keystrokes. Done before the
        // Touch ID prompt (which the overlay triggers 0.5 s after appearing) so the
        // focus change doesn't fight with the system dialog. Unhidden on unlock.
        hideRunningApp(bundleIdentifier: app.bundleIdentifier)

        NSLog("[BonsoirNon] Overlay shown for: %@", app.name)
    }

    /// Hide all overlay windows.
    func hide() {
        stopTimeoutTimer()

        // Cancel any in-progress Touch ID evaluation
        AuthenticationService.shared.cancelAuthentication()

        // Mark the app as authenticated so it won't re-lock immediately
        if let app = currentApp {
            AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
        }

        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        // Activate the protected app now that overlays are gone.
        // Small delay ensures overlay panels and Touch ID dialog are fully dismissed
        // before attempting to bring the app forward.
        if let bundleID = currentApp?.bundleIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.activateProtectedApp(bundleIdentifier: bundleID)
            }
        }

        currentApp = nil
        NSLog("[BonsoirNon] Overlay dismissed")
    }

    /// Dismiss all overlays (used by panic key).
    func dismissAll() {
        hide()
    }

    /// Close the overlay WITHOUT unlocking: the protected app is hidden and stays locked.
    /// Used by the timeout failsafe so that waiting never grants access.
    func dismissWithoutUnlock() {
        stopTimeoutTimer()
        AuthenticationService.shared.cancelAuthentication()

        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        let lockedApp = currentApp
        currentApp = nil
        ActivityLog.shared.record(.lockTimedOut, app: lockedApp?.name)

        if let lockedApp {
            let bundleID = lockedApp.bundleIdentifier
            AppMonitorService.shared.resetLock(for: bundleID)
            let running = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID })
            running?.hide()

            // If the app refused to hide and is still in front, lock it again
            // rather than leaving it usable.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, !self.isShowing,
                      let running, !running.isTerminated,
                      running.isActive, !running.isHidden
                else { return }
                NSLog("[BonsoirNon] Protected app still in front after timeout — re-locking")
                self.show(for: lockedApp)
            }
        }

        NSLog("[BonsoirNon] Overlay timed out — protected app hidden, still locked")
    }

    /// Whether an overlay is currently displayed.
    var isShowing: Bool {
        !overlayWindows.isEmpty
    }

    /// Bundle identifier of the currently locked app (if any).
    var currentBundleIdentifier: String? {
        currentApp?.bundleIdentifier
    }

    /// Display name of the currently locked app (if any).
    var currentAppName: String? {
        currentApp?.name
    }

    /// During Touch ID: pass through mouse events so system dialog gets interaction.
    /// After auth: restore mouse capture for overlay blocking.
    func setTouchIDMode(_ active: Bool) {
        for window in overlayWindows {
            window.ignoresMouseEvents = active
        }
    }

    /// Enable key window status on overlay windows (needed for password input).
    func enableKeyboardInput() {
        setTouchIDMode(false)
        for window in overlayWindows {
            window.allowKeyStatus = true
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Screen Management

    @objc private func screensDidChange(_ notification: Notification) {
        guard !overlayWindows.isEmpty else { return }

        let screens = NSScreen.screens

        // Reposition existing windows to match current screens (don't recreate to avoid re-triggering Touch ID)
        for (index, window) in overlayWindows.enumerated() {
            if index < screens.count {
                window.reposition(to: screens[index])
            }
        }

        // Close excess windows if screens were removed
        while overlayWindows.count > screens.count {
            overlayWindows.removeLast().close()
        }

        // Add new windows for new screens (only blur, no Touch ID trigger)
        if let app = currentApp {
            for screenIndex in overlayWindows.count..<screens.count {
                let window = LockOverlayWindow(for: screens[screenIndex])
                let overlayView = LockOverlayView(
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    isPrimary: false,
                    onDismiss: { [weak self] in
                        let name = self?.currentApp?.name ?? "app"
                        self?.hide()
                        self?.onUnlocked?(name)
                    }
                )
                window.contentView = NSHostingView(rootView: overlayView)
                window.orderFront(nil)
                overlayWindows.append(window)
            }
        }

        NSLog("[BonsoirNon] Overlays repositioned for screen change (%d screens)", screens.count)
    }

    private func createOverlayWindows(for app: ProtectedApp) {
        let primaryScreen = NSScreen.main ?? NSScreen.screens.first

        for screen in NSScreen.screens {
            let window = LockOverlayWindow(for: screen)
            let isPrimary = (screen == primaryScreen)

            let overlayView = LockOverlayView(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                isPrimary: isPrimary,
                onDismiss: { [weak self] in
                    let name = self?.currentApp?.name ?? "app"
                    self?.hide()
                    self?.onUnlocked?(name)
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            // Don't make key or activate — system Touch ID dialog needs focus
            window.orderFront(nil)
            overlayWindows.append(window)
        }
    }

    // MARK: - App Window Management

    /// Bring the protected app to the foreground after successful auth.
    /// Only activates if the app is already running — never launches a closed app.
    private func activateProtectedApp(bundleIdentifier: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            NSLog("[BonsoirNon] App not running, skipping activation: %@", bundleIdentifier)
            return
        }
        app.unhide()
        app.activate()
        NSLog("[BonsoirNon] Activated app: %@", bundleIdentifier)
    }

    /// Hide a running app (used while it is locked).
    func hideRunningApp(bundleIdentifier: String) {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier })?
            .hide()
    }

    // MARK: - Timeout

    private func startTimeoutTimer() {
        let timeout = SafetyManager.isDevMode
            ? SafetyManager.devModeTimeout
            : SafetyManager.overlayTimeout

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            NSLog("[BonsoirNon Safety] Overlay timeout reached (%.0fs) — hiding app, staying locked", timeout)
            self?.dismissWithoutUnlock()
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

}
