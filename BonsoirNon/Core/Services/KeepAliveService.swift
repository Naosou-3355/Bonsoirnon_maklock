import AppKit

/// Keeps Bonsoir, non running: a per-user launchd agent starts it at login and
/// relaunches it whenever it stops without going through the menu's Quit
/// (Force Quit from Activity Monitor, `killall`, crash).
///
/// Release builds only: a Debug build run from Xcode must not hand over to the
/// installed copy or get relaunched.
///
/// Flow:
/// - launched by launchd (env `BONSOIRNON_LAUNCHD=1`): run normally;
/// - launched by hand (Finder, Spotlight) while keep-alive is on: make sure the
///   agent is loaded, start it, and exit, so only the launchd-managed copy runs.
final class KeepAliveService {
    static let shared = KeepAliveService()

    static let label = "com.bonsoirnon.app.keepalive"
    private static let envKey = "BONSOIRNON_LAUNCHD"

    private init() {}

    /// Whether keep-alive can be used at all in this build.
    static var isSupported: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    /// Whether this process was started by the launchd agent.
    var launchedByLaunchd: Bool {
        ProcessInfo.processInfo.environment[Self.envKey] == "1"
    }

    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    private var domain: String { "gui/\(getuid())" }

    /// Call first thing at launch. Returns true if this process must exit because
    /// the launchd-managed copy is (being) started instead.
    func handOverIfNeeded() -> Bool {
        guard Self.isSupported,
              Defaults.shared.appSettings.launchAtLogin,
              !launchedByLaunchd
        else { return false }

        // Another copy already runs (normally the launchd one): just leave.
        let me = ProcessInfo.processInfo.processIdentifier
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .contains(where: { $0.processIdentifier != me }) {
            return true
        }

        try? SMAppServiceBridge.unregisterMainApp()  // the agent replaces the login item
        guard writeAgent() else { return false }   // can't set it up: keep running by hand
        if isAgentLoaded() {
            launchctl(["kickstart", "\(domain)/\(Self.label)"])
        } else {
            launchctl(["bootstrap", domain, plistURL.path])
        }
        NSLog("[BonsoirNon] Handing over to the launchd agent")
        return true
    }

    /// Turn keep-alive (login launch + relaunch) on or off. Turning it on from a
    /// copy launched by hand hands over to launchd, which quits this copy.
    func setEnabled(_ enabled: Bool) {
        guard Self.isSupported else { return }

        // The agent replaces the plain login item.
        try? SMAppServiceBridge.unregisterMainApp()

        if enabled {
            guard writeAgent() else { return }
            if !launchedByLaunchd {
                if isAgentLoaded() {
                    launchctl(["kickstart", "\(domain)/\(Self.label)"])
                } else {
                    launchctl(["bootstrap", domain, plistURL.path])
                }
                AppDelegate.terminateAuthorized()
            }
        } else {
            // Not unloading: that would kill this very process. Without the file,
            // the agent is gone at next login, and a menu Quit is never relaunched.
            try? FileManager.default.removeItem(at: plistURL)
        }
    }

    // MARK: - Private

    @discardableResult
    private func writeAgent() -> Bool {
        guard let executable = Bundle.main.executablePath else { return false }
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executable],
            "EnvironmentVariables": [Self.envKey: "1"],
            "RunAtLoad": true,
            // Relaunch unless it exited cleanly (menu Quit, logout).
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 3,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]
        do {
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            if (try? Data(contentsOf: plistURL)) != data {
                try data.write(to: plistURL, options: .atomic)
            }
            return true
        } catch {
            NSLog("[BonsoirNon] Could not write launch agent: %@", error.localizedDescription)
            return false
        }
    }

    private func isAgentLoaded() -> Bool {
        launchctl(["print", "\(domain)/\(Self.label)"]) == 0
    }

    @discardableResult
    private func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            NSLog("[BonsoirNon] launchctl %@ failed: %@", arguments.first ?? "", error.localizedDescription)
            return -1
        }
    }
}

import ServiceManagement

/// Thin wrapper so the login-item calls live in one place.
enum SMAppServiceBridge {
    static func registerMainApp() throws { try SMAppService.mainApp.register() }
    static func unregisterMainApp() throws {
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// "Launch at login": the keep-alive agent in Release (which also relaunches the
/// app if it is killed), a plain login item in Debug.
enum LaunchAtLogin {
    static func apply(_ enabled: Bool) {
        if KeepAliveService.isSupported {
            KeepAliveService.shared.setEnabled(enabled)
            return
        }
        do {
            if enabled {
                try SMAppServiceBridge.registerMainApp()
            } else {
                try SMAppServiceBridge.unregisterMainApp()
            }
        } catch {
            NSLog("[BonsoirNon] Failed to update login item: %@", error.localizedDescription)
        }
    }
}
