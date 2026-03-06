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
- Audio feedback sounds (Tink/Pop) on recording start/stop via AudioServicesPlaySystemSound
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

## Remaining

### Core Features
- [ ] Smart formatting (auto-punctuation, capitalization)
- [ ] Clipboard mode (dictate to clipboard instead of active field)
- [ ] Command mode ("new line", "select all", "delete that" voice commands)
- [ ] History (searchable log of past dictations)
- [ ] Change hotkey setting

### Polish
- [ ] Error handling with user-facing alerts
- [ ] Permission status indicators in settings
- [ ] App icon
- [ ] Accessibility permission onboarding flow

### Business/Distribution
- [ ] Free tier with daily dictation limit
- [ ] Mac App Store / direct download packaging
