import Foundation
import Combine

enum TranslationProvider: String, CaseIterable, Identifiable {
    case openAICompatible = "openai_compatible"
    var id: String { rawValue }
    var displayName: String { "OpenAI-Compatible" }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let appGroupID = "group.com.floattranslator.ipad"
    static let defaultOpenAIModel = "gpt-4.1-mini"
    static let defaultOpenAIBaseURL = "https://api.openai.com/v1"
    static let defaultSystemPrompt = """
    You are a translation engine.
    If the source text is Chinese, translate it to English.
    Otherwise, translate it to Simplified Chinese.
    Output only the translation.
    Preserve meaning, tone, punctuation, numbers, casing, and line breaks.
    Do not explain, annotate, add alternatives, or use quotation marks.
    """

    private let defaults: UserDefaults
    private enum Keys {
        static let provider = "FloatTranslatorProvider"
        static let systemPrompt = "FloatTranslatorSystemPrompt"
        static let openAIModel = "FloatTranslatorOpenAIModel"
        static let openAIBaseURL = "FloatTranslatorOpenAIBaseURL"
        static let openAIAPIKey = "FloatTranslatorOpenAIAPIKey"
    }

    @Published var provider: TranslationProvider {
        didSet { save(provider.rawValue, forKey: Keys.provider) }
    }

    @Published var systemPrompt: String {
        didSet { save(systemPrompt, forKey: Keys.systemPrompt) }
    }

    @Published var openAIModel: String {
        didSet { save(openAIModel, forKey: Keys.openAIModel) }
    }

    @Published var openAIBaseURL: String {
        didSet { save(openAIBaseURL, forKey: Keys.openAIBaseURL) }
    }

    @Published var openAIAPIKey: String {
        didSet { save(openAIAPIKey, forKey: Keys.openAIAPIKey) }
    }

    private init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        let providerRaw = defaults.string(forKey: Keys.provider) ?? TranslationProvider.openAICompatible.rawValue
        provider = TranslationProvider(rawValue: providerRaw) ?? .openAICompatible
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? Self.defaultOpenAIModel
        openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL) ?? Self.defaultOpenAIBaseURL
        openAIAPIKey = defaults.string(forKey: Keys.openAIAPIKey) ?? ""
    }

    var effectiveSystemPrompt: String {
        let trimmed = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultSystemPrompt : trimmed
    }

    var effectiveOpenAIModel: String {
        let trimmed = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultOpenAIModel : trimmed
    }

    var effectiveOpenAIBaseURL: String {
        let trimmed = openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultOpenAIBaseURL : trimmed
    }

    var effectiveOpenAIAPIKey: String {
        openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resetSystemPrompt() {
        systemPrompt = Self.defaultSystemPrompt
    }

    private func save(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
