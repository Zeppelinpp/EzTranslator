# FloatTranslator - AI Coding Agent Guide

## Project Overview

FloatTranslator (also referred to as EzTranslator) is a minimal floating translator application for macOS (with an in-progress iPadOS branch). It provides instant translation via a compact floating window that appears when holding the Right Option key.

### Key Characteristics

- **Primary Platform**: macOS 12.0+ (minimum version)
- **Secondary Platform**: iPadOS 18.0+ (work in progress, see `FloatTranslator-iPad/`)
- **Language**: Swift
- **UI Framework**: SwiftUI + AppKit (Cocoa)
- **Build System**: Custom bash build script (no Xcode project for macOS version)
- **Distribution**: Manual build and install to `/Applications/`

## Architecture

### macOS Application (`Sources/main.swift`)

The macOS app is a single-file Swift application (~1300 lines) structured as follows:

| Component | Description |
|-----------|-------------|
| `AppSettings` | Observable settings singleton persisted via UserDefaults. Handles provider config (Ollama/OpenAI), API keys, system prompt. |
| `TranslatorService` | Network layer for translation requests. Supports Ollama (local) and OpenAI-compatible APIs. |
| `SelectionMonitor` | State machine for translation status, manages in-memory cache for translation results. |
| `HoverTextService` | OCR-based word detection using ScreenCaptureKit and Vision framework. Captures screen region under cursor. |
| `SelectedTextService` | Accessibility-based text selection capture. Uses Cmd+C simulation to get selected text. |
| `FloatingWindowView` | SwiftUI view for the floating translation popup (original text, translation, loading state). |
| `SettingsView` | SwiftUI form for configuring providers, models, API keys, and system prompt. |
| `AppDelegate` | Main app coordinator. Handles menu bar, window management, global event monitoring (Option key), and translation flow. |

### Translation Flow

1. User holds **Right Option** key for 0.5s
2. App first tries to get selected text via accessibility (Cmd+C simulation)
3. If no selection, uses OCR (ScreenCaptureKit + Vision) to detect word under cursor
4. Sends text to configured provider (Ollama or OpenAI-compatible API)
5. Displays result in floating window near cursor with dynamic positioning

### iPadOS Branch (`FloatTranslator-iPad/`)

Work-in-progress iPadOS adaptation using a different architecture:

| Component | Description |
|-----------|-------------|
| `Core/` | Shared business logic (Settings, Models, Service, Monitor) |
| `App/` | SwiftUI app entry point, TranslationView, SettingsView |
| `ShareExtension/` | iOS Share Extension to receive text from other apps |
| `project.yml` | XcodeGen specification for generating Xcode project |

**iPadOS Differences:**
- Uses Share Extension instead of global hotkey (iOS limitations)
- Only supports OpenAI-compatible providers (no Ollama)
- Uses App Groups for data sharing between extension and app
- Designed for Slide Over / Split View multitasking

## Build Process

### macOS Build

```bash
bash build.sh
```

The build script performs:
1. Generates app icons using `Scripts/generate_assets.swift`
2. Compiles `Sources/main.swift` with required frameworks
3. Creates app bundle at `/Applications/FloatTranslator.app`
4. Signs the app with the configured signing identity

**Required Frameworks:**
- Cocoa
- SwiftUI
- ApplicationServices (accessibility)
- ScreenCaptureKit (screenshot/OCR)
- Vision (text recognition)

**Signing:**
- Uses `FLOAT_TRANSLATOR_SIGNING_IDENTITY` environment variable or defaults to a specific Apple Development identity
- Code signing is required for proper functioning

### iPadOS Build

```bash
cd FloatTranslator-iPad
xcodegen generate
# Then build in Xcode or use xcodebuild
```

## Project Structure

```
.
├── Sources/
│   └── main.swift                 # Main macOS application (single file)
├── Scripts/
│   ├── generate_assets.swift      # Icon generation script
│   └── float-translator.sh        # Raycast toggle script
├── GeneratedAssets/               # Build-generated icons (gitignored ideally)
├── FloatTranslator-iPad/          # iPadOS branch (WIP)
│   └── FloatTranslator-iPad.xcodeproj/
├── docs/
│   ├── branding/                  # Logo and hero SVGs
│   └── superpowers/               # Implementation plans and specs
├── build.sh                       # Main build script
└── README.md                      # User documentation
```

## Code Style Guidelines

### Swift Conventions

- **Imports**: Group Foundation/UI frameworks first, then Apple frameworks alphabetically
- **Naming**: Use descriptive camelCase for variables/functions, PascalCase for types
- **Access Control**: Default to `internal`, use `private` for implementation details
- **Comments**: Use `// MARK: -` to organize sections in the single-file architecture

