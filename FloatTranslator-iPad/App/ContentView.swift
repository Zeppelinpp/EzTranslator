import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: SelectionMonitor

    var body: some View {
        TabView {
            TranslationView()
                .tabItem {
                    Label("Translate", systemImage: "globe")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "floattranslator", url.host == "translate" else { return }
        let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
        guard let text = defaults?.string(forKey: "pendingTranslationText"), !text.isEmpty else { return }
        defaults?.removeObject(forKey: "pendingTranslationText")
        monitor.translateText(text)
    }
}
