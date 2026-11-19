import SwiftUI

/// Security settings tab: authentication method, backup password.
struct SecuritySettingsView: View {
    @State private var settings = Defaults.shared.appSettings
    @State private var hasBackupPassword = false
    @State private var showPasswordSheet = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var keyboardGuardTrusted = KeyboardGuard.shared.isTrusted

    /// Shorter delay: applied at once. Longer delay or "never": needs Touch ID.
    private var relockDelayBinding: Binding<Int> {
        Binding(
            get: { settings.relockDelay },
            set: { newValue in
                let old = settings.relockDelay
                guard RelockDelay.isWeaker(newValue, than: old) else {
                    settings.relockDelay = newValue
                    Defaults.shared.appSettings = settings
                    return
                }
                AuthenticationService.shared.confirmSensitiveAction(reason: "Let unlocked apps stay open longer") { success in
                    guard success else { return }
                    settings.relockDelay = newValue
                    Defaults.shared.appSettings = settings
                }
            }
        )
    }

    static func label(forRelockDelay seconds: Int) -> String {
        switch seconds {
        case 0: return "Immediately"
        case RelockDelay.never: return "Never (only on quit, sleep, idle)"
        case let s where s < 3600: return "After \(s / 60) min"
        default: return "After \(seconds / 3600) h"
        }
    }

    var body: some View {
        Form {
            Section {
                // Protected apps always ask when they open; this sets when they ask
                // again after you leave them.
                Picker("Re-lock after leaving an app", selection: relockDelayBinding) {
                    ForEach(RelockDelay.choices, id: \.self) { seconds in
                        Text(Self.label(forRelockDelay: seconds)).tag(seconds)
                    }
                }
                Text("Protected apps always ask when they open, and again after sleep, idle or when the Watch leaves.")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
            }

            Section("Touch ID") {
                HStack {
                    Image(systemName: "touchid")
                        .font(.system(size: 20))
                        .foregroundColor(AuthenticationService.shared.isTouchIDAvailable ? BonsoirNonColors.success : BonsoirNonColors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AuthenticationService.shared.isTouchIDAvailable ? "Touch ID Available" : "Touch ID Not Available")
                            .font(BonsoirNonTypography.body)
                        if !AuthenticationService.shared.isTouchIDAvailable {
                            Text("Touch ID is not configured on this Mac. Use a backup password instead.")
                                .font(BonsoirNonTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Keyboard Blocking") {
                HStack {
                    Image(systemName: keyboardGuardTrusted ? "keyboard" : "exclamationmark.triangle.fill")
                        .foregroundColor(keyboardGuardTrusted ? BonsoirNonColors.success : BonsoirNonColors.locked)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(keyboardGuardTrusted ? "Keystrokes to locked apps are blocked" : "Keyboard blocking is off")
                            .font(BonsoirNonTypography.body)
                        Text("Needs the Accessibility permission. Locked apps are hidden either way; this blocks typing as a safety net.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !keyboardGuardTrusted {
                    Button("Grant Accessibility Permission...") {
                        KeyboardGuard.shared.requestPermission()
                        KeyboardGuard.shared.openSystemSettings()
                    }
                }
            }

            Section("Backup Password") {
                if hasBackupPassword {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(BonsoirNonColors.success)
                        Text("Backup password is set")
                            .font(BonsoirNonTypography.body)
                    }

                    Button("Change Password...") {
                        resetPasswordFields()
                        showPasswordSheet = true
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(BonsoirNonColors.locked)
                        Text("No backup password set")
                            .font(BonsoirNonTypography.body)
                    }

                    Text("A backup password lets you unlock apps when Touch ID is unavailable.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)

                    Button("Set Password...") {
                        resetPasswordFields()
                        showPasswordSheet = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            keyboardGuardTrusted = KeyboardGuard.shared.isTrusted
            KeyboardGuard.shared.startIfPossible()
        }
        .onAppear {
            keyboardGuardTrusted = KeyboardGuard.shared.isTrusted
            hasBackupPassword = KeychainManager.shared.hasPassword()
        }
        .sheet(isPresented: $showPasswordSheet) {
            passwordSheet
        }
    }

    // MARK: - Password Sheet

    private var passwordSheet: some View {
        VStack(spacing: 16) {
            Text(hasBackupPassword ? "Change Password" : "Set Backup Password")
                .font(BonsoirNonTypography.title)

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            if let passwordError {
                Text(passwordError)
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(BonsoirNonColors.error)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showPasswordSheet = false
                }

                PrimaryButton("Save") {
                    savePassword()
                }
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func savePassword() {
        guard !newPassword.isEmpty else {
            passwordError = "Password cannot be empty."
            return
        }

        guard newPassword.count >= 4 else {
            passwordError = "Password must be at least 4 characters."
            return
        }

        guard newPassword == confirmPassword else {
            passwordError = "Passwords do not match."
            return
        }

        // A new backup password is a new way to unlock every app: prove it's you first.
        let password = newPassword
        AuthenticationService.shared.confirmSensitiveAction(reason: "Change the Bonsoir, non backup password") { success in
            guard success else {
                passwordError = "Authentication required to change the password."
                return
            }
            if KeychainManager.shared.savePassword(password) {
                Defaults.shared.isBackupPasswordSet = true
                hasBackupPassword = true
                showPasswordSheet = false
            } else {
                passwordError = "Failed to save password. Please try again."
            }
        }
    }

    private func resetPasswordFields() {
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
    }
}
