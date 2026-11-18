import CommonCrypto
import Foundation
import Security

/// Manages secure storage of the backup password in the macOS Keychain.
///
/// The password itself is never stored: only a salted PBKDF2-HMAC-SHA256 hash
/// (600,000 iterations, per the OWASP Password Storage Cheat Sheet).
final class KeychainManager {
    static let shared = KeychainManager(service: "com.bonsoirnon.app")

    /// Keychain service name. Tests use a different one so they never touch real data.
    let service: String
    private let account = "backup-password-hash"

    private static let iterations: UInt32 = 600_000
    private static let saltLength = 16
    private static let hashLength = 32
    private static let formatPrefix = "pbkdf2-sha256"

    init(service: String) {
        self.service = service
    }

    /// Hash and save a password to the Keychain.
    @discardableResult
    func savePassword(_ password: String) -> Bool {
        var salt = Data(count: Self.saltLength)
        let saltStatus = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, $0.baseAddress!)
        }
        guard saltStatus == errSecSuccess,
              let hash = Self.deriveHash(password: password, salt: salt, iterations: Self.iterations)
        else { return false }

        let encoded = "\(Self.formatPrefix)$\(Self.iterations)$\(salt.base64EncodedString())$\(hash.base64EncodedString())"
        guard let data = encoded.data(using: .utf8) else { return false }

        // Delete existing entry first
        deletePassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Verify a password against the stored hash (constant-time comparison).
    func verifyPassword(_ password: String) -> Bool {
        guard let stored = retrievePassword() else { return false }

        let parts = stored.split(separator: "$", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts[0] == Self.formatPrefix,
              let iterations = UInt32(parts[1]),
              let salt = Data(base64Encoded: String(parts[2])),
              let expected = Data(base64Encoded: String(parts[3])),
              let candidate = Self.deriveHash(password: password, salt: salt, iterations: iterations)
        else { return false }

        return Self.constantTimeEquals(candidate, expected)
    }

    /// Check whether a backup password exists in the Keychain.
    /// Uses attribute-only query to avoid triggering the Keychain authorization dialog.
    func hasPassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }

    /// Remove the stored password from the Keychain.
    @discardableResult
    func deletePassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private

    private static func deriveHash(password: String, salt: Data, iterations: UInt32) -> Data? {
        let passwordBytes = Array(password.utf8)
        var derived = Data(count: hashLength)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedPtr.bindMemory(to: UInt8.self).baseAddress, hashLength
                )
            }
        }
        return Int(status) == kCCSuccess ? derived : nil
    }

    private static func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[a.startIndex + i] ^ b[b.startIndex + i] }
        return diff == 0
    }

    private func retrievePassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }
}
