import Cocoa
import SwiftUI
import ApplicationServices
import ScreenCaptureKit
import Vision
import Combine

private let floatingWindowMinWidth: CGFloat = 220
private let floatingWindowMaxWidth: CGFloat = 540
private let floatingWindowMinHeight: CGFloat = 72
private let floatingWindowMaxHeight: CGFloat = 420

enum TranslationProvider: String, CaseIterable, Identifiable {
    case ollama
    case openAICompatible = "openai_compatible"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .openAICompatible:
            return "OpenAI-Compatible"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultOllamaModel = "qwen2.5:0.5b"
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

    private enum Keys {
        static let provider = "FloatTranslatorProvider"
        static let systemPrompt = "FloatTranslatorSystemPrompt"
        static let ollamaModel = "FloatTranslatorOllamaModel"
        static let openAIModel = "FloatTranslatorOpenAIModel"
        static let openAIBaseURL = "FloatTranslatorOpenAIBaseURL"
        static let openAIAPIKey = "FloatTranslatorOpenAIAPIKey"
    }

    @Published var provider: TranslationProvider {
        didSet {
            save(provider.rawValue, forKey: Keys.provider)
        }
    }

    @Published var systemPrompt: String {
        didSet {
            save(systemPrompt, forKey: Keys.systemPrompt)
        }
    }

    @Published var ollamaModel: String {
        didSet {
            save(ollamaModel, forKey: Keys.ollamaModel)
        }
    }

    @Published var openAIModel: String {
        didSet {
            save(openAIModel, forKey: Keys.openAIModel)
        }
    }

    @Published var openAIBaseURL: String {
        didSet {
            save(openAIBaseURL, forKey: Keys.openAIBaseURL)
        }
    }

