import SwiftUI

/// Apps settings tab: manage the list of protected applications.
struct AppsSettingsView: View {
    @StateObject private var manager = ProtectedAppsManager.shared
    @State private var appPickerController = AppPickerWindowController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protected Applications")
                .font(BonsoirNonTypography.title)

            if manager.apps.isEmpty {
                emptyState
            } else {
                appsList
            }

            Spacer()

            HStack {
                Spacer()
                PrimaryButton("Add App", icon: "plus") {
                    appPickerController.show(from: NSApp.keyWindow)
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.open")
                .font(.system(size: 40))
                .foregroundColor(BonsoirNonColors.textSecondary)
            Text("No protected apps yet")
                .font(BonsoirNonTypography.headline)
                .foregroundColor(.secondary)
            Text("Add apps to protect them with Touch ID or password.")
                .font(BonsoirNonTypography.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var appsList: some View {
        List {
            ForEach(manager.apps) { app in
                HStack(spacing: 12) {
                    AppIconView(bundleIdentifier: app.bundleIdentifier, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(BonsoirNonTypography.headline)
                        Text(app.bundleIdentifier)
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Auto-close toggle
                    Button(action: { manager.toggleAutoClose(app) }) {
                        Image(systemName: app.autoClose ? "timer" : "timer")
                            .font(.system(size: 12))
                            .foregroundColor(app.autoClose ? BonsoirNonColors.gold : BonsoirNonColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(app.autoClose ? "Auto-close enabled" : "Enable auto-close when inactive")

                    Toggle("", isOn: Binding(
                        get: { app.isEnabled },
                        set: { enable in
                            if enable {
                                manager.toggleApp(app)
                            } else {
                                // Turning protection off weakens security: authenticate first.
                                requireAuthentication(reason: "Stop protecting \(app.name)") {
                                    ActivityLog.shared.record(.appUnprotected, app: app.name)
                                    manager.toggleApp(app)
                                }
                            }
                        }
                    ))
                    .toggleStyle(.goldSwitch)
                    .labelsHidden()

                    Button(action: {
                        requireAuthentication(reason: "Remove \(app.name) from protected apps") {
                            ActivityLog.shared.record(.appUnprotected, app: app.name)
                            manager.removeApp(app)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(BonsoirNonColors.error)
                    }
                    .buttonStyle(.plain)
                }
                .id(app.id)
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                let appsToRemove = indexSet.map { manager.apps[$0] }
                let names = appsToRemove.map(\.name).joined(separator: ", ")
                requireAuthentication(reason: "Remove \(names) from protected apps") {
                    appsToRemove.forEach {
                        ActivityLog.shared.record(.appUnprotected, app: $0.name)
                        manager.removeApp($0)
                    }
                }
            }
        }
    }

    /// Run `action` only after Touch ID (or the macOS password as fallback) succeeds.
    /// On failure, refresh the list so a switch the user flipped snaps back.
    private func requireAuthentication(reason: String, action: @escaping () -> Void) {
        AuthenticationService.shared.confirmSensitiveAction(reason: reason) { success in
            if success {
                action()
            } else {
                manager.objectWillChange.send()
            }
        }
    }
}
