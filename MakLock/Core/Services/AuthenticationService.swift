import LocalAuthentication
import Foundation

/// Handles Touch ID and password authentication.
final class AuthenticationService {
    static let shared = AuthenticationService()

    /// Whether a Touch ID evaluation is currently in progress.
    private(set) var isAuthenticating = false

    /// The active LAContext — kept so it can be cancelled on overlay dismiss.
    private var activeContext: LAContext?

    private init() {}

    /// Attempt Touch ID authentication.
    /// Concurrent calls are silently ignored — only one evaluatePolicy at a time.
    func authenticateWithTouchID(reason: String = "Unlock this app", completion: @escaping (AuthResult) -> Void) {
        guard !isAuthenticating else {
            NSLog("[MakLock] Touch ID already in progress — ignoring duplicate call")
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let authError = mapLAError(error)
            completion(.failure(authError))
            return
        }

        isAuthenticating = true
        activeContext = context

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.activeContext = nil

                if success {
                    completion(.success)
                } else if let error = error as? LAError, error.code == .userCancel {
                    completion(.cancelled)
                } else {
                    let authError = self.mapLAError(error as NSError?)
                    completion(.failure(authError))
                }
            }
        }
    }

    /// Cancel any in-progress Touch ID evaluation (called when overlay is dismissed externally).
    func cancelAuthentication() {
        activeContext?.invalidate()
        activeContext = nil
        isAuthenticating = false
    }

    /// Failed password attempts since the last success.
    private var failedPasswordAttempts = 0

    /// Password entry is refused until this date after too many failures.
    private var passwordLockedUntil: Date?

    /// Free attempts before a lockout starts.
    private static let freePasswordAttempts = 5

    /// Verify the backup password, with an escalating lockout after repeated failures
    /// (30 s after 5 failures, doubling each time, capped at 15 min).
    func authenticateWithPassword(_ password: String) -> AuthResult {
        guard KeychainManager.shared.hasPassword() else {
            return .failure(.noPasswordSet)
        }

        if let until = passwordLockedUntil, until > Date() {
            return .failure(.tooManyAttempts(retryAfter: Int(until.timeIntervalSinceNow.rounded(.up))))
        }

        if KeychainManager.shared.verifyPassword(password) {
            failedPasswordAttempts = 0
            passwordLockedUntil = nil
            return .success
        }

        failedPasswordAttempts += 1
        let excess = failedPasswordAttempts - Self.freePasswordAttempts
        if excess >= 0 {
            let delay = min(30 * pow(2, Double(excess)), 15 * 60)
            passwordLockedUntil = Date().addingTimeInterval(delay)
            return .failure(.tooManyAttempts(retryAfter: Int(delay)))
        }
        return .failure(.wrongPassword)
    }

    /// Authenticate with Touch ID, falling back to macOS login password.
    /// Used for settings access gating — shows the native system dialog, not the full-screen overlay.
    func authenticateWithSystemFallback(reason: String, completion: @escaping (AuthResult) -> Void) {
        guard !isAuthenticating else {
            completion(.cancelled)
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(mapLAError(error)))
            return
        }

        isAuthenticating = true
        activeContext = context

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.activeContext = nil

                if success {
                    completion(.success)
                } else if let error = error as? LAError, error.code == .userCancel {
                    completion(.cancelled)
                } else {
                    completion(.failure(self.mapLAError(error as NSError?)))
                }
            }
        }
    }

    /// Check if Touch ID is available on this Mac.
    var isTouchIDAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Private

    private func mapLAError(_ error: NSError?) -> AuthError {
        guard let error else { return .systemError("Unknown error") }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        default:
            return .systemError(error.localizedDescription)
        }
    }
}
