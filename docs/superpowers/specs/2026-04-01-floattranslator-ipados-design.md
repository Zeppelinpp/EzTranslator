# FloatTranslator iPadOS Branch Design

## Goal
Create an iPadOS-specific branch of FloatTranslator that lets users translate selected text from any app via Share Extension, displaying results in a lightweight Slide Over / Split View window.

## Constraints
- iPadOS 18.6.2, no jailbreak available.
- Cannot draw global floating overlays like macOS.
- Must use Apple-standard inter-app text sharing (Share Extension).
- Self-use only; no App Store submission required.

## Architecture

### Directory Layout
```
FloatTranslator-iPad/
├── Core/
│   ├── AppSettings.swift
│   ├── TranslatorService.swift
│   ├── TranslationModels.swift
│   └── SelectionMonitor.swift
├── App/
│   ├── FloatTranslator_iPadApp.swift
│   ├── TranslationView.swift
│   └── SettingsView.swift
└── ShareExtension/
    ├── ShareViewController.swift
    └── Info.plist
```

### Component Responsibilities

#### Core Layer
| File | Responsibility |
|------|----------------|
| `AppSettings.swift` | Observable settings (provider, model, base URL, API key, system prompt). Persists via App Group UserDefaults so Share Extension can read them. |
| `TranslatorService.swift` | Network layer for OpenAI-compatible chat completions. |
| `TranslationModels.swift` | Codable request/response structs (`OpenAIChatRequest`, `OpenAIChatResponse`, etc.). |
| `SelectionMonitor.swift` | State machine for current translation (source, result, loading flag, in-memory cache). |

#### App Layer
| File | Responsibility |
|------|----------------|
| `FloatTranslator_iPadApp.swift` | `@main` entry point. Handles `onOpenURL` to pick up translations triggered from Share Extension. |
| `TranslationView.swift` | Main UI inside the Slide Over / Split View window: source text, divider, translation result or loading indicator. Wrapped in `ScrollView`. |
| `SettingsView.swift` | Form-based settings for provider configuration and system prompt. |

#### ShareExtension Layer
| File | Responsibility |
|------|----------------|
| `ShareViewController.swift` | Receives `NSExtensionItem`, extracts plain text, writes it to App Group shared defaults under key `pendingTranslationText`, then launches the host app via `open(_:options:completionHandler:)` and calls `completeRequest(returningItems:)` to finish. |

### Data Flow
1. User selects text in any app (e.g., Safari) and chooses **Share → FloatTranslator**.
2. Share Extension extracts the text and writes it to shared UserDefaults (`pendingTranslationText`).
3. Share Extension opens the host app URL (`floattranslator://translate`).
4. Main app (already in Slide Over or Split View) receives `onOpenURL`, reads and clears `pendingTranslationText`.
5. `SelectionMonitor` starts translation via `TranslatorService`.
6. `TranslationView` updates with loading state and then the result.

### UI Behavior
- The app supports multi-tasking: `UIRequiresFullScreen = false` in `Info.plist`.
- `TranslationView` is a vertical `ScrollView` so long translations remain readable in narrow Slide Over widths.
- No manual text input field; the app only displays translations triggered externally.
- No persistent history list.

### Caching Strategy
- `SelectionMonitor` keeps an in-memory cache dictionary (`[String: String]`) keyed by a composite of settings + source text.
- Cache is **cleared only when the app process terminates** (no background eviction).

### Provider Support
- **OpenAI-Compatible only** (Ollama is removed because local LLMs are impractical on iPad battery/thermal constraints).
- Configurable fields: `base URL`, `model name`, `API key`, `system prompt`.

### Deployment
- Build and install via Xcode wireless debugging or AltStore / SideStore sideloading.
- Re-signing interval depends on the chosen sideload method (7 days for free developer account, 1 year for paid, etc.).
