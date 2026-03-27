# EzTranslator

#### Minimal floating translator for macOS

`EzTranslator` is a lightweight menu bar translator for looking up words and translating selected text on macOS.

EzTranslator is designed around a very small interaction surface: hold `Right Option`, see a compact floating translation near your cursor, then continue what you were doing. No app switching, no heavy panel, no extra workflow.

It supports both local models through `Ollama` and bring-your-own-key setups through any OpenAI-compatible API provider.

## Features

- Lightweight menu bar app with fast startup and minimal friction.
- Compact floating UI for glance-level reading.
- Hold `Right Option` to translate a single word under the cursor.
- Translate selected text with the same flow.
- Dynamic popup sizing and adaptive positioning near screen edges.
- Native macOS `Settings` window for provider and prompt configuration.
- Support local `Ollama` models.
- Support OpenAI-compatible providers with configurable `base URL`, `model`, and `API key`.

## Translation Providers

EzTranslator supports two providers from Settings:

- `Ollama` (local model, configurable model name, e.g. `qwen2.5:0.5b`)
- `OpenAI-Compatible` (configurable `model`, `base URL`, `API key`)

## Why EzTranslator

- **Flow-first**: the main interaction is hold-to-translate, so translation does not take over your screen.
- **Minimal UI**: the popup is intentionally compact instead of trying to become a full translation workspace.
- **Good fit for quick word lookup**: especially useful when you only need an instant translation for one word or a short phrase.
- **Local-first optionality**: works well with local models, but does not lock you into them.

## Installation

### Build from source

```bash
bash build.sh
```

The app will be installed to `/Applications/FloatTranslator.app`.

## Usage

Mode | How it works
--- | ---
Hover word translation | Move the cursor over a word and hold `Right Option`
Selection translation | Select text first, then hold `Right Option`
Provider configuration | Open `Settings...` from the menu bar icon

## Settings

In `Settings...`, you can configure:

- Translation provider
- Ollama model
- OpenAI-compatible base URL
- OpenAI-compatible model
- OpenAI-compatible API key
- System prompt

## Permissions

- Screen Recording permission is required for hover OCR translation.
- Accessibility permission is required for selected-text translation.

## Screenshot Tips

For marketing screenshots, use macOS delayed screenshot:

1. Press `Shift + Command + 5`.
2. Set timer to `5s` or `10s`.
3. Start capture, then hold `Right Option` to show the popup.
4. The screenshot is taken automatically while the popup is visible.