### Single-File Architecture

The macOS app uses a single-file architecture for simplicity:

```swift
// MARK: - Section Name
```

Sections in order:
1. Imports and constants
2. Enums (TranslationProvider)
3. Settings (AppSettings)
4. Provider APIs (request/response models)
5. Services (TranslatorService)
6. State Management (SelectionMonitor)
7. Platform Services (HoverTextService, SelectedTextService)
8. SwiftUI Views (FloatingWindowView, SettingsView)
9. App Delegate
10. Main entry point

### UI Constants

Floating window sizing:
```swift
private let floatingWindowMinWidth: CGFloat = 220
private let floatingWindowMaxWidth: CGFloat = 540
private let floatingWindowMinHeight: CGFloat = 72
private let floatingWindowMaxHeight: CGFloat = 420
```

## Testing Strategy

**No automated tests** are currently implemented. Testing is manual:

### macOS Manual Testing

1. Build and install: `bash build.sh`
2. Grant permissions when prompted:
   - **Screen Recording**: Required for OCR hover translation
   - **Accessibility**: Required for selected text translation
3. Test hover translation: Hold Right Option over any text
4. Test selection translation: Select text, then hold Right Option
5. Test settings: Configure different providers, verify persistence

### Raycast Integration

The `Scripts/float-translator.sh` script can be used as a Raycast command to toggle the app.

## Configuration

### UserDefaults Keys

| Key | Purpose |
|-----|---------|
| `FloatTranslatorProvider` | Selected provider (ollama/openai_compatible) |
| `FloatTranslatorSystemPrompt` | Custom system prompt for translation |
| `FloatTranslatorOllamaModel` | Ollama model name (default: qwen2.5:0.5b) |
| `FloatTranslatorOpenAIModel` | OpenAI model name (default: gpt-4.1-mini) |
| `FloatTranslatorOpenAIBaseURL` | API base URL |
| `FloatTranslatorOpenAIAPIKey` | API key (optional) |

### Default System Prompt

```
You are a translation engine.
If the source text is Chinese, translate it to English.
Otherwise, translate it to Simplified Chinese.
Output only the translation.
Preserve meaning, tone, punctuation, numbers, casing, and line breaks.
Do not explain, annotate, add alternatives, or use quotation marks.
```

## Security Considerations

1. **API Keys**: Stored in plain text in UserDefaults. This is acceptable for personal use but not for distribution.
2. **Screen Recording**: The app requests screen capture access for OCR functionality. Screen content is processed locally and never sent to any server.
3. **Pasteboard Access**: Selected text capture temporarily uses the pasteboard (Cmd+C simulation) but restores original contents.
4. **Code Signing**: Required for proper functioning on macOS. Unsigned builds may have limited functionality.

## Common Development Tasks

### Adding a New Translation Provider

1. Add case to `TranslationProvider` enum
2. Add settings properties to `AppSettings`
3. Add request/response models if needed
4. Implement request method in `TranslatorService`
5. Update `SettingsView` with configuration UI

### Modifying the Floating Window

The floating window is an `NSPanel` with:
- `.nonactivatingPanel` style (doesn't steal focus)
- `.floating` level (stays above other windows)
- `hidesOnDeactivate = false` (stays visible when switching apps)

Modify `setupWindow()` and `FloatingWindowView` for UI changes.

### Adjusting OCR Behavior

Modify `HoverTextService`:
- `ocrCaptureSize`: Size of screen capture region (default: 320x120)
- `recognitionLanguages`: Languages for Vision OCR (default: en-US, zh-Hans, zh-Hant)
- Token regex pattern in `tokenRanges()`: Controls what constitutes a "word"

## Known Limitations

1. **No proper test suite** - All testing is manual
2. **Single-file architecture** - The macOS app is intentionally kept in one file for simplicity
3. **iPadOS branch incomplete** - The iPadOS version is a work-in-progress with basic Xcode project structure
4. **No auto-updater** - Users must manually rebuild to get updates
5. **Hardcoded signing identity** - The build script has a default signing identity that may need changing

## Dependencies

**No external dependencies** for the macOS version. Uses only Apple system frameworks.

**iPadOS branch tools:**
- XcodeGen (brew install xcodegen) - for generating Xcode project

## Development Environment

- **macOS**: 12.0+ required for build, 15.2+ for OCR features
- **Xcode**: Latest version recommended for iPadOS development
- **Swift**: Version included with latest Xcode

## Permissions Required

| Permission | Purpose | When Requested |
|------------|---------|----------------|
| Screen Recording | OCR hover translation | First use of hover feature |
| Accessibility | Selected text capture | First use of selection feature |

Users can manually grant permissions in System Settings > Privacy & Security.
