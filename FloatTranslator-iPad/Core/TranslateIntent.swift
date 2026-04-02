import AppIntents
import Foundation

struct TranslateIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Translate selected text using FloatTranslator")

    @Parameter(title: "Text", description: "The text to translate")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Translate $\text")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard !text.isEmpty else {
            throw IntentError.message("Text cannot be empty")
        }

        let result = await withCheckedContinuation { continuation in
            TranslatorService.shared.translate(text) { result in
                continuation.resume(returning: result)
            }
        }

        if result.hasPrefix("Error:") || result == "Parse error" || result == "No data" {
            throw IntentError.message("Translation failed: \(result)")
        }

        return .result(value: result)
    }
}

enum IntentError: Error {
    case message(String)
}

extension IntentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}
