import Foundation
import Combine

class SelectionMonitor: ObservableObject {
    @Published var selectedText: String = ""
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var status: String = "Share text to translate"

    private let idleStatus = "Share text to translate"
    private var requestID: Int = 0
    private var translationCache: [String: String] = [:]

    func clearTransientContent() {
        requestID += 1
        selectedText = ""
        translatedText = ""
        isTranslating = false
        status = idleStatus
    }

    func clearCache() {
        translationCache.removeAll()
        clearTransientContent()
    }

    func translateText(_ text: String) {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            clearTransientContent()
            return
        }

        selectedText = candidate
        let cacheKey = "\(TranslatorService.shared.cacheContextKey())::\(candidate)"

        if let cached = translationCache[cacheKey] {
            translatedText = cached
            isTranslating = false
            status = idleStatus
            return
        }

        requestID += 1
        let currentRequestID = requestID

        translatedText = ""
        isTranslating = true
        status = "Translating..."

        TranslatorService.shared.translate(candidate) { [weak self] result in
            guard let self, self.requestID == currentRequestID else { return }

            self.translatedText = result
            self.isTranslating = false
            self.status = self.idleStatus

            if !result.hasPrefix("Error:") &&
                result != "Parse error" &&
                result != "No data" &&
                result != "Encode error" &&
                result != candidate {
                self.translationCache[cacheKey] = result
            }
        }
    }
}
