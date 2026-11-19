import AppKit
import SwiftUI

/// Manages the NSStatusItem and menu bar icon states.
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// Current lock state displayed in the menu bar.
    enum IconState {
        /// No protected apps are running.
        case idle
        /// A protected app is running (unlocked).
        case active
        /// An overlay is currently displayed.
        case locked
    }

    var iconState: IconState = .idle {
        didSet { updateIcon() }
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial icon based on protection state
        iconState = Defaults.shared.appSettings.isProtectionEnabled ? .active : .idle

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            onToggleProtection: { [weak self] in
                self?.toggleProtection()
            },
            onRequestDisable: { [weak popover] completion in
                // Keep the popover open while the Touch ID dialog has focus.
                popover?.behavior = .applicationDefined
                AuthenticationService.shared.confirmSensitiveAction(
                    reason: "Turn off Bonsoir, non protection"
                ) { success in
                    popover?.behavior = .transient
                    completion(success)
                }
            },
            onSettingsClicked: { [weak self] in
                self?.hidePopover()
                let screen = self?.statusItem?.button?.window?.screen
                NotificationCenter.default.post(name: .openSettings, object: screen)
            },
            onQuitClicked: {
                AppDelegate.terminateAuthorized()
            }
        ))
        self.popover = popover

        if let button = statusItem?.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            hidePopover()
        } else {
            // Require authentication before showing the popover
            SettingsAuthService.shared.authenticate { [weak self] success in
                guard success else { return }
                NSApp.activate(ignoringOtherApps: true)
                self?.popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    /// Close the menu if it is open.
    func closePopover() {
        hidePopover()
    }

    private func hidePopover() {
        popover?.performClose(nil)
    }

    private func toggleProtection() {
        var settings = Defaults.shared.appSettings
        settings.isProtectionEnabled.toggle()
        Defaults.shared.appSettings = settings

        if !settings.isProtectionEnabled {
            ActivityLog.shared.record(.protectionTurnedOff)
            OverlayWindowService.shared.dismissAll()
            iconState = .idle
        } else {
            iconState = .active
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        // Template image: white on a dark menu bar, black on a light one.
        guard let hand = NSImage(named: "MenuBarIcon") else { return }
        hand.isTemplate = true
        hand.accessibilityDescription = "Bonsoir, non"

        // Idle (no protected app running): dimmed hand.
        button.appearsDisabled = (iconState == .idle)

        guard iconState == .locked else {
            button.image = hand
            return
        }

        // Locked: hand tinted for the current appearance, plus an orange dot.
        let handSize = hand.size
        let size = NSSize(width: handSize.width + 5, height: 18)
        let badged = NSImage(size: size, flipped: false) { _ in
            let handRect = NSRect(x: 0, y: 0, width: handSize.width, height: handSize.height)
            let tinted = NSImage(size: handSize, flipped: false) { rect in
                hand.draw(in: rect)
                NSColor.labelColor.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: handRect)
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - 6, y: size.height - 6, width: 6, height: 6)).fill()
            return true
        }
        badged.isTemplate = false
        badged.accessibilityDescription = "Bonsoir, non (locked)"
        button.image = badged
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("com.bonsoirnon.app.openSettings")
    static let lockAllNow = Notification.Name("com.bonsoirnon.app.lockAllNow")
}
