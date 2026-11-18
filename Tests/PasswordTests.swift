import Foundation
import Security

func passwordTests() {
    let service = "com.bonsoirnon.selftest"
    let kc = KeychainManager(service: service)
    kc.deletePassword()
    defer { kc.deletePassword() }

    suite("Password: hashing and verification") {
        check(kc.savePassword("bonne-nuit-été"), "save")
        check(kc.hasPassword(), "hasPassword")
        check(kc.verifyPassword("bonne-nuit-été"), "correct password (unicode)")
        check(!kc.verifyPassword("bonne-nuit-ete"), "wrong password rejected")
        check(!kc.verifyPassword(""), "empty password rejected")
    }

    suite("Password: stored as PBKDF2, never in clear, random salt") {
        func stored() -> String {
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: "backup-password-hash",
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var r: AnyObject?
            SecItemCopyMatching(q as CFDictionary, &r)
            return String(data: (r as? Data) ?? Data(), encoding: .utf8) ?? ""
        }
        kc.savePassword("bonne-nuit-été")
        let first = stored()
        let parts = first.split(separator: "$")
        check(parts.count == 4 && parts[0] == "pbkdf2-sha256" && parts[1] == "600000", "format")
        check(!first.contains("bonne-nuit"), "no plaintext")
        kc.savePassword("bonne-nuit-été")
        check(stored() != first, "salt differs per save")
    }

    suite("Password: legacy/malformed entry never verifies") {
        kc.deletePassword()
        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                  kSecAttrAccount as String: "backup-password-hash",
                                  kSecValueData as String: Data("legacy-plain".utf8)]
        SecItemAdd(add as CFDictionary, nil)
        check(!kc.verifyPassword("legacy-plain"), "legacy entry rejected")
    }
}
