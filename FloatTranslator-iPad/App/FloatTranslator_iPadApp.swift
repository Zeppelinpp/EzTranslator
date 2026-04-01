import SwiftUI

@main
struct FloatTranslator_iPadApp: App {
    @StateObject private var monitor = SelectionMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
        .handlesExternalEvents(matching: ["translate"])
    }
}
