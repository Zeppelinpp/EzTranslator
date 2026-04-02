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
        print("[App] handleOpenURL called with: \(url)")
        guard url.scheme == "floattranslator", url.host == "translate" else {
            print("[App] URL scheme/host mismatch")
            return
        }
        let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
        let queueKey = "translationQueue"

        guard let data = defaults?.data(forKey: queueKey) else {
            print("[App] No data in UserDefaults for key: \(queueKey)")
            return
        }
        guard var queue = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            print("[App] Failed to parse queue data")
            return
        }
        guard !queue.isEmpty else {
            print("[App] Queue is empty")
            return
        }
        print("[App] Queue has \(queue.count) item(s)")

        let item = queue.removeFirst()
        if let remainingData = try? JSONSerialization.data(withJSONObject: queue) {
            defaults?.set(remainingData, forKey: queueKey)
        } else {
            defaults?.removeObject(forKey: queueKey)
        }

        guard let text = item["text"], !text.isEmpty else {
            print("[App] Text is empty or missing")
            return
        }
        print("[App] Calling translateText with text (first 50 chars): \(text.prefix(50))...")
        monitor.translateText(text)
    }
}