    @Published var openAIAPIKey: String {
        didSet {
            save(openAIAPIKey, forKey: Keys.openAIAPIKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let providerRaw = defaults.string(forKey: Keys.provider) ?? TranslationProvider.ollama.rawValue
        provider = TranslationProvider(rawValue: providerRaw) ?? .ollama
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? Self.defaultOllamaModel
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? Self.defaultOpenAIModel
        openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL) ?? Self.defaultOpenAIBaseURL
        openAIAPIKey = defaults.string(forKey: Keys.openAIAPIKey) ?? ""
    }

    var effectiveSystemPrompt: String {
        let trimmed = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultSystemPrompt : trimmed
    }

    var effectiveOllamaModel: String {
        let trimmed = ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultOllamaModel : trimmed
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
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - Provider APIs
struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Codable {
    let temperature: Double
}

struct OllamaResponse: Codable {
    let response: String
}

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

class TranslatorService {
    static let shared = TranslatorService()

    private enum TranslationRequestResult {
        case success(String)
        case failure(String)
    }

    private let settings = AppSettings.shared
    private let ollamaURL = URL(string: "http://localhost:11434/api/generate")!
    private let openAICompletionsPath = "chat/completions"

    func translate(_ text: String, completion: @escaping (String) -> Void) {
        translate(text, prompt: buildPrompt(for: text), isRetry: false, completion: completion)
    }

    func cacheContextKey() -> String {
        [
            settings.provider.rawValue,
            settings.effectiveSystemPrompt,
            settings.effectiveOllamaModel,
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
        switch settings.provider {
        case .ollama:
            requestOllamaTranslation(prompt: prompt, completion: completion)
        case .openAICompatible:
            requestOpenAICompatibleTranslation(prompt: prompt, completion: completion)
        }
    }

    private func requestOllamaTranslation(prompt: String, completion: @escaping (TranslationRequestResult) -> Void) {
        let request = OllamaRequest(
            model: settings.effectiveOllamaModel,
            prompt: prompt,
            stream: false,
            options: OllamaOptions(temperature: 0.1)
        )

        var urlRequest = URLRequest(url: ollamaURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
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
                let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
                completion(.success(response.response))
            } catch {
                completion(.failure("Parse error"))
            }
        }.resume()
    }

    private func requestOpenAICompatibleTranslation(prompt: String, completion: @escaping (TranslationRequestResult) -> Void) {
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
                guard let content = response.choices.first?.message.content,
                      !content.isEmpty else {
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

        return baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
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
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .lowercased()
    }
}

// MARK: - Hover Translation State
class SelectionMonitor: ObservableObject {
    @Published var selectedText: String = ""
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var status: String = "Hold Option over a word to translate"

    private let idleStatus = "Hold Option over a word to translate"
    private var requestID: Int = 0
    private var translationCache: [String: String] = [:]

    func showIdleStatus() {
        if selectedText.isEmpty && translatedText.isEmpty && !isTranslating {
            status = idleStatus
        }
    }

    func showPermissionStatus() {
        selectedText = ""
        translatedText = ""
        isTranslating = false
        status = "Enable Screen Recording permission for FloatTranslator"
    }

    func showSelectionPermissionStatus() {
        selectedText = ""
        translatedText = ""
        isTranslating = false
        status = "Enable Accessibility permission for selected-text translation"
    }

    func clearTransientContent() {
        requestID += 1
        selectedText = ""
        translatedText = ""
        isTranslating = false
        status = idleStatus
    }

    func clearCache() {
        clearCache(keepCurrentContent: false)
    }

    func clearCache(keepCurrentContent: Bool) {
        translationCache.removeAll()
        if !keepCurrentContent {
            clearTransientContent()
        }
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

// MARK: - Accessibility Hover Reader
class HoverTextService {
    private let ocrCaptureSize = CGSize(width: 320, height: 120)

    func requestScreenCaptureAccessIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func hoveredWordUsingOCR(at point: CGPoint) -> String? {
        guard let image = captureImage(around: point) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        let captureRect = captureRect(around: point)
        let localPoint = CGPoint(x: point.x - captureRect.minX, y: point.y - captureRect.minY)

        let matches: [(text: String, distance: CGFloat)] = ocrTokenMatches(from: observations, imageSize: captureRect.size).map { match in
            (match.text, distanceFrom(point: localPoint, to: match.rect))
        }

        guard !matches.isEmpty else { return nil }

        let bestMatch = matches.min { lhs, rhs in
            if abs(lhs.distance - rhs.distance) < 1 {
                return lhs.text.count < rhs.text.count
            }
            return lhs.distance < rhs.distance
        }

        return bestMatch?.text
    }

    private func captureImage(around point: CGPoint) -> CGImage? {
        guard #available(macOS 15.2, *) else { return nil }

        let rect = captureRect(around: point)
        let semaphore = DispatchSemaphore(value: 0)
        var image: CGImage?

        SCScreenshotManager.captureImage(in: rect) { capturedImage, _ in
            image = capturedImage
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 1)
        return image
    }

    private func captureRect(around point: CGPoint) -> CGRect {
        CGRect(
            x: point.x - (ocrCaptureSize.width / 2),
            y: point.y - (ocrCaptureSize.height / 2),
            width: ocrCaptureSize.width,
            height: ocrCaptureSize.height
        )
    }

    private func convertObservationRect(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.minX * imageSize.width,
            y: (1 - normalizedRect.maxY) * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
    }

    private func ocrTokenMatches(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [(text: String, rect: CGRect)] {
        var matches: [(text: String, rect: CGRect)] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let tokenMatches = tokenRanges(in: candidate.string).compactMap { range -> (text: String, rect: CGRect)? in
                guard let box = try? candidate.boundingBox(for: range),
                      let normalized = normalizeCandidate(String(candidate.string[range])) else {
                    return nil
                }

                return (normalized, convertObservationRect(box.boundingBox, imageSize: imageSize))
            }

            if !tokenMatches.isEmpty {
                matches.append(contentsOf: tokenMatches)
                continue
            }

            if let normalized = normalizeCandidate(candidate.string) {
                matches.append((normalized, convertObservationRect(observation.boundingBox, imageSize: imageSize)))
            }
        }

        return matches
    }

    private func tokenRanges(in text: String) -> [Range<String.Index>] {
        let pattern = #"[[:script=Han:]]+|[\p{L}\p{N}][\p{L}\p{N}'._-]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            Range(match.range, in: text)
        }
    }

    private func distanceFrom(point: CGPoint, to rect: CGRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return sqrt((dx * dx) + (dy * dy))
    }

    private func normalizeCandidate(_ text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty,
              cleaned.count <= 80,
              cleaned.lowercased() != "terminal pane" else {
            return nil
        }
        return cleaned
    }
}

class SelectedTextService {
    private let minimumAttemptInterval: TimeInterval = 0.8
    private var lastAttemptAt: Date = .distantPast
    private var cachedSelection: String?
    private let trustedPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

    func reset() {
        lastAttemptAt = .distantPast
        cachedSelection = nil
    }

    func requestTrustIfNeeded() -> Bool {
        let options = [trustedPromptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func selectedText() -> String? {
        guard isTrusted() else { return nil }

        let now = Date()
        if now.timeIntervalSince(lastAttemptAt) < minimumAttemptInterval {
            return cachedSelection
        }

        lastAttemptAt = now
        cachedSelection = captureSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cachedSelection?.isEmpty == true {
            cachedSelection = nil
        }
        return cachedSelection
    }

    private func captureSelectedText() -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let initialChangeCount = pasteboard.changeCount
        let initialString = pasteboard.string(forType: .string)

        defer {
            restorePasteboard(snapshot, to: pasteboard)
        }

        guard triggerCopyShortcut() else { return nil }

        for _ in 0..<30 {
            Thread.sleep(forTimeInterval: 0.05)

            if let copied = pasteboard.string(forType: .string),
               !copied.isEmpty,
               (pasteboard.changeCount != initialChangeCount || copied != initialString) {
                return copied
            }

            if pasteboard.changeCount != initialChangeCount,
               let copied = pasteboard.string(forType: .string),
               !copied.isEmpty {
                return copied
            }
        }

        return nil
    }

    private func triggerCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                }
            }
            return clone
        }
    }

    private func restorePasteboard(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

// MARK: - SwiftUI Views
struct FloatingWindowView: View {
    @ObservedObject var monitor: SelectionMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !monitor.selectedText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Original")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(monitor.selectedText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    Divider()
                }

                if monitor.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.65)
                        Text("Translating...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if !monitor.translatedText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Translation")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(monitor.translatedText)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                    }
                } else {
                    Text(monitor.status)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let onClearCache: () -> Void
    let onRequestScreenRecordingPermission: () -> Void
    let onOpenAccessibilitySettings: () -> Void

    var body: some View {
        Form {
            Section("Translation") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(TranslationProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                if settings.provider == .ollama {
                    TextField("Ollama Model", text: $settings.ollamaModel)
                    Text("Endpoint: http://localhost:11434/api/generate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Model", text: $settings.openAIModel)
                    TextField("Base URL", text: $settings.openAIBaseURL)
                    SecureField("API Key (optional)", text: $settings.openAIAPIKey)
                }
            }

            Section("System Prompt") {
                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 180)

                HStack {
                    Button("Reset Prompt") {
                        settings.resetSystemPrompt()
                        onClearCache()
                    }

                    Spacer()

                    Button("Clear Translation Cache") {
                        onClearCache()
                    }
                }
            }

            Section("Permissions") {
                Button("Request Screen Recording Permission") {
                    onRequestScreenRecordingPermission()
                }

                Button("Open Accessibility Settings") {
                    onOpenAccessibilitySettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding(14)
        .frame(width: 620, height: 560)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var statusItem: NSStatusItem!
    let monitor = SelectionMonitor()
    let appSettings = AppSettings.shared
    let hoverTextService = HoverTextService()
    let selectedTextService = SelectedTextService()

    var settingsWindow: NSWindow?
    var localMonitor: Any?
    var globalFlagsMonitor: Any?
    var hoverTimer: Timer?
    var activationTimer: Timer?
    var monitorContentObserver: AnyCancellable?
    var settingsCacheObserver: AnyCancellable?

    var isRightOptionPressed = false
    var isHoverTranslationActive = false
    var activeSelectedText: String?
    var lastHoveredWord: String = ""
    var lastSampledMouseLocation: CGPoint?
    let hoverMovementThreshold: CGFloat = 10
    let activationDelay: TimeInterval = 0.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        setupWindow()
        setupStatusItem()
        bindMonitorContentUpdates()
        bindSettingsCacheInvalidation()

        NSApp.setActivationPolicy(.accessory)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }

            if event.type == .flagsChanged {
                self.handleFlagsChanged(event)
                return event
            }

            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
                return nil
            }

            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    func setupWindow() {
        let contentView = FloatingWindowView(monitor: monitor)

        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: floatingWindowMinWidth, height: floatingWindowMinHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.minSize = NSSize(width: floatingWindowMinWidth, height: floatingWindowMinHeight)
        window.maxSize = NSSize(width: floatingWindowMaxWidth, height: floatingWindowMaxHeight)
        window.orderOut(nil)
    }

    func bindMonitorContentUpdates() {
        monitorContentObserver = Publishers.CombineLatest4(
            monitor.$selectedText,
            monitor.$translatedText,
            monitor.$isTranslating,
            monitor.$status
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self, self.window.isVisible else { return }
                self.resizeWindowToFitContent()
                self.positionWindow(near: NSEvent.mouseLocation)
            }
    }

    func bindSettingsCacheInvalidation() {
        settingsCacheObserver = appSettings.objectWillChange
            .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.monitor.clearCache(keepCurrentContent: true)
            }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = loadStatusBarIcon()
            button.image?.isTemplate = true
            button.toolTip = "FloatTranslator"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hold Option to Translate", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit FloatTranslator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func handleFlagsChanged(_ event: NSEvent) {
        let isRightOptionEvent = event.keyCode == 61
        let isLeftOptionEvent = event.keyCode == 58
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let optionPressed = flags.contains(.option)

        if isLeftOptionEvent && optionPressed {
            cancelHoverTranslation()
            return
        }

        guard isRightOptionEvent else {
            if !optionPressed {
                cancelHoverTranslation()
            }
            return
        }

        if optionPressed {
            guard !isRightOptionPressed else { return }
            isRightOptionPressed = true
            scheduleHoverTranslationActivation()
        } else {
            cancelHoverTranslation()
        }
    }

    func scheduleHoverTranslationActivation() {
        activationTimer?.invalidate()
        activationTimer = Timer.scheduledTimer(withTimeInterval: activationDelay, repeats: false) { [weak self] _ in
            guard let self, self.isRightOptionPressed else { return }
            self.beginHoverTranslation()
        }
        activationTimer?.tolerance = 0.1
    }

    func beginHoverTranslation() {
        guard !isHoverTranslationActive else { return }

        isHoverTranslationActive = true
        activeSelectedText = nil
        _ = selectedTextService.requestTrustIfNeeded()
        selectedTextService.reset()
        hoverTimer?.invalidate()
        lastSampledMouseLocation = nil
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            self?.updateHoveredWordIfNeeded()
        }
        hoverTimer?.tolerance = 0.05
        updateHoveredWord()
    }

