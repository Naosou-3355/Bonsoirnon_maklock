import Foundation

/// Authentication methods supported by Bonsoir, non.
enum AuthMethod: String, Codable, CaseIterable {
    /// Touch ID biometric authentication.
    case touchID

    /// Backup password stored in Keychain.
    case password
}

/// Result of an authentication attempt.
enum AuthResult {
    case success
    case failure(AuthError)
    case cancelled
}

/// Authentication errors.
enum AuthError: Error, LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case wrongPassword
    case noPasswordSet
    case tooManyAttempts(retryAfter: Int)
    case systemError(String)

    var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return "Touch ID n'est pas disponible sur ce Mac."
        case .biometryNotEnrolled:
            return "Aucune empreinte n'est enregistrée dans Touch ID."
        case .biometryLockout:
            return "Touch ID est bloqué. Utilise ton mot de passe."
        case .wrongPassword:
            return "Mot de passe incorrect. Réessaie."
        case .noPasswordSet:
            return "Aucun mot de passe de secours. Va dans Réglages → Sécurité."
        case .tooManyAttempts(let seconds):
            return "Trop d'essais. Réessaie dans \(seconds) s."
        case .systemError(let message):
            return message
        }
    }
}
