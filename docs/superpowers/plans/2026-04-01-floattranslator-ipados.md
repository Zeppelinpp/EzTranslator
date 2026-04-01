# FloatTranslator iPadOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iPadOS branch of FloatTranslator with a Share Extension trigger and a lightweight Slide Over / Split View App for translation results.

**Architecture:** Reuse the OpenAI-compatible translation engine from the macOS codebase, strip Ollama and macOS-specific permissions/OCR, wrap it in a SwiftUI iOS App with a Share Extension that writes into an App Group shared container.

**Tech Stack:** Swift, SwiftUI, URLSession, UserDefaults App Groups, Xcode project generated via xcodegen.

---

## File Map

| File | Responsibility |
|------|----------------|
| `FloatTranslator-iPad/Core/AppSettings.swift` | Settings model, persisted to App Group UserDefaults. |
| `FloatTranslator-iPad/Core/TranslationModels.swift` | Codable structs for OpenAI-compatible API. |
| `FloatTranslator-iPad/Core/TranslatorService.swift` | Network requests, retries, echo detection. |
| `FloatTranslator-iPad/Core/SelectionMonitor.swift` | Translation state machine + in-memory cache. |
| `FloatTranslator-iPad/App/FloatTranslator_iPadApp.swift` | `@main`, `WindowGroup`, `onOpenURL` handling. |
| `FloatTranslator-iPad/App/ContentView.swift` | Top-level `TabView` switching between Translate and Settings. |
| `FloatTranslator-iPad/App/TranslationView.swift` | Scrollable translation result UI. |
| `FloatTranslator-iPad/App/SettingsView.swift` | Form-based configuration UI. |
| `FloatTranslator-iPad/App/Info.plist` | iOS app metadata, multi-tasking, URL scheme. |
| `FloatTranslator-iPad/App/FloatTranslator-iPad.entitlements` | App Group entitlement. |
| `FloatTranslator-iPad/ShareExtension/ShareViewController.swift` | Receives text from share sheet, writes to shared defaults, opens host app. |
| `FloatTranslator-iPad/ShareExtension/Info.plist` | Share extension metadata. |
| `FloatTranslator-iPad/ShareExtension/FloatTranslatorShareExtension.entitlements` | App Group entitlement for extension. |
| `FloatTranslator-iPad/project.yml` | xcodegen spec to generate the Xcode project. |

---

### Task 1: Create directory skeleton and install xcodegen

**Files:**
- Create directories under `FloatTranslator-iPad/`

- [ ] **Step 1: Create directories**

Run:
```bash
mkdir -p FloatTranslator-iPad/{Core,App,ShareExtension}
```

Expected: three empty subdirectories exist.

- [ ] **Step 2: Install xcodegen**

Run:
```bash
brew install xcodegen
```

Expected: `xcodegen --version` prints a version number.

- [ ] **Step 3: Commit skeleton**

```bash
git add FloatTranslator-iPad
git commit -m "chore: add iPadOS branch directory skeleton"
```

---

### Task 2: Write Core Layer (Settings + Models + Service + Monitor)

**Files:**
- Create: `FloatTranslator-iPad/Core/AppSettings.swift`
- Create: `FloatTranslator-iPad/Core/TranslationModels.swift`
- Create: `FloatTranslator-iPad/Core/TranslatorService.swift`
- Create: `FloatTranslator-iPad/Core/SelectionMonitor.swift`

- [ ] **Step 1: Write AppSettings.swift**

```swift
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
```

- [ ] **Step 2: Write TranslationModels.swift**

```swift
import Foundation

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
}

struct OpenAIChatChoice: Codable {
    let message: OpenAIChatMessage
}

struct OpenAIChatResponse: Codable {
    let choices: [OpenAIChatChoice]
}
```

- [ ] **Step 3: Write TranslatorService.swift**

```swift
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
```

- [ ] **Step 4: Write SelectionMonitor.swift**

```swift
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
```

- [ ] **Step 5: Verify compilation**

Skip the plain `swiftc -typecheck` because `AppSettings.swift` imports `Combine`, which requires the iOS SDK. Compilation will be verified in Task 6 after the Xcode project is generated. Just inspect the files for correctness.

