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
                AuthenticationService.shared.confirmSensitiveAction(reason: "Laisser les apps déverrouillées plus longtemps") { success in
                    guard success else { return }
                    settings.relockDelay = newValue
                    Defaults.shared.appSettings = settings
                }
            }
        )
    }

    static func label(forRelockDelay seconds: Int) -> String {
        switch seconds {
        case 0: return "Immédiatement"
        case RelockDelay.never: return "Jamais"
        case let s where s < 3600: return "Au bout de \(s / 60) min"
        default: return "Au bout de \(seconds / 3600) h"
        }
    }

    var body: some View {
        Form {
            Section {
                // Protected apps always ask when they open; this sets when they ask
                // again after you leave them.
                Picker("Quand tu passes à une autre app, reverrouiller", selection: relockDelayBinding) {
                    ForEach(RelockDelay.choices, id: \.self) { seconds in
                        Text(Self.label(forRelockDelay: seconds)).tag(seconds)
                    }
                }
                Text("Une app protégée se verrouille toujours quand tu l'ouvres, quand tu la fermes, en veille, après inactivité ou quand ta montre s'éloigne. Ce réglage ajoute le cas où tu passes simplement à une autre app.")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
            }

            Section("Touch ID") {
                HStack {
                    Image(systemName: "touchid")
                        .font(.system(size: 20))
                        .foregroundColor(AuthenticationService.shared.isTouchIDAvailable ? BonsoirNonColors.success : BonsoirNonColors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AuthenticationService.shared.isTouchIDAvailable ? "Touch ID disponible" : "Touch ID indisponible")
                            .font(BonsoirNonTypography.body)
                        if !AuthenticationService.shared.isTouchIDAvailable {
                            Text("Touch ID n'est pas configuré sur ce Mac. Utilise un mot de passe de secours.")
                                .font(BonsoirNonTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Clavier") {
                HStack {
                    Image(systemName: keyboardGuardTrusted ? "keyboard" : "exclamationmark.triangle.fill")
                        .foregroundColor(keyboardGuardTrusted ? BonsoirNonColors.success : BonsoirNonColors.locked)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(keyboardGuardTrusted ? "La frappe vers les apps verrouillées est bloquée" : "Blocage du clavier inactif")
                            .font(BonsoirNonTypography.body)
                        Text("Nécessite l'autorisation Accessibilité. Les apps verrouillées sont masquées dans tous les cas ; ceci bloque la frappe en plus.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !keyboardGuardTrusted {
                    Button("Autoriser l'accessibilité…") {
                        KeyboardGuard.shared.requestPermission()
                        KeyboardGuard.shared.openSystemSettings()
                    }
                }
            }

            Section("Mot de passe de secours") {
                if hasBackupPassword {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(BonsoirNonColors.success)
                        Text("Mot de passe de secours défini")
                            .font(BonsoirNonTypography.body)
                    }

                    Button("Changer le mot de passe…") {
                        resetPasswordFields()
                        showPasswordSheet = true
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(BonsoirNonColors.locked)
                        Text("Aucun mot de passe de secours")
                            .font(BonsoirNonTypography.body)
                    }

                    Text("Le mot de passe de secours déverrouille les apps quand Touch ID n'est pas disponible.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)

                    Button("Définir un mot de passe…") {
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
            Text(hasBackupPassword ? "Change Password" : "Mot de passe de secours")
                .font(BonsoirNonTypography.title)

            SecureField("Nouveau mot de passe", text: $newPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            SecureField("Confirmer le mot de passe", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            if let passwordError {
                Text(passwordError)
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(BonsoirNonColors.error)
            }

            HStack(spacing: 12) {
                Button("Annuler") {
                    showPasswordSheet = false
                }

                PrimaryButton("Enregistrer") {
                    savePassword()
                }
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func savePassword() {
        guard !newPassword.isEmpty else {
            passwordError = "Le mot de passe ne peut pas être vide."
            return
        }

        guard newPassword.count >= 4 else {
            passwordError = "Le mot de passe doit faire au moins 4 caractères."
            return
        }

        guard newPassword == confirmPassword else {
            passwordError = "Les mots de passe ne correspondent pas."
            return
        }

        // A new backup password is a new way to unlock every app: prove it's you first.
        let password = newPassword
        AuthenticationService.shared.confirmSensitiveAction(reason: "Changer le mot de passe de secours de Bonsoir, non") { success in
            guard success else {
                passwordError = "Authentification nécessaire pour changer le mot de passe."
                return
            }
            if KeychainManager.shared.savePassword(password) {
                Defaults.shared.isBackupPasswordSet = true
                hasBackupPassword = true
                showPasswordSheet = false
            } else {
                passwordError = "Échec de l'enregistrement. Réessaie."
            }
        }
    }

    private func resetPasswordFields() {
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
    }
}
