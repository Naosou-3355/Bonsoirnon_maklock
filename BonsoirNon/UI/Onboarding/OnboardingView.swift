import SwiftUI
import ServiceManagement

/// First-launch onboarding view with welcome, safety tutorial, password setup, and finish.
struct OnboardingView: View {
    @State private var currentStep = 0
    let onComplete: () -> Void

    private let totalSteps = 5

    private let infoSteps: [Int: OnboardingInfoStep] = [
        0: OnboardingInfoStep(
            icon: OnboardingInfoStep.appIcon,
            title: "Bienvenue dans Bonsoir, non",
            description: "Verrouille n'importe quelle app avec Touch ID ou un mot de passe.\nTes apps, ta vie privée."
        ),
        // Step 1 = Panic Key (custom view with visual keycaps)
        // Step 2 = Password Setup (custom view)
        3: OnboardingInfoStep(
            icon: "plus.app.fill",
            title: "Ajoute des apps à protéger",
            description: "Ouvre Réglages → Apps pour choisir les applications à protéger.\n\nCommence par une app de test comme Échecs."
        )
        // Step 4 = Final Step (custom view with Launch at Login toggle)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentStep {
                case 1:
                    PanicKeyStep()
                case 2:
                    PasswordSetupStep(onContinue: { advanceStep() })
                case 4:
                    FinalStep()
                default:
                    if let info = infoSteps[currentStep] {
                        InfoStepView(step: info)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(BonsoirNonAnimations.standard, value: currentStep)

            // Navigation
            HStack {
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? BonsoirNonColors.gold : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Password step handles its own button
                if currentStep != 2 {
                    if currentStep < totalSteps - 1 {
                        PrimaryButton("Continuer") {
                            advanceStep()
                        }
                    } else {
                        PrimaryButton("C'est parti") {
                            onComplete()
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 440)
        .background(BonsoirNonColors.background)
    }

    private func advanceStep() {
        withAnimation(BonsoirNonAnimations.standard) {
            currentStep += 1
        }
    }
}

// MARK: - Info Step

private struct InfoStepView: View {
    let step: OnboardingInfoStep

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if step.icon == OnboardingInfoStep.appIcon {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: step.icon)
                    .font(.system(size: 48))
                    .foregroundColor(BonsoirNonColors.gold)
                    .frame(height: 60)
            }

            Text(step.title)
                .font(BonsoirNonTypography.largeTitle)
                .foregroundColor(BonsoirNonColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(step.description)
                .font(BonsoirNonTypography.body)
                .foregroundColor(BonsoirNonColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Panic Key Step

private struct PanicKeyStep: View {
    var body: some View {
        if SafetyManager.isDevMode {
            panicKeyContent
        } else {
            InfoStepView(step: OnboardingInfoStep(
                icon: "exclamationmark.triangle.fill",
                title: "Si tu es bloqué",
                description: "L'écran de verrouillage se ferme tout seul après 60 secondes, et l'app reste masquée et verrouillée.\n\nTerminal, Finder, Moniteur d'activité et Réglages Système ne peuvent jamais être verrouillés : tu peux toujours quitter Bonsoir, non depuis là."
            ))
        }
    }

    /// Debug builds only: the panic key does not exist in Release.
    private var panicKeyContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(BonsoirNonColors.gold)
                .frame(height: 60)

            Text("Raccourci d'urgence")
                .font(BonsoirNonTypography.largeTitle)
                .foregroundColor(BonsoirNonColors.textPrimary)

            Text("Si tu restes bloqué, ce raccourci\nferme immédiatement tous les écrans de verrouillage :")
                .font(BonsoirNonTypography.body)
                .foregroundColor(BonsoirNonColors.textSecondary)
                .multilineTextAlignment(.center)

            // Visual keyboard shortcut
            HStack(spacing: 6) {
                KeyCap("⌘", label: "Command")
                Text("+").foregroundColor(BonsoirNonColors.textSecondary)
                KeyCap("⌥", label: "Option")
                Text("+").foregroundColor(BonsoirNonColors.textSecondary)
                KeyCap("⇧", label: "Shift")
                Text("+").foregroundColor(BonsoirNonColors.textSecondary)
                KeyCap("⌃", label: "Control")
                Text("+").foregroundColor(BonsoirNonColors.textSecondary)
                KeyCap("U", label: nil)
            }
            .padding(.vertical, 8)

            Text("Essaie-le maintenant : il marche toujours, même en plein écran.")
                .font(BonsoirNonTypography.caption)
                .foregroundColor(BonsoirNonColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

/// A visual keyboard key cap.
private struct KeyCap: View {
    let symbol: String
    let label: String?

    init(_ symbol: String, label: String?) {
        self.symbol = symbol
        self.label = label
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(BonsoirNonColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BonsoirNonColors.cardDark)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 2)
                )

            Text(label ?? " ")
                .font(.system(size: 8))
                .foregroundColor(label != nil ? BonsoirNonColors.textSecondary : .clear)
        }
    }
}

// MARK: - Password Setup Step

private struct PasswordSetupStep: View {
    let onContinue: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(BonsoirNonColors.gold)
                .frame(height: 60)

            Text("Mot de passe de secours")
                .font(BonsoirNonTypography.largeTitle)
                .foregroundColor(BonsoirNonColors.textPrimary)

            Text("Utilisé quand Touch ID n'est pas disponible.\nTu pourras le changer dans les Réglages.")
                .font(BonsoirNonTypography.body)
                .foregroundColor(BonsoirNonColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if isSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(BonsoirNonColors.success)
                    Text("Mot de passe enregistré !")
                        .font(BonsoirNonTypography.body)
                        .foregroundColor(BonsoirNonColors.success)
                }
                .padding(.top, 8)

                PrimaryButton("Continuer") {
                    onContinue()
                }
            } else {
                VStack(spacing: 10) {
                    passwordField("Mot de passe (4 caractères min.)", text: $password)
                    passwordField("Confirmer le mot de passe", text: $confirmPassword)
                        .onSubmit { savePassword() }
                }

                // Show/hide toggle
                Button(action: { showPassword.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
                            .font(BonsoirNonTypography.caption)
                    }
                    .foregroundColor(BonsoirNonColors.textSecondary)
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(BonsoirNonColors.error)
                }

                PrimaryButton("Enregistrer") {
                    savePassword()
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func passwordField(_ placeholder: String, text: Binding<String>) -> some View {
        Group {
            if showPassword {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textFieldStyle(.roundedBorder)
        .frame(width: 260)
    }

    private func savePassword() {
        guard !password.isEmpty else {
            errorMessage = "Le mot de passe ne peut pas être vide."
            return
        }
        guard password.count >= 4 else {
            errorMessage = "Le mot de passe doit faire au moins 4 caractères."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Les mots de passe ne correspondent pas."
            return
        }

        let saved = KeychainManager.shared.savePassword(password)
        if saved {
            Defaults.shared.isBackupPasswordSet = true
            withAnimation(BonsoirNonAnimations.standard) {
                isSaved = true
            }
        } else {
            errorMessage = "Échec de l'enregistrement. Réessaie."
        }
    }
}

// MARK: - Final Step

private struct FinalStep: View {
    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundColor(BonsoirNonColors.gold)
                .frame(height: 60)

            Text("Tout est prêt")
                .font(BonsoirNonTypography.largeTitle)
                .foregroundColor(BonsoirNonColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Bonsoir, non vit dans ta barre des menus.\nLes apps protégées demanderont Touch ID : pose simplement ton doigt sur le capteur.")
                .font(BonsoirNonTypography.body)
                .foregroundColor(BonsoirNonColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            VStack(spacing: 12) {
                Toggle("Ouvrir Bonsoir, non à la connexion", isOn: $launchAtLogin)
                    .toggleStyle(.goldSwitch)

                Text("Tu peux aussi régler le verrouillage après inactivité\net d'autres options dans les Réglages.")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(BonsoirNonColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .onDisappear {
            saveLaunchAtLogin()
        }
    }

    private func saveLaunchAtLogin() {
        var settings = Defaults.shared.appSettings
        settings.launchAtLogin = launchAtLogin
        Defaults.shared.appSettings = settings

        LaunchAtLogin.apply(launchAtLogin)
    }
}

// MARK: - Models

private struct OnboardingInfoStep {
    /// Pass as `icon` to show the app icon instead of an SF Symbol.
    static let appIcon = "__appIcon__"

    let icon: String
    let title: String
    let description: String
}