Expected: all four files are present and have no obvious syntax errors.

- [ ] **Step 6: Commit Core layer**

```bash
git add FloatTranslator-iPad/Core
git commit -m "feat(ipad): add core settings, models, service, and monitor"
```

---

### Task 3: Write App UI Layer (App entry, ContentView, TranslationView, SettingsView)

**Files:**
- Create: `FloatTranslator-iPad/App/FloatTranslator_iPadApp.swift`
- Create: `FloatTranslator-iPad/App/ContentView.swift`
- Create: `FloatTranslator-iPad/App/TranslationView.swift`
- Create: `FloatTranslator-iPad/App/SettingsView.swift`

- [ ] **Step 1: Write FloatTranslator_iPadApp.swift**

```swift
import SwiftUI

@main
struct FloatTranslator_iPadApp: App {
    @StateObject private var monitor = SelectionMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
        .handlesExternalEvents(matching: ["floattranslator://translate"])
    }
}
```

- [ ] **Step 2: Write ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: SelectionMonitor

    var body: some View {
        TabView {
            TranslationView()
                .tabItem {
                    Label("Translate", systemImage: "globe")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "floattranslator", url.host == "translate" else { return }
        let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
        guard let text = defaults?.string(forKey: "pendingTranslationText"), !text.isEmpty else { return }
        defaults?.removeObject(forKey: "pendingTranslationText")
        monitor.translateText(text)
    }
}
```

- [ ] **Step 3: Write TranslationView.swift**

```swift
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
```

- [ ] **Step 4: Write SettingsView.swift**

```swift
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
```

- [ ] **Step 5: Commit App UI layer**

```bash
git add FloatTranslator-iPad/App
git commit -m "feat(ipad): add app UI entry point, translation view, and settings"
```

---

### Task 4: Write Share Extension

**Files:**
- Create: `FloatTranslator-iPad/ShareExtension/ShareViewController.swift`
- Create: `FloatTranslator-iPad/ShareExtension/Info.plist`

- [ ] **Step 1: Write ShareViewController.swift**

```swift
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            complete()
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
            itemProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                guard let text = item as? String else {
                    self?.complete()
                    return
                }

                let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
                defaults?.set(text, forKey: "pendingTranslationText")

                if let url = URL(string: "floattranslator://translate") {
                    self?.extensionContext?.open(url, completionHandler: { _ in
                        self?.complete()
                    })
                } else {
                    self?.complete()
                }
            }
        } else {
            complete()
        }
    }

    private func complete() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
```

- [ ] **Step 2: Write ShareExtension Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionMainStoryboard</key>
        <string>MainInterface</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

Wait — `NSExtensionMainStoryboard` requires a storyboard, but we want to do it programmatically. Change to `NSExtensionPrincipalClass`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

- [ ] **Step 3: Commit Share Extension**

```bash
git add FloatTranslator-iPad/ShareExtension
git commit -m "feat(ipad): add share extension to accept text and open host app"
```

---

### Task 5: Write Xcode project metadata (Info.plists, entitlements, project.yml)

**Files:**
- Create: `FloatTranslator-iPad/App/Info.plist`
- Create: `FloatTranslator-iPad/App/FloatTranslator-iPad.entitlements`
- Create: `FloatTranslator-iPad/ShareExtension/FloatTranslatorShareExtension.entitlements`
- Create: `FloatTranslator-iPad/project.yml`

- [ ] **Step 1: Write App Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>FloatTranslator</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UIRequiresFullScreen</key>
    <false/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.floattranslator.ipad</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>floattranslator</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Write App Entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.floattranslator.ipad</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Write Share Extension Entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.floattranslator.ipad</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Write project.yml**

```yaml
name: FloatTranslator-iPad
options:
  bundleIdPrefix: com.floattranslator
  deploymentTarget:
    iOS: "18.0"
