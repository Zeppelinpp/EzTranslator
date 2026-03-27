# EzTranslator

A lightweight, compact floating translator for macOS.

EzTranslator stays out of your way: hold `Right Option` and translate instantly with a small hover window near your cursor.

## Why EzTranslator

- Lightweight menu bar app, fast startup, low friction.
- Compact and clean UI designed for quick glance reading.
- Hover translation for a single word under cursor, no manual selection needed.
- Selection translation support for highlighted text.
- Local-first with Ollama support.
- Bring your own key with any OpenAI-compatible API provider.

## Translation Providers

EzTranslator supports two providers from Settings:

- `Ollama` (local model)
  - Configurable model name (for example `qwen2.5:0.5b`)
- `OpenAI-Compatible`
  - Configurable `model`
  - Configurable `base URL`
  - Configurable `API key`

## Usage

1. Build and install:

```bash
bash build.sh
```

2. Launch the app from `/Applications/FloatTranslator.app`.
3. Open `Settings...` from the menu bar icon to configure provider, model, prompt, and keys.
4. Hold `Right Option` to trigger hover translation.

## Notes

- For hover OCR translation, macOS Screen Recording permission is required.
- For selected-text translation, Accessibility permission is required.

