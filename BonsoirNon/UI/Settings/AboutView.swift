import SwiftUI

/// About window showing app version, credits, and links.
struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            // App name
            Text("Bonsoir, non")
                .font(BonsoirNonTypography.largeTitle)

            // Version
            Text("Version \(version) (\(build))")
                .font(BonsoirNonTypography.caption)
                .foregroundColor(.secondary)

            // Description
            Text("Verrouille n'importe quelle app avec Touch ID ou un mot de passe.")
                .font(BonsoirNonTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            // Credits
            VStack(spacing: 4) {
                Text("Basé sur MakLock de Maciej Dutkiewicz")
                    .font(BonsoirNonTypography.body)
                Text("Libre et open source, licence MIT")
                    .font(BonsoirNonTypography.caption)
                    .foregroundColor(.secondary)
            }

            // GitHub link
            Link(destination: URL(string: "https://github.com/Naosou-3355/Bonsoirnon_maklock")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text("github.com/Naosou-3355/Bonsoirnon_maklock")
                        .font(BonsoirNonTypography.caption)
                }
            }
        }
        .padding(32)
        .frame(width: 360, height: 380)
    }
}
