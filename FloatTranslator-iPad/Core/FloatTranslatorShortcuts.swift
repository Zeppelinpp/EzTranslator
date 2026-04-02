import AppIntents

struct FloatTranslatorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateIntent(),
            phrases: [
                "Translate text with \(.applicationName)",
                "Translate using \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "globe"
        )
    }
}
