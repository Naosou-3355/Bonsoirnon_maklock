import SwiftUI

/// SwiftUI content for the menu bar popover dropdown.
struct MenuBarView: View {
    let onToggleProtection: () -> Void
    /// Asks for authentication before protection is turned off; calls back with the result.
    let onRequestDisable: (@escaping (Bool) -> Void) -> Void
    let onSettingsClicked: () -> Void
    let onQuitClicked: () -> Void

    @State private var isProtectionEnabled = Defaults.shared.appSettings.isProtectionEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 16)
                    .foregroundColor(BonsoirNonColors.gold)
                Text("Bonsoir, non")
                    .font(BonsoirNonTypography.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)

            // Status + Quick Toggle
            HStack {
                Circle()
                    .fill(isProtectionEnabled ? BonsoirNonColors.success : BonsoirNonColors.textSecondary)
                    .frame(width: 8, height: 8)
                Text(isProtectionEnabled ? "Protection Active" : "Protection Off")
                    .font(BonsoirNonTypography.body)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isProtectionEnabled },
                    set: { enable in
                        if enable {
                            isProtectionEnabled = true
                            onToggleProtection()
                        } else {
                            // Turning protection off needs Touch ID or the macOS password.
                            onRequestDisable { success in
                                guard success else { return }
                                isProtectionEnabled = false
                                onToggleProtection()
                            }
                        }
                    }
                ))
                    .toggleStyle(.goldSwitchSmall)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Protected apps count
            let appCount = ProtectedAppsManager.shared.apps.filter(\.isEnabled).count
            HStack(spacing: 6) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(appCount) protected app\(appCount == 1 ? "" : "s")")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)

            // Actions
            MenuBarButton(title: "Lock All Now", icon: "lock.fill", shortcut: "⌃⌥⌘L") {
                NotificationCenter.default.post(name: .lockAllNow, object: nil)
            }

            MenuBarButton(title: "Settings...", icon: "gearshape") {
                onSettingsClicked()
            }

            MenuBarButton(title: "About Bonsoir, non", icon: "info.circle") {
                showAboutWindow()
            }

            Divider()
                .padding(.horizontal, 8)

            MenuBarButton(title: "Quit Bonsoir, non", icon: "power") {
                onQuitClicked()
            }

            Spacer()
                .frame(height: 8)
        }
        .frame(width: 260)
    }

    private func showAboutWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Bonsoir, non"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Button

private struct MenuBarButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(BonsoirNonTypography.body)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(.horizontal, 4)
    }
}