    func cancelHoverTranslation() {
        activationTimer?.invalidate()
        activationTimer = nil
        isRightOptionPressed = false
        endHoverTranslation()
    }

    func endHoverTranslation() {
        isHoverTranslationActive = false
        hoverTimer?.invalidate()
        hoverTimer = nil
        activeSelectedText = nil
        lastHoveredWord = ""
        lastSampledMouseLocation = nil
        selectedTextService.reset()
        monitor.clearTransientContent()
        window.orderOut(nil)
    }

    func updateHoveredWordIfNeeded() {
        let cursorPoint = CGEvent(source: nil)?.location ?? .zero

        guard shouldResample(for: cursorPoint) else { return }
        lastSampledMouseLocation = cursorPoint
        updateHoveredWord(at: cursorPoint)
    }

    func updateHoveredWord() {
        let cursorPoint = CGEvent(source: nil)?.location ?? .zero
        lastSampledMouseLocation = cursorPoint
        updateHoveredWord(at: cursorPoint)
    }

    func updateHoveredWord(at cursorPoint: CGPoint) {
        if !selectedTextService.isTrusted() {
            monitor.showSelectionPermissionStatus()
        }

        if let activeSelectedText {
            presentWindow(near: NSEvent.mouseLocation)

            guard activeSelectedText != lastHoveredWord else { return }
            lastHoveredWord = activeSelectedText
            monitor.translateText(activeSelectedText)
            return
        }

        if let selectedText = selectedTextService.selectedText() {
            activeSelectedText = selectedText
            presentWindow(near: NSEvent.mouseLocation)

            guard selectedText != lastHoveredWord else { return }
            lastHoveredWord = selectedText
            monitor.translateText(selectedText)
            return
        }

        guard hoverTextService.hasScreenCaptureAccess() else {
            monitor.showPermissionStatus()
            presentWindow(near: NSEvent.mouseLocation)
            return
        }

        let hoveredWord = hoverTextService.hoveredWordUsingOCR(at: cursorPoint)

        guard let hoveredWord else {
            lastHoveredWord = ""
            monitor.showIdleStatus()
            window.orderOut(nil)
            return
        }

        presentWindow(near: NSEvent.mouseLocation)

        guard hoveredWord != lastHoveredWord else { return }
        lastHoveredWord = hoveredWord
        monitor.translateText(hoveredWord)
    }

