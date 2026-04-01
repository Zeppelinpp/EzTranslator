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
        let queueKey = "translationQueue"

        guard let data = defaults?.data(forKey: queueKey),
              var queue = try? JSONSerialization.jsonObject(with: data) as? [[String: String]],
              !queue.isEmpty else { return }

        let item = queue.removeFirst()
        if let remainingData = try? JSONSerialization.data(withJSONObject: queue) {
            defaults?.set(remainingData, forKey: queueKey)
        } else {
            defaults?.removeObject(forKey: queueKey)
        }

        guard let text = item["text"], !text.isEmpty else { return }
        monitor.translateText(text)
    }
}
