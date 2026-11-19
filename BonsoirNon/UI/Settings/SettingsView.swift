import SwiftUI

/// Root settings view with tabbed navigation.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Général", systemImage: "gearshape")
                }

            AppsSettingsView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            SecuritySettingsView()
                .tabItem {
                    Label("Sécurité", systemImage: "lock.shield")
                }

            WatchSettingsView()
                .tabItem {
                    Label("Montre", systemImage: "applewatch")
                }

            ActivitySettingsView()
                .tabItem {
                    Label("Journal", systemImage: "list.bullet.rectangle")
                }
        }
        .frame(width: 520, height: 400)
    }
}
