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
                    Toggle("Use Apple Watch to unlock", isOn: $settings.useWatchUnlock)
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
                Section("Paired Watch") {
                    if let watchID = watchService.pairedWatchIdentifier {
                        HStack {
                            Image(systemName: "applewatch")
                                .font(.system(size: 24))
                                .foregroundColor(watchService.isWatchInRange ? BonsoirNonColors.success : BonsoirNonColors.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Watch")
                                    .font(BonsoirNonTypography.body)
                                Text(watchService.isWatchInRange ? "In range" : "Out of range")
                                    .font(BonsoirNonTypography.caption)
                                    .foregroundColor(watchService.isWatchInRange ? BonsoirNonColors.success : .secondary)
                            }

                            Spacer()

                            Button("Unpair") {
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
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(watchID.uuidString, forType: .string)
                                }
                            }
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching for Apple Watch...")
                                .font(BonsoirNonTypography.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        Text("Make sure your Apple Watch is unlocked, on your wrist, and nearby.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Sensitivity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Range:")
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

                        Text("Lower sensitivity means the Watch can be farther away. Higher sensitivity requires the Watch to be closer.")
                            .font(BonsoirNonTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("How it works") {
                Text("When your Apple Watch is nearby, Bonsoir, non can automatically unlock protected apps without requiring Touch ID or a password. If the Watch moves out of range, apps will be locked again.")
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
                Text("Bluetooth is on")
                    .font(BonsoirNonTypography.body)
            }

        case .poweredOff:
            HStack(spacing: 8) {
                Image(systemName: "bluetooth")
                    .foregroundColor(BonsoirNonColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth is off")
                        .font(BonsoirNonTypography.body)
                    Text("Turn on Bluetooth in System Settings to use Apple Watch unlock.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .unauthorized:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(BonsoirNonColors.locked)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth Permission Required")
                        .font(BonsoirNonTypography.body)
                    Text("Bonsoir, non needs Bluetooth access to detect your Apple Watch. Grant permission in System Settings → Privacy & Security → Bluetooth.")
                        .font(BonsoirNonTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .unsupported:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(BonsoirNonColors.error)
                Text("Bluetooth is not supported on this Mac")
                    .font(BonsoirNonTypography.body)
            }

        case .unknown:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking Bluetooth status...")
                    .font(BonsoirNonTypography.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sensitivityLabel: String {
        switch sensitivity {
        case 0..<30: return "Far"
        case 30..<70: return "Medium"
        default: return "Close"
        }
    }
}
