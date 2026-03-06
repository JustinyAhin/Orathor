# Orathor

Voice dictation for macOS that just works — fast, accurate, and out of your way.

Press a shortcut, speak, and your words appear wherever your cursor is. Orathor is a native menu bar app built with Swift and SwiftUI. No Electron, no web views, no accounts.

## How it works

1. Trigger recording with the **Right Command** key (hold or double-tap)
2. Speak — transcription happens in real time
3. Release or tap again to stop — the text is inserted at your cursor

A floating overlay appears while recording. Press **Escape** to cancel without inserting text.

You can also start/stop from the menu bar popover and copy the transcription to your clipboard.

## Speech engines

| Engine | Type | Setup |
|---|---|---|
| **Apple Speech** | Local, on-device | None — works out of the box |
| **Deepgram Nova** | Cloud, higher accuracy | Requires an API key (stored in Keychain) |

Switch between engines in the Settings section of the menu bar popover.

## Requirements

- macOS 14 Sonoma or later
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
- macOS `CGEvent` APIs for text insertion

## License

All rights reserved.
