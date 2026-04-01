import Foundation
import Combine

class TranslatorService {
    static let shared = TranslatorService()

    private enum TranslationRequestResult {
        case success(String)
        case failure(String)
    }

    private let settings = AppSettings.shared
    private let openAICompletionsPath = "chat/completions"

    func translate(_ text: String, completion: @escaping (String) -> Void) {
        translate(text, prompt: buildPrompt(for: text), isRetry: false, completion: completion)
    }

    func cacheContextKey() -> String {
        [
            settings.provider.rawValue,
            settings.effectiveSystemPrompt,
            settings.effectiveOpenAIModel,
            settings.effectiveOpenAIBaseURL
        ].joined(separator: "|")
    }

    private func buildPrompt(for text: String) -> String {
        """
        \(settings.effectiveSystemPrompt)

        Text:
        \(text)
        """
    }

    private func buildRetryPrompt(for text: String) -> String {
        """
        You are a translator.
        Translate the input text into the opposite language:
        - If the input is Chinese, translate it to English.
        - Otherwise, translate it to Simplified Chinese.
        Return only the translated text.
        Do not repeat the source text unless the translation is exactly identical in meaning and wording.

        Text:
        \(text)
        """
    }

    private func translate(_ text: String, prompt: String, isRetry: Bool, completion: @escaping (String) -> Void) {
        requestTranslation(prompt: prompt) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let translatedRaw):
                let translated = translatedRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !isRetry && self.looksLikeEcho(of: text, response: translated) {
                    self.translate(text, prompt: self.buildRetryPrompt(for: text), isRetry: true, completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    completion(translated)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    private func requestTranslation(prompt: String, completion: @escaping (TranslationRequestResult) -> Void) {
        let endpoint = openAIEndpointURL(from: settings.effectiveOpenAIBaseURL)
        let requestBody = OpenAIChatRequest(
            model: settings.effectiveOpenAIModel,
            messages: [OpenAIChatMessage(role: "user", content: prompt)],
            temperature: 0.1
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60

        let apiKey = settings.effectiveOpenAIAPIKey
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure("Encode error"))
            return
        }

        URLSession.shared.dataTask(with: urlRequest) { data, _, error in
            if let error = error {
                completion(.failure("Error: \(error.localizedDescription)"))
                return
            }
            guard let data = data else {
                completion(.failure("No data"))
                return
            }
            do {
                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                guard let content = response.choices.first?.message.content, !content.isEmpty else {
                    completion(.failure("Parse error"))
                    return
                }
                completion(.success(content))
            } catch {
                completion(.failure("Parse error"))
            }
        }.resume()
    }

    private func openAIEndpointURL(from baseURLString: String) -> URL {
        let fallback = URL(string: "\(AppSettings.defaultOpenAIBaseURL)/\(openAICompletionsPath)")!
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmed), !trimmed.isEmpty else {
            return fallback
        }
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix(openAICompletionsPath) {
            return baseURL
        }
        return baseURL.appendingPathComponent("chat").appendingPathComponent("completions")
    }

    private func looksLikeEcho(of source: String, response: String) -> Bool {
        let normalizedSource = normalizeForComparison(source)
        let normalizedResponse = normalizeForComparison(response)
        guard !normalizedSource.isEmpty, !normalizedResponse.isEmpty else { return false }
        return normalizedSource == normalizedResponse
    }

    private func normalizeForComparison(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "")
            .replacingOccurrences(of: "\u{201D}", with: "")
            .lowercased()
    }
}
