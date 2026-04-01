import SwiftUI

struct TranslationView: View {
    @EnvironmentObject var monitor: SelectionMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !monitor.selectedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(monitor.selectedText)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    Divider()
                }

                if monitor.isTranslating {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Translating...")
                            .foregroundColor(.secondary)
                    }
                } else if !monitor.translatedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(monitor.translatedText)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                } else {
                    Text(monitor.status)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
