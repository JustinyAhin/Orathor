# Orathor

**An open-source Wispr Flow alternative for macOS.** Native, runs on-device, keeps your dictation to yourself.

Press a shortcut, speak, and your words appear wherever your cursor is. It's a native menu bar app written in Swift and SwiftUI. No Electron, no web views, no account to sign up for. By default your audio never leaves your Mac, because transcription runs entirely on-device with Apple's SpeechAnalyzer. And since the source is right here, that privacy claim is something you can read in the code instead of taking on faith.

Tools like Wispr Flow cost around $12 a month, or $144 a year, for cloud dictation. Orathor is a one-time license with no subscription, and the source is free to build yourself.

## Free vs. paid

Orathor is open source, and a build from this repo is always fully unlocked. There's no feature gate hidden in the code.

- **Build it yourself (free):** clone, open in Xcode, run. You get full local dictation with Apple SpeechAnalyzer at no cost, plus every cloud engine if you bring your own API key.
- **Buy the binary (one-time license):** a signed, notarized download that updates itself through Sparkle, plus priority support. It's for people who'd rather not build from source. Cloud engines still use your own API keys.

Same app either way. You're paying for the convenience of a prebuilt binary that keeps itself up to date, not to unlock anything.

## How it compares

If you've used Wispr Flow, SuperWhisper, Monologue, Willow Voice, MacWhisper, or VoiceInk, Orathor will feel familiar: system-wide dictation on a hotkey, with optional cleanup of the result. A few things are different.

It's open source, so the on-device privacy claim is something you can verify in the code rather than a line on a landing page. It runs locally by default with Apple SpeechAnalyzer, and the cloud engines (Deepgram and OpenAI Live Transcribe) are opt-in instead of the default. It's a one-time license rather than the monthly bill most cloud dictation tools charge. You can run the cloud engines in a free build with your own API key, at cost. And because it's a native app rather than Electron, it launches instantly and barely shows up in Activity Monitor.

## Install

1. Download the latest zip from the [Releases page](https://github.com/JustinyAhin/Orathor/releases/latest)
2. Unzip and drag `Orathor.app` to `/Applications`
3. Open Orathor normally. Apple notarization lets Gatekeeper verify the download.
4. Orathor lives in the menu bar (no Dock icon). Look for the mic icon.
5. Grant the permissions it asks for: Microphone, Accessibility (text insertion), and Speech Recognition (Apple Speech engine)

After that, updates arrive automatically through Sparkle.

## How it works

1. Trigger recording with the **Right Option** key (hold or double-tap, configurable in Settings)
2. Speak. A floating overlay shows a live preview of your words as you talk.
3. Release or tap again to stop, and the text is inserted at your cursor.

Press **Escape** while recording to cancel without inserting text.

You can also start and stop from the menu bar popover and copy the transcription to your clipboard, or set a separate hotkey that dictates straight to the clipboard.

## Speech engines

| Engine | Type | Setup |
|---|---|---|
| **Apple Speech** (default) | Local, on-device (SpeechAnalyzer) | None, works out of the box |
| **Deepgram Nova** | Cloud, higher accuracy | Requires an API key (stored in Keychain) |
| **OpenAI Live Transcribe** | Cloud, realtime streaming | Requires an API key (stored in Keychain) |

Switch engines from the pill in the menu bar popover header, or in Settings.

## Smart formatting

An optional on-device polish pass (Apple Foundation Models) fixes punctuation, removes filler words, and applies spoken commands like "new line". Turn it on in Settings or from the wand pill in the popover header; it needs Apple Intelligence. The original transcript is always kept.

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

You are free to use, modify, and redistribute the source under the terms of the GPL v3. Derivative works must also be released under the GPL v3. The official prebuilt binary is distributed separately under its own terms and includes a closed licensing component; builds from this repo are always fully unlocked.

### Trademark

"Orathor", including the name, logo, and app icon, is a trademark of Justin Ahinon and is **not** covered by the GPL. You may fork, modify, and redistribute the code under the GPL v3, but a distributed fork must use a different name and icon, must not present itself as Orathor or as officially associated with it, and must not use the name in a way that suggests endorsement. Building the app unmodified from source for personal use is of course fine.

## Contributing

Contributions are welcome. All contributors must sign the [Contributor License Agreement](CLA.md) before their first pull request can be merged. A bot will comment on your PR with instructions.
