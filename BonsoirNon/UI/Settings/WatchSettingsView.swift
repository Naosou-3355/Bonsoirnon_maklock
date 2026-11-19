import SwiftUI

/// Watch settings tab: Apple Watch proximity unlock with pairing and sensitivity.
struct WatchSettingsView: View {
    @ObservedObject private var watchService = WatchProximityService.shared
    @State private var settings = Defaults.shared.appSettings
    @State private var sensitivity: Double = {
        let rssi = Double(Defaults.shared.appSettings.watchRssiThreshold)
        return ((rssi + 90) / 40.0) * 100
    }()

    var body: some View {
        Form {
            // Bluetooth status
            Section {
                bluetoothStatusRow

                if watchService.bluetoothState == .poweredOn || watchService.bluetoothState == .unknown {
                    Toggle("Déverrouiller avec l'Apple Watch", isOn: $settings.useWatchUnlock)
                        .onChange(of: settings.useWatchUnlock) { _, enabled in
                            Defaults.shared.appSettings = settings
                            if enabled {
                                watchService.startScanning()
                            } else {
                                watchService.stopScanning()
                            }
                        }
                }
            }

            if settings.useWatchUnlock && watchService.bluetoothState == .poweredOn {
                Section("Montre associée") {
                    if let watchID = watchService.pairedWatchIdentifier {
                        HStack {
                            Image(systemName: "applewatch")
                                .font(.system(size: 24))
                                .foregroundColor(watchService.isWatchInRange ? BonsoirNonColors.success : BonsoirNonColors.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Watch")
                                    .font(BonsoirNonTypography.body)
                                Text(watchService.isWatchInRange ? "À portée" : "Hors de portée")
                                    .font(BonsoirNonTypography.caption)
                                    .foregroundColor(watchService.isWatchInRange ? BonsoirNonColors.success : .secondary)
                            }

                            Spacer()

                            Button("Dissocier") {
                                watchService.unpair()
                                settings.useWatchUnlock = false
                                Defaults.shared.appSettings = settings
                            }
                            .foregroundColor(BonsoirNonColors.error)
                        }
                        .padding(.vertical, 4)

                        // UUID copyable via context menu (NOT .textSelection — causes layout loop in TabView)
                        Text(watchID.uuidString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .contextMenu {
                                Button("Copier") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(watchID.uuidString, forType: .string)
                                }
                            }
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Recherche des montres à proximité…")
                                .font(BonsoirNonTypography.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        Text("Mets ta montre au poignet, déverrouillée, tout près du Mac, puis choisis-la. La plus proche est en haut.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)

                        ForEach(watchService.candidates) { candidate in
                            HStack {
                                Image(systemName: "applewatch")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(BonsoirNonTypography.body)
                                    Text("Signal : \(candidate.rssi) dBm")
                                        .font(BonsoirNonTypography.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("C'est ma montre") {
                                    // A paired Watch can unlock every app: prove it's you.
                                    AuthenticationService.shared.confirmSensitiveAction(
                                        reason: "Appairer « \(candidate.name) » pour déverrouiller tes apps"
                                    ) { success in
                                        if success { watchService.pair(with: candidate.id) }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Sensibilité") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Portée :")
                            Slider(value: $sensitivity, in: 0...100, step: 10)
                                .onChange(of: sensitivity) { _, value in
                                    let rssi = Int(-90 + (value / 100.0) * 40)
                                    watchService.rssiThreshold = rssi
                                    var s = Defaults.shared.appSettings
                                    s.watchRssiThreshold = rssi
                                    Defaults.shared.appSettings = s
                                }
                            Text(sensitivityLabel)
                                .frame(width: 50, alignment: .trailing)
                                .font(BonsoirNonTypography.caption)
                                .monospacedDigit()
                        }

                        Text("Sensibilité basse : la montre peut être plus loin. Sensibilité haute : elle doit être plus près.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Fonctionnement") {
                Text("Quand ton Apple Watch est à proximité, Bonsoir, non déverrouille les apps protégées sans Touch ID ni mot de passe. Si elle s'éloigne, les apps se reverrouillent.")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Bluetooth Status

    @ViewBuilder
    private var bluetoothStatusRow: some View {
        switch watchService.bluetoothState {
        case .poweredOn:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(BonsoirNonColors.success)
                Text("Bluetooth activé")
                    .font(BonsoirNonTypography.body)
            }

        case .poweredOff:
            HStack(spacing: 8) {
                Image(systemName: "bluetooth")
                    .foregroundColor(BonsoirNonColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth désactivé")
                        .font(BonsoirNonTypography.body)
                    Text("Active le Bluetooth dans Réglages Système pour déverrouiller avec l'Apple Watch.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .unauthorized:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(BonsoirNonColors.locked)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autorisation Bluetooth nécessaire")
                        .font(BonsoirNonTypography.body)
                    Text("Bonsoir, non a besoin du Bluetooth pour détecter ton Apple Watch. Autorise-le dans Réglages Système → Confidentialité et sécurité → Bluetooth.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .unsupported:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(BonsoirNonColors.error)
                Text("Bluetooth n'est pas pris en charge sur ce Mac")
                    .font(BonsoirNonTypography.body)
            }

        case .unknown:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Vérification du Bluetooth…")
                    .font(BonsoirNonTypography.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sensitivityLabel: String {
        switch sensitivity {
        case 0..<30: return "Loin"
        case 30..<70: return "Moyen"
        default: return "Proche"
        }
    }
}
