import SwiftUI

/// Settings tab listing what happened: unlocks, failed attempts, protection changes.
struct ActivitySettingsView: View {
    @ObservedObject private var log = ActivityLog.shared
    @State private var onlySuspicious = false

    private var events: [ActivityEvent] {
        onlySuspicious ? log.history.events.filter { $0.kind.isSuspicious } : log.history.events
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Journal")
                    .font(BonsoirNonTypography.title)
                Spacer()
                Toggle("Tentatives suspectes seulement", isOn: $onlySuspicious)
                    .toggleStyle(.checkbox)
            }

            if events.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundColor(BonsoirNonColors.textSecondary)
                    Text(onlySuspicious ? "Aucune tentative suspecte" : "Rien pour l'instant")
                        .font(BonsoirNonTypography.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(events) { event in
                    HStack(spacing: 10) {
                        Image(systemName: Self.icon(for: event.kind))
                            .foregroundColor(event.kind.isSuspicious ? BonsoirNonColors.error : BonsoirNonColors.success)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.text(for: event))
                                .font(BonsoirNonTypography.body)
                            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(BonsoirNonTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                Text("Les 200 derniers événements sont gardés.")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Effacer le journal…") {
                    AuthenticationService.shared.confirmSensitiveAction(reason: "Effacer le journal de Bonsoir, non") { success in
                        if success { log.clear() }
                    }
                }
                .disabled(log.history.events.isEmpty)
            }
        }
        .padding()
    }

    static func icon(for kind: ActivityKind) -> String {
        switch kind {
        case .unlockTouchID: return "touchid"
        case .unlockPassword: return "key.fill"
        case .unlockWatch: return "applewatch"
        case .touchIDFailed: return "touchid"
        case .wrongPassword: return "key.slash"
        case .passwordLockedOut: return "hourglass"
        case .lockTimedOut: return "clock.badge.exclamationmark"
        case .protectionTurnedOff: return "shield.slash"
        case .appUnprotected: return "minus.circle"
        case .quitRefused: return "xmark.octagon"
        case .lockAllNow: return "lock.fill"
        }
    }

    static func text(for event: ActivityEvent) -> String {
        let app = event.appName ?? "une app"
        switch event.kind {
        case .unlockTouchID: return "\(app) déverrouillé avec Touch ID"
        case .unlockPassword: return "\(app) déverrouillé avec le mot de passe"
        case .unlockWatch: return "\(app) déverrouillé par l'Apple Watch"
        case .touchIDFailed: return "Touch ID refusé pour \(app)"
        case .wrongPassword: return "Mauvais mot de passe pour \(app)"
        case .passwordLockedOut: return "Trop d'essais : mot de passe bloqué (\(app))"
        case .lockTimedOut: return "Écran de verrouillage laissé sans réponse (\(app))"
        case .protectionTurnedOff: return "Protection coupée"
        case .appUnprotected: return "\(app) retiré ou désactivé de la protection"
        case .quitRefused: return "Tentative de fermer Bonsoir, non refusée"
        case .lockAllNow: return "Tout verrouillé maintenant"
        }
    }
}
