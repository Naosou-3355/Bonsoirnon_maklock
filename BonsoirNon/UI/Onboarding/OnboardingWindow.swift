import AppKit
import SwiftUI

/// Controller for the first-launch onboarding window.
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    /// Show onboarding if the user hasn't completed it yet.
    func showIfNeeded() {
        guard !Defaults.shared.hasCompletedOnboarding else { return }
        // The onboarding lets anyone set a backup password without knowing the old
        // one. The flag above lives in UserDefaults and can be deleted from Terminal,
        // so never show it again once the app has been set up.
        guard !KeychainManager.shared.hasPassword(),
              Defaults.shared.protectedApps.isEmpty
        else {
            Defaults.shared.hasCompletedOnboarding = true
            return
        }
        show()
    }

    /// Show the onboarding window.
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let onboardingView = OnboardingView {
            Defaults.shared.hasCompletedOnboarding = true
            self.close()
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Bienvenue dans Bonsoir, non"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()

        // Menu bar apps (LSUIElement) run in background — must activate explicitly
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    /// Close the onboarding window.
    func close() {
        window?.close()
        window = nil
    }
}
