import AppKit
import ApplicationServices

/// Drops keystrokes aimed at a locked app while the lock screen is up.
///
/// The overlay is a non-activating panel (so the Touch ID dialog keeps focus),
/// which means the app behind it can still be the frontmost one and receive
/// typing — e.g. a message typed blind and sent with Return. Locked apps are
/// also hidden (see OverlayWindowService), this is the safety net.
///
/// Needs the Accessibility permission (System Settings → Privacy & Security →
/// Accessibility). Without it, nothing is blocked and the app keeps working.
final class KeyboardGuard {
    static let shared = KeyboardGuard()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    /// Whether Bonsoir, non has the Accessibility permission.
    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Show the system prompt asking for the Accessibility permission.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings on the Accessibility list.
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Install the event tap if allowed and not installed yet. Cheap to call often.
    func startIfPossible() {
        guard tap == nil, isTrusted else { return }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, _ in
                KeyboardGuard.shared.handle(type: type, event: event)
            },
            userInfo: nil
        ) else {
            NSLog("[BonsoirNon] Keyboard guard: could not create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        NSLog("[BonsoirNon] Keyboard guard active")
    }

    // MARK: - Private

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables slow or interrupted taps: turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard OverlayWindowService.shared.isShowing,
              let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              ProtectedAppsManager.shared.isProtected(front),
              !AppMonitorService.shared.isAuthenticated(front)
        else {
            return Unmanaged.passUnretained(event)
        }

        // A locked app is in front behind the overlay: swallow the keystroke.
        return nil
    }
}
