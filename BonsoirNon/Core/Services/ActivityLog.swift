import Foundation

/// Records unlocks, failed attempts and protection changes, newest first.
/// Stored in the Keychain (like the settings) so it can't be wiped from Terminal.
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    private static let account = "activity-log"

    @Published private(set) var history = ActivityHistory()

    private init() {
        if let data = KeychainManager.shared.data(forAccount: Self.account),
           let saved = try? JSONDecoder().decode(ActivityHistory.self, from: data) {
            history = saved
        }
    }

    func record(_ kind: ActivityKind, app appName: String? = nil) {
        let event = ActivityEvent(date: Date(), kind: kind, appName: appName)
        DispatchQueue.main.async {
            self.history.append(event)
            self.save()
        }
    }

    /// Erase the log (Settings asks for Touch ID first).
    func clear() {
        history.clear()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            KeychainManager.shared.setData(data, forAccount: Self.account)
        }
    }
}
