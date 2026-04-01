import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var monitor: SelectionMonitor

    var body: some View {
        NavigationView {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $settings.provider) {
                        ForEach(TranslationProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    TextField("Model", text: $settings.openAIModel)
                    TextField("Base URL", text: $settings.openAIBaseURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("API Key (optional)", text: $settings.openAIAPIKey)
                }

                Section("System Prompt") {
                    TextEditor(text: $settings.systemPrompt)
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 160)
                }

                Section {
                    Button("Reset Prompt") {
                        settings.resetSystemPrompt()
                        monitor.clearCache()
                    }

                    Button("Clear Translation Cache") {
                        monitor.clearCache()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
