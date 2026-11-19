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

    var body: some View {
        Form {
            Section {
                Toggle("Require authentication on app launch", isOn: $settings.requireAuthOnLaunch)
                    .toggleStyle(.goldSwitch)
                    .onChange(of: settings.requireAuthOnLaunch) {
                        Defaults.shared.appSettings = settings
                    }

                Toggle("Require authentication on app switch", isOn: $settings.requireAuthOnActivate)
                    .toggleStyle(.goldSwitch)
                    .onChange(of: settings.requireAuthOnActivate) {
                        Defaults.shared.appSettings = settings
                    }
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
