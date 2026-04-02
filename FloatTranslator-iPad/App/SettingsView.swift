import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var monitor: SelectionMonitor

    // Local state for editing
    @State private var provider: TranslationProvider = .openAICompatible
    @State private var openAIModel: String = ""
    @State private var openAIBaseURL: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var systemPrompt: String = ""

    @State private var showSavedToast = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $provider) {
                    ForEach(TranslationProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                TextField("Model", text: $openAIModel)
                TextField("Base URL", text: $openAIBaseURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                SecureField("API Key (optional)", text: $openAIAPIKey)
            }

            Section("System Prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 160)
            }

            Section {
                Button("Reset Prompt") {
                    systemPrompt = AppSettings.defaultSystemPrompt
                }

                Button("Clear Translation Cache") {
                    monitor.clearCache()
                }
                .foregroundColor(.red)
            }

            Section {
                Button(action: saveSettings) {
                    HStack {
                        Spacer()
                        Text("Confirm & Save")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!hasChanges())
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadFromSettings()
        }
        .overlay(
            VStack {
                Spacer()
                if showSavedToast {
                    Text("Settings Saved")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        )
    }

    private func loadFromSettings() {
        provider = settings.provider
        openAIModel = settings.openAIModel
        openAIBaseURL = settings.openAIBaseURL
        openAIAPIKey = settings.openAIAPIKey
        systemPrompt = settings.systemPrompt
    }

    private func hasChanges() -> Bool {
        provider != settings.provider ||
        openAIModel != settings.openAIModel ||
        openAIBaseURL != settings.openAIBaseURL ||
        openAIAPIKey != settings.openAIAPIKey ||
        systemPrompt != settings.systemPrompt
    }

    private func saveSettings() {
        settings.provider = provider
        settings.openAIModel = openAIModel
        settings.openAIBaseURL = openAIBaseURL
        settings.openAIAPIKey = openAIAPIKey
        settings.systemPrompt = systemPrompt

        monitor.clearCache()

        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedToast = false
            }
        }
    }
}