targets:
  FloatTranslator-iPad:
    type: application
    platform: iOS
    sources:
      - path: App
      - path: Core
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.floattranslator.ipad
        PRODUCT_NAME: FloatTranslator
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
    info:
      path: App/Info.plist
    entitlements:
      path: App/FloatTranslator-iPad.entitlements
  FloatTranslatorShareExtension:
    type: appExtension
    platform: iOS
    sources:
      - path: ShareExtension
      - path: Core
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.floattranslator.ipad.shareextension
        PRODUCT_NAME: FloatTranslatorShareExtension
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
    info:
      path: ShareExtension/Info.plist
    entitlements:
      path: ShareExtension/FloatTranslatorShareExtension.entitlements
```

- [ ] **Step 5: Generate Xcode project**

Run:
```bash
cd FloatTranslator-iPad
xcodegen generate
```

Expected: `FloatTranslator-iPad.xcodeproj` is created successfully with no errors.

- [ ] **Step 6: Commit project metadata**

```bash
git add FloatTranslator-iPad/App/Info.plist FloatTranslator-iPad/App/FloatTranslator-iPad.entitlements FloatTranslator-iPad/ShareExtension/FloatTranslatorShareExtension.entitlements FloatTranslator-iPad/project.yml
git commit -m "feat(ipad): add info plists, entitlements, and xcodegen project spec"
```

---

### Task 6: Build and smoke test

**Files:**
- Generated: `FloatTranslator-iPad/FloatTranslator-iPad.xcodeproj`

- [ ] **Step 1: Verify Xcode project builds (simulator)**

Run:
```bash
cd FloatTranslator-iPad
xcodebuild -project FloatTranslator-iPad.xcodeproj -scheme FloatTranslator-iPad -sdk iphonesimulator build CODE_SIGNING_REQUIRED=NO
```

Expected: `** BUILD SUCCEEDED **`

If signing errors appear anyway, open the generated `.xcodeproj` in Xcode, set your development team under Signing & Capabilities for both targets, and build from there.

- [ ] **Step 2: Add generated Xcode project to gitignore (optional but recommended)**

Because `project.yml` is the source of truth, add the generated `.xcodeproj` to `.gitignore` to avoid merge conflicts:

```bash
echo "FloatTranslator-iPad/FloatTranslator-iPad.xcodeproj/" >> .gitignore
git add .gitignore
git commit -m "chore: ignore generated xcodeproj for iPadOS branch"
```

- [ ] **Step 3: Final verification checklist**

Confirm the following manually or by inspection:
- `FloatTranslator-iPad/` contains `Core/`, `App/`, `ShareExtension/`, `project.yml`.
- `App/Info.plist` has `UIRequiresFullScreen = false` and `CFBundleURLTypes` with `floattranslator` scheme.
- Both entitlements list `group.com.floattranslator.ipad`.
- `TranslatorService` has no Ollama references.
- `ContentView` reads `pendingTranslationText` from shared `UserDefaults` on `onOpenURL`.

- [ ] **Step 4: Final commit**

If all checks pass, commit any remaining changes and mark the branch ready for on-device testing.

```bash
git add -A
git commit -m "feat(ipad): complete iPadOS branch with share extension and slide over support"
```

---

## Testing Strategy

There is no unit test target in this plan because the app is UI-heavy and network-dependent; the fastest validation path is:

1. **Simulator Build** (Task 6 Step 1) guarantees there are no compilation errors.
2. **Manual end-to-end test** on iPad:
   - Build and run the main app on iPad.
   - Put the app into Slide Over.
   - Open Safari, select text, tap Share, choose FloatTranslator.
   - Verify the app receives the text and triggers translation (or at least displays the source text).
   - Verify Settings changes persist across Share Extension invocations.

---

## Known Limitations / Notes for Agent

- **App Group must be configured in Xcode Signing & Capabilities** before the Share Extension and App can share data. `xcodegen` generates the entitlements files, but you still need to toggle the App Group capability in Xcode or set the correct provisioning profile that includes `group.com.floattranslator.ipad`. For a self-use build, open the generated `.xcodeproj` in Xcode, select the target, go to Signing & Capabilities, enable App Groups, and check the group identifier.
- **No Ollama support** by design (iPad thermal/battery constraints).
- **Cache clears only on app termination** by design.
- **URL scheme `floattranslator://translate`** is hard-coded in both Share Extension and App.
