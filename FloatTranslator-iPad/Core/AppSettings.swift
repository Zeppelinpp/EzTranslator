import Foundation
import Combine
import Security

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

    // NOTE: Using UserDefaults instead of Keychain for ShareExtension compatibility
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

        // Try to load API Key from UserDefaults first, then migrate from Keychain if needed
        let savedKey = defaults.string(forKey: Keys.openAIAPIKey) ?? ""
        if !savedKey.isEmpty {
            openAIAPIKey = savedKey
        } else {
            // Migration: try to load from old Keychain storage
            openAIAPIKey = Self.migrateKeychainAPIKey(to: defaults) ?? ""
        }
    }

    /// Migrate API Key from old Keychain storage to UserDefaults
    private static func migrateKeychainAPIKey(to defaults: UserDefaults) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.appGroupID,
            kSecAttrAccount as String: Keys.openAIAPIKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        // Save to UserDefaults for future access
        defaults.set(apiKey, forKey: Keys.openAIAPIKey)
        // Optionally delete from Keychain
        SecItemDelete(query as CFDictionary)
        return apiKey
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
