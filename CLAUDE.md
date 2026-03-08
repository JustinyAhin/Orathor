# Orathor

Native macOS voice dictation app — speak instead of type, anywhere on your system. Fast, accurate, easy.

## Codebase Structure

**Run `.claude/hooks/update-structure.sh`** when you need to understand the codebase structure. Use the output to navigate directly to the right files instead of broad Glob/Grep searches.

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI (macOS 14+)
- **IDE**: Xcode (use `xcodebuild` for CLI builds)
- **Speech (cloud)**: Deepgram Nova (default) — more providers later
- **Speech (local)**: Apple Speech framework
- **Architecture**: MVVM

## Project Details

Product spec and research are in the `kb/` folder.

@kb/orathor-brief.md
@kb/design.md

## Documentation

When you need to check Apple documentation, use these resources:

- [Swift language guide](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/)
- [SwiftUI docs](https://developer.apple.com/documentation/swiftui)
- [Deepgram API docs](https://developers.deepgram.com/docs)
- [Deepgram streaming](https://developers.deepgram.com/docs/getting-started-with-live-streaming-audio)
- [Speech framework](https://developer.apple.com/documentation/speech)
- [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)

## Code Conventions

### Swift

- Use `struct` over `class` unless you need reference semantics
- Use `let` over `var` when the value won't change
- Prefer Swift concurrency (`async/await`, `@MainActor`) over GCD/callbacks
- Mark UI-updating code with `@MainActor`
- Use Swift's strong typing — avoid `Any`, force unwraps (`!`), and `as!`
- Handle optionals safely with `guard let`, `if let`, or nil coalescing (`??`)

### Naming

- Types (structs, classes, enums, protocols): `PascalCase`
- Functions, variables, properties: `camelCase`
- File names match the primary type they contain (e.g., `TranscriptionManager.swift`)
- Boolean properties read as assertions: `isRecording`, `hasPermission`, `canTranscribe`

### SwiftUI

- Keep views small and composable — extract subviews into separate structs
- Put view models in separate files from views
- Use `@Observable` (Observation framework, macOS 14+) instead of `ObservableObject`/`@Published`
- Use `@State` for view-local state, `@Environment` for dependency injection
- Prefer `.task {}` modifier over `.onAppear` for async work

```swift
// Good — @Observable (modern)
@Observable
final class TranscriptionViewModel {
    var transcribedText = ""
    var isRecording = false
}

// Bad — old ObservableObject pattern
class TranscriptionViewModel: ObservableObject {
    @Published var transcribedText = ""
    @Published var isRecording = false
}
```

### Project Structure

```
Orathor/
├── App/
│   └── OrathorApp.swift          # App entry point, menu bar setup
├── Views/
│   ├── TranscriptionView.swift
│   ├── SettingsView.swift
│   └── Components/               # Reusable view components
├── ViewModels/
│   └── TranscriptionViewModel.swift
├── Services/
│   ├── AudioService.swift        # Mic capture
│   ├── TranscriptionService.swift # Protocol for speech engines
│   ├── DeepgramService.swift     # Deepgram Nova (cloud, default)
│   ├── AppleSpeechService.swift  # Apple Speech (local)
│   └── KeyboardService.swift     # Global hotkey handling
├── Models/
│   └── Transcription.swift       # Data models
├── Extensions/                    # Swift extensions
├── Utilities/                     # Helpers
└── Resources/
    └── Assets.xcassets
```

### Error Handling

- Use Swift's typed error handling (`do/catch`, `Result`, `throws`)
- Never silently swallow errors — at minimum log them
- Present user-facing errors through SwiftUI alerts

```swift
// Good
do {
    try await transcriptionService.start()
} catch {
    errorMessage = error.localizedDescription
    showError = true
}

// Bad
try? await transcriptionService.start()
```

### Permissions

The app requires these entitlements/permissions:
- **Microphone access** — `NSMicrophoneUsageDescription` in Info.plist
- **Accessibility** — for system-wide text insertion (if using accessibility APIs)
- **Speech Recognition** — `NSSpeechRecognitionUsageDescription` in Info.plist

Always check permission status before using protected APIs and guide the user to grant access.

## Workflow

### Token efficiency rules

- **Never re-read a file you just edited.** You already know its contents.
- **Batch all formatting at the end**, not after each file.
- **Before using Edit, verify the exact string exists** in what you already read. If the file was modified since you read it, re-read it once — not repeatedly.

### After all edits are done, run checks:

1. **Build** the project:

```bash
cd /Users/iamsegbedji/work/projects/Orathor && xcodebuild -scheme Orathor -configuration Debug build 2>&1 | tail -20
```

2. If there are build errors, fix them before moving on.
3. **Update `kb/progress.md`** after every meaningful change (new feature, bug fix, architectural change). Move completed items from Remaining to Completed, add new items as needed.

## Commands

```bash
# Build
xcodebuild -scheme Orathor -configuration Debug build

# Quit, rebuild, and relaunch
./scripts/rebuild.sh

# Build and run (release)
xcodebuild -scheme Orathor -configuration Release build

# Clean build
xcodebuild -scheme Orathor clean build

# Open in Xcode
open Orathor.xcodeproj
```

## Menu Bar App Setup

Orathor is a **menu bar app** (no dock icon). Key setup:

- Set `LSUIElement = YES` in Info.plist (hides from dock)
- Use `MenuBarExtra` in SwiftUI for the menu bar icon/popover
- The app should feel invisible until invoked

```swift
@main
struct OrathorApp: App {
    var body: some Scene {
        MenuBarExtra("Orathor", systemImage: "mic.fill") {
            // Menu bar popover content
        }
        .menuBarExtraStyle(.window)
    }
}
```

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` — find unblocked work
- `bd create "Title" --type task --priority 2` — create issue
- `bd close <id>` — complete work
- `bd dolt push` — push beads to remote

For full workflow details: `bd prime`

## Fetching Pages

When you need to fetch a page's content, use this order:

1. `curl https://defuddle.md/[url]` — preferred, returns clean markdown
2. WebFetch tool — fallback
