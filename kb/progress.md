# Orathor — Progress

## Completed

### Step 1: Menu Bar App
- Converted from WindowGroup to MenuBarExtra with waveform icon
- Added LSUIElement to hide from Dock
- Popover UI with quit button

### Step 2: Audio Capture
- AudioService with AVAudioEngine mic capture
- Real-time audio level metering (RMS)
- Microphone entitlement and usage description

### Step 3: Local Speech-to-Text
- TranscriptionService protocol (swappable engines)
- AppleSpeechService using SFSpeechRecognizer for live on-device transcription
- TranscriptionViewModel (MVVM) coordinating audio + speech
- Real-time transcribed text displayed in popover

### Step 4: System-Wide Text Insertion
- TextInsertionService (clipboard + CGEvent Cmd+V simulation)
- Preserves previous clipboard contents after insertion
- Disabled App Sandbox for CGEvent access
- Accessibility permission request

### Step 5: Global Hotkey + Floating Overlay
- KeyboardService monitoring Right Command key
- Hold Right Cmd → records while held, auto-inserts on release
- Double-press Right Cmd → toggles recording, press again to stop and auto-insert
- Escape cancels recording in double-tap toggle mode (no text inserted)
- Floating non-activating NSPanel overlay with pulsing red dot + audio level bars
- Auto-insert at cursor when recording stops via hotkey

### Step 6: UX Polish
- Audio feedback sounds (Tink/Pop/Funk) on recording start/stop/cancel via AudioServicesPlaySystemSound
- Sounds fire from KeyboardService before audio engine setup for instant feedback
- Removed Insert at Cursor / Copy buttons from popover
- Fixed transcription not clearing between sessions
- Added rebuild script (scripts/rebuild.sh)
- Added .gitignore (xcuserdata, build artifacts, .DS_Store)

### Step 7: Deepgram Nova + Settings
- DeepgramService: WebSocket streaming to Nova 3 via URLSessionWebSocketTask
- Audio conversion pipeline (hardware float32 → linear16 @ 16kHz mono)
- Interim results shown in real-time, replaced by final results seamlessly
- Auto-reconnect on disconnect (up to 3 attempts, exponential backoff)
- Finalize + CloseStream lifecycle for clean shutdown
- Settings view with engine picker (Apple Local / Deepgram Cloud)
- API key stored securely in Keychain via KeychainService wrapper
- SpeechEngine enum for runtime engine switching
- TranscriptionService protocol updated to async (startTranscribing, stopTranscribing)
- Both engines wait for final results before text insertion (prevents word loss)
- ViewModel supports swappable speech service based on settings

### Step 8: Transcript History + Menu Bar Redesign
- TranscriptEntry model (text, timestamp, duration, word count, target app)
- TranscriptHistoryService (in-memory store)
- Frontmost app detection on recording start (name + bundle ID)
- Menu bar popover redesigned: scrollable list of recent transcripts
- Each entry shows app icon/name, text preview, duration, word count
- Click to copy transcript text

### Step 9: Persistence + Transcript Actions
- Transcript entries persisted to JSON at ~/Library/Application Support/segbedji.Orathor/
- Audio recordings saved as .m4a files in Recordings/ subdirectory
- AudioPlaybackService for playing back saved recordings
- Transcript row actions: copy icon, "..." menu (Play, Show in Finder, Delete)
- Fixed .path() vs .path bug (percent-encoded path broke FileManager lookup)
- Cancel via Escape discards audio file and skips saving entry

### Step 10: Searchable History
- Search bar in menu bar popover filters transcripts by text content and app name
- Case-insensitive local filtering via `localizedCaseInsensitiveContains`
- "No matching transcripts" empty state when search yields no results
- Search text resets when popover closes (`@State` lifecycle)

## Remaining

### Core Features
- [ ] Smart formatting (auto-punctuation, capitalization)
- [ ] Clipboard mode (dictate to clipboard instead of active field)
- [ ] Command mode ("new line", "select all", "delete that" voice commands)
- [ ] Change hotkey setting
- [ ] Main app window (beyond menu bar)

### Polish
- [ ] Error handling with user-facing alerts
- [ ] Permission status indicators in settings
- [ ] App icon
- [ ] Accessibility permission onboarding flow

### Business/Distribution
- [ ] Free tier with daily dictation limit
- [ ] Mac App Store / direct download packaging
