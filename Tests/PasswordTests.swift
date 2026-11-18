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

func lockoutAndStorageTests() {
    let t0 = Date(timeIntervalSince1970: 0)

    suite("Lockout: 5 free attempts, then 30 s doubling, capped at 15 min") {
        var l = PasswordLockout()
        for i in 1...4 { check(l.recordFailure(at: t0) == nil, "failure \(i) is free") }
        check(l.recordFailure(at: t0) == 30, "5th failure locks 30 s")
        check(l.secondsRemaining(at: t0 + 10) == 20, "20 s left after 10 s")
        check(l.secondsRemaining(at: t0 + 31) == nil, "unlocked after 30 s")
        check(l.recordFailure(at: t0 + 31) == 60, "6th failure locks 60 s")
        var big = PasswordLockout()
        for _ in 1...30 { _ = big.recordFailure(at: t0) }
        check(big.secondsRemaining(at: t0) == 15 * 60, "capped at 15 min")
        l.recordSuccess()
        check(l.failures == 0 && l.secondsRemaining(at: t0 + 31) == nil, "success resets")
    }

    suite("Lockout: survives a restart (round-trips through the Keychain)") {
        let kc = KeychainManager(service: "com.bonsoirnon.selftest")
        defer { kc.removeData(forAccount: "password-lockout") }
        var l = PasswordLockout()
        for _ in 1...5 { _ = l.recordFailure(at: t0) }
        check(kc.setData(try! JSONEncoder().encode(l), forAccount: "password-lockout"), "save")
        let back = kc.data(forAccount: "password-lockout").flatMap { try? JSONDecoder().decode(PasswordLockout.self, from: $0) }
        check(back == l, "same state after reload")
    }

    suite("Keychain storage: set, overwrite, read, remove") {
        let kc = KeychainManager(service: "com.bonsoirnon.selftest")
        defer { kc.removeData(forAccount: "blob") }
        check(kc.setData(Data("a".utf8), forAccount: "blob"), "add")
        check(kc.setData(Data("b".utf8), forAccount: "blob"), "overwrite")
        check(kc.data(forAccount: "blob") == Data("b".utf8), "read latest")
        check(kc.removeData(forAccount: "blob"), "remove")
        check(kc.data(forAccount: "blob") == nil, "gone")
    }
}
