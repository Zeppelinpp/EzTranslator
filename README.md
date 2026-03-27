# EzTranslator

A minimal floating translator for macOS.

Inspired by the instant lookup workflow in tools like EasyDict, but focused on an even more compact, flow-first experience.

Hold `Right Option` to translate what is under your cursor without switching apps, selecting text, or breaking attention.

## Why EzTranslator (vs traditional popup translators)

- **Extreme lightweight**: menu bar app, fast startup, very low friction.
- **Compact UI**: small floating window for glance-level reading.
- **No context switch**: translation appears right next to your cursor.
- **Flow preserved**: hold `Right Option`, see result, continue what you were doing.
- **Word hover translation**: single word lookup without manual selection.
- **Selection translation**: highlighted text is translated directly.
- **Local-first + BYOK**: use local Ollama or any OpenAI-compatible provider.

## Translation Providers

EzTranslator supports two providers from Settings:

- `Ollama` (local model, configurable model name, e.g. `qwen2.5:0.5b`)
- `OpenAI-Compatible` (configurable `model`, `base URL`, `API key`)

## Core Experience

1. Move cursor to a word.
2. Hold `Right Option`.
3. Get an instant compact translation popup near cursor.
4. Release key and continue working.

## Usage

1. Build and install:

```bash
bash build.sh
```

2. Launch the app from `/Applications/FloatTranslator.app`.
3. Open `Settings...` from the menu bar icon to configure provider, model, prompt, and keys.
4. Hold `Right Option` to trigger hover/selection translation.

## Screenshot Tips

For marketing screenshots, use macOS delayed screenshot:

1. Press `Shift + Command + 5`.
2. Set timer to `5s` or `10s`.
3. Start capture, then hold `Right Option` to show the popup.
4. The screenshot is taken automatically while the popup is visible.

## Notes

- For hover OCR translation, macOS Screen Recording permission is required.
- For selected-text translation, Accessibility permission is required.
