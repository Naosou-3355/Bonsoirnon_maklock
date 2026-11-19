import AppKit
import LocalAuthentication

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
    func authenticateWithTouchID(reason: String = "Déverrouiller cette app", completion: @escaping (AuthResult) -> Void) {
        guard !isAuthenticating else {
            NSLog("[BonsoirNon] Touch ID already in progress — ignoring duplicate call")
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

    /// Keychain account holding the lockout state (survives app restarts).
    private static let lockoutAccount = "password-lockout"

    private var lockout: PasswordLockout {
        get {
            guard let data = KeychainManager.shared.data(forAccount: Self.lockoutAccount),
                  let value = try? JSONDecoder().decode(PasswordLockout.self, from: data)
            else { return PasswordLockout() }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                KeychainManager.shared.setData(data, forAccount: Self.lockoutAccount)
            }
        }
    }

    /// Verify the backup password, with an escalating lockout after repeated failures
    /// (see `PasswordLockout`). The lockout is stored in the Keychain, so quitting
    /// and relaunching Bonsoir, non does not reset it.
    func authenticateWithPassword(_ password: String) -> AuthResult {
        guard KeychainManager.shared.hasPassword() else {
            return .failure(.noPasswordSet)
        }

        var state = lockout
        if let remaining = state.secondsRemaining() {
            return .failure(.tooManyAttempts(retryAfter: remaining))
        }

        if KeychainManager.shared.verifyPassword(password) {
            state.recordSuccess()
            lockout = state
            return .success
        }

        let delay = state.recordFailure()
        lockout = state
        if let delay {
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

    /// Ask for Touch ID (macOS password as fallback) before an action that weakens
    /// protection, then bring Bonsoir, non back to the front: the system dialog takes
    /// focus and macOS would otherwise leave our window behind other apps.
    /// The Watch is deliberately not accepted here.
    func confirmSensitiveAction(reason: String, completion: @escaping (Bool) -> Void) {
        let window = NSApp.keyWindow
        authenticateWithSystemFallback(reason: reason) { result in
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            if case .success = result {
                completion(true)
            } else {
                completion(false)
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
        guard let error else { return .systemError("Erreur inconnue") }

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