    func shouldResample(for cursorPoint: CGPoint) -> Bool {
        guard let lastSampledMouseLocation else { return true }

        let dx = cursorPoint.x - lastSampledMouseLocation.x
        let dy = cursorPoint.y - lastSampledMouseLocation.y
        return sqrt((dx * dx) + (dy * dy)) >= hoverMovementThreshold
    }

    func presentWindow(near mouseLocation: NSPoint) {
        resizeWindowToFitContent()
        positionWindow(near: mouseLocation)
        window.orderFrontRegardless()
    }

    func positionWindow(near mouseLocation: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        let offset: CGFloat = 18
        let padding: CGFloat = 8
        let windowSize = window.frame.size
        let visibleFrame = screen.visibleFrame

        let rightSpace = visibleFrame.maxX - mouseLocation.x - offset
        let leftSpace = mouseLocation.x - visibleFrame.minX - offset
        let aboveSpace = visibleFrame.maxY - mouseLocation.y - offset
        let belowSpace = mouseLocation.y - visibleFrame.minY - offset

        let placeRight = rightSpace >= windowSize.width || rightSpace >= leftSpace
        let placeBelow = belowSpace >= windowSize.height || belowSpace >= aboveSpace

        var originX = placeRight
            ? mouseLocation.x + offset
            : mouseLocation.x - windowSize.width - offset
        var originY = placeBelow
            ? mouseLocation.y - windowSize.height - offset
            : mouseLocation.y + offset

        originX = min(max(originX, visibleFrame.minX + padding), visibleFrame.maxX - windowSize.width - padding)
        originY = min(max(originY, visibleFrame.minY + padding), visibleFrame.maxY - windowSize.height - padding)

        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    func resizeWindowToFitContent() {
        let targetSize = calculateWindowSize()
        if abs(window.frame.width - targetSize.width) < 1 && abs(window.frame.height - targetSize.height) < 1 {
            return
        }
        window.setContentSize(targetSize)
    }

    func calculateWindowSize() -> NSSize {
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 14
        let sectionSpacing: CGFloat = 8
        let inSectionSpacing: CGFloat = 2
        let dividerHeight: CGFloat = 1
        let progressRowHeight: CGFloat = 16
        let preferredTextWidthCap: CGFloat = 420

        let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let originalFont = NSFont.systemFont(ofSize: 12)
        let translationFont = NSFont.systemFont(ofSize: 13)
        let statusFont = NSFont.systemFont(ofSize: 12)

        var preferredTextWidth: CGFloat = 0
        if !monitor.selectedText.isEmpty {
            preferredTextWidth = max(preferredTextWidth, singleLineWidth("Original", font: labelFont))
            preferredTextWidth = max(preferredTextWidth, min(singleLineWidth(monitor.selectedText, font: originalFont), preferredTextWidthCap))
        }

        if monitor.isTranslating {
            preferredTextWidth = max(preferredTextWidth, singleLineWidth("Translating...", font: statusFont) + 24)
        } else if !monitor.translatedText.isEmpty {
            preferredTextWidth = max(preferredTextWidth, singleLineWidth("Translation", font: labelFont))
            preferredTextWidth = max(preferredTextWidth, min(singleLineWidth(monitor.translatedText, font: translationFont), preferredTextWidthCap))
        } else {
            preferredTextWidth = max(preferredTextWidth, min(singleLineWidth(monitor.status, font: statusFont), preferredTextWidthCap))
        }

        let targetWidth = min(
            max(preferredTextWidth + horizontalPadding, floatingWindowMinWidth),
            floatingWindowMaxWidth
        )
        let textWrapWidth = max(targetWidth - horizontalPadding, 80)

        var contentHeight = verticalPadding
        if !monitor.selectedText.isEmpty {
            contentHeight += multilineHeight("Original", font: labelFont, width: textWrapWidth)
            contentHeight += inSectionSpacing
            contentHeight += multilineHeight(monitor.selectedText, font: originalFont, width: textWrapWidth)
            contentHeight += sectionSpacing + dividerHeight + sectionSpacing
        }

        if monitor.isTranslating {
            contentHeight += progressRowHeight
        } else if !monitor.translatedText.isEmpty {
            contentHeight += multilineHeight("Translation", font: labelFont, width: textWrapWidth)
            contentHeight += inSectionSpacing
            contentHeight += multilineHeight(monitor.translatedText, font: translationFont, width: textWrapWidth)
        } else {
            contentHeight += multilineHeight(monitor.status, font: statusFont, width: textWrapWidth)
        }

        let targetHeight = min(max(contentHeight, floatingWindowMinHeight), floatingWindowMaxHeight)
        return NSSize(width: targetWidth, height: targetHeight)
    }

    func singleLineWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    func multilineHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else {
            return ceil(font.ascender - font.descender + font.leading)
        }

        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let rect = attributed.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height)
    }

    func loadStatusBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "StatusBarIconTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "FloatTranslator")
        }
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit FloatTranslator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc
    func openSettingsWindow() {
        if settingsWindow == nil {
            let content = SettingsView(
                settings: appSettings,
                onClearCache: { [weak self] in
                    self?.monitor.clearCache(keepCurrentContent: true)
                },
                onRequestScreenRecordingPermission: { [weak self] in
                    self?.requestScreenRecordingPermission()
                },
                onOpenAccessibilitySettings: { [weak self] in
                    self?.openAccessibilitySettings()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            window.title = "Settings"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: content)
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    func requestScreenRecordingPermission() {
        _ = hoverTextService.requestScreenCaptureAccessIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        activationTimer?.invalidate()
        hoverTimer?.invalidate()

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
        }
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
