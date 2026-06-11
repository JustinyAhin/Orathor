# Orathor

Voice dictation for macOS that just works — fast, accurate, and out of your way.

Press a shortcut, speak, and your words appear wherever your cursor is. Orathor is a native menu bar app built with Swift and SwiftUI. No Electron, no web views, no accounts.

## Install

1. Download the latest zip from [Orathor-releases](https://github.com/JustinyAhin/Orathor-releases/tree/main/releases)
2. Unzip and drag `Orathor.app` to `/Applications`
3. **Right-click → Open** the first time — the app isn't notarized, so a normal double-click is blocked by Gatekeeper
4. Orathor lives in the menu bar (no Dock icon) — look for the mic icon
5. Grant the permissions it asks for: Microphone, Accessibility (text insertion), and Speech Recognition (Apple Speech engine)

Updates after that are automatic via Sparkle.

## How it works

1. Trigger recording with the **Right Option** key (hold or double-tap — configurable in Settings)
2. Speak — the floating overlay shows a live preview of your words as you talk
3. Release or tap again to stop — the text is inserted at your cursor

Press **Escape** while recording to cancel without inserting text.

You can also start/stop from the menu bar popover and copy the transcription to your clipboard, or set a separate hotkey that dictates straight to the clipboard.

## Speech engines

| Engine | Type | Setup |
|---|---|---|
| **Apple Speech** (default) | Local, on-device (SpeechAnalyzer) | None — works out of the box |
| **Deepgram Nova** | Cloud, higher accuracy | Requires an API key (stored in Keychain) |
| **OpenAI Whisper** | Cloud, realtime streaming | Requires an API key (stored in Keychain) |

Switch engines from the pill in the menu bar popover header, or in Settings.

## Smart formatting

An optional on-device polish pass (Apple Foundation Models) fixes punctuation, removes filler words, and applies spoken commands like "new line". Opt in from Settings or the wand pill in the popover header — requires Apple Intelligence. The original transcript is always preserved.

## Requirements

- macOS 26.2 or later (Apple Silicon)
- Microphone permission
- Accessibility permission (for inserting text at your cursor)
- Speech Recognition permission (when using Apple Speech engine)

## Development

### Build and run

```bash
# Build (debug)
xcodebuild -scheme Orathor -configuration Debug build

# Quit, rebuild, and relaunch
./scripts/rebuild.sh

# Open in Xcode
open Orathor.xcodeproj
```

### Tech stack

- **Swift 6** with SwiftUI
- **MVVM** architecture
- `@Observable` (Observation framework) for reactive state
- `async/await` for concurrency
- `AVAudioEngine` for mic capture
- `SpeechAnalyzer` / `SpeechTranscriber` for on-device transcription
- `FoundationModels` for on-device smart formatting
- macOS `CGEvent` APIs for text insertion
- **Sparkle** for auto-updates

## License

Orathor is licensed under the [GNU General Public License v3.0](LICENSE).

You are free to use, modify, and redistribute the source under the terms of the GPL v3. Derivative works must also be released under the GPL v3. The official prebuilt binary is distributed separately.

## Contributing

Contributions are welcome. All contributors must sign the [Contributor License Agreement](CLA.md) before their first pull request can be merged — a bot will comment on your PR with instructions.
