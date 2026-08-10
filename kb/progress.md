# Orathor — Progress

## Completed

### Beads Documentation
- Centralized the reusable Beads workflow and backup/recovery runbook in `JustinyAhin/kb/engineering/issue-tracking.md`; left generated `.beads/README.md` untouched.
- Added the documented Dolt-native backup script at `scripts/beads-backup.sh` and aligned project-level Dolt ignore rules.

### Git Documentation
- Centralized the reusable Git workflow in `JustinyAhin/kb/engineering/git.md` and replaced Orathor's local Git rules with a reference.

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
- Audio feedback sounds (Sosumi/Purr/Morse) on recording start/stop/cancel via AudioServicesPlaySystemSound
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
- Copy button swaps to checkmark icon briefly as feedback instead of "Copied!" text

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
- Yellow background highlight on matching text in search results
- "No matching transcripts" empty state when search yields no results
- Search text resets when popover closes (`@State` lifecycle)
- Escape key closes menu bar popover (NSEvent local monitor)

### Step 11: Customizable Hotkeys + Clipboard Mode
- HotkeyModifier enum (rightCommand, rightOption, rightControl, rightShift, fn)
- KeyboardService supports two configurable hotkeys with RecordingMode (insertAtCursor/clipboard)
- Hold and double-tap work the same for both hotkeys
- Clipboard hotkey copies text to clipboard instead of simulating Cmd+V paste
- Hotkey settings persisted in UserDefaults with auto-swap on conflict
- "Press to record" hotkey capture UI with key cap display (HotkeyField/OptionalHotkeyField)
- Clipboard hotkey is optional (can be cleared with X button)
- Recording overlay shows clipboard icon when in clipboard mode
- Menu bar hint text updates dynamically based on configured insert hotkey
- Defaults: Right Option (insert), clipboard hotkey unset

### Step 12: Main App Window
- NavigationSplitView with sidebar: Dashboard, Transcripts, Settings
- Sidebar has app branding (waveform + "Orathor") at top, Settings separated at bottom
- Dashboard: horizontal stats row (total words, time saved, avg WPM), top sources with app icons, monthly activity heatmap, recent transcripts
- Transcripts: date-grouped entries ("Today", "Yesterday", etc.) in rounded cards, hover-only action buttons, compact rows with time column
- Settings moved from menu bar popover to main window sidebar
- "Open Orathor" button in menu bar popover footer opens the window
- Menu bar popover capped to 15 most recent transcripts
- Shared `@Observable` ViewModel between MenuBarExtra and Window scenes
- TextHighlighter utility extracted for shared search-highlight logic

### Step 13: UI Redesign — Design System
- Design token system: Theme.swift (Spacing, Radius, OType) + ViewModifiers.swift (CardModifier, SectionHeaderModifier, GhostButtonStyle, IconButtonStyle, SubtleDivider)
- 13 custom colorsets in asset catalog with light/dark variants
- All views updated to use design tokens: consistent typography (OType), spacing (Spacing), corner radii (Radius), and themed colors

### Step 14: Visual Redesign — Amber Palette + Structural Overhaul
- New brand palette: rich amber (#D97706) → warm gold (#F59E0B) gradient, replacing teal-blue
- Warm stone neutrals (Tailwind stone scale) for surfaces, borders, text — replaces cool gray
- Warning color shifted to red-orange (#EA580C) to differentiate from amber brand
- Dark mode hero: deep warm blacks (#0C0A09), warm elevated surfaces
- Main window: replaced NavigationSplitView sidebar with centered segmented tab bar (Home/Transcripts/Settings)
- Dashboard → Home: stats strip (gradientAccentCard), activity streak grid (GitHub-style heatmap with streak counter), top apps section (ranked bar chart with app icons), recent transcripts
- New leftAccentCard modifier: amber left border accent on transcript cards (signature element)
- TranscriptsView: inline search bar replacing .searchable modifier; left-accent cards per date group
- MenuBarView: amber accent bars on transcript rows; tighter header with audio level bar when recording
- Updated design context (kb/design.md): "Bold, warm, confident" personality; Raycast reference

### Step 17: UI Redesign — Readout-Inspired Overhaul
- Dark-mode colors shifted from warm tints to cool neutral charcoals (Readout-style)
- Multi-color indicator palette: blue (sessions), green (active), orange (tokens), red (errors), yellow (secondary), gray (inactive)
- Replaced top tab bar with NavigationSplitView sidebar (grouped: Overview, Monitor, Settings)
- Readout-style stat cards with centered numbers + colored dot indicators
- Multi-colored horizontal bar charts for Top Apps
- Transcript filter pills (Today / This Week / This Month / All Time)
- Page titles on all views (Home, Transcripts, Settings)
- Unified transcript row style: main window uses same TranscriptEntryRow as menu bar
- Dark/Light/System theme switcher in Settings > Appearance (defaults to dark)
- Settings page uses full-width layout matching other pages
- Updated design.md with Readout as primary reference
- Dashboard charts (WPM trend, activity bars, engine donut) now have hover tooltips: rule mark + flat tooltip card on the line/bar charts; donut highlights the hovered slice, dims the rest, and swaps the center label

### Step 18: Refinement Pass — Quiet, Blue-Led, Shared Components
- Editorial Home opener: time-of-day greeting (NSFullUserName) + muted summary sentence with colored data words; streak folded into the sentence; replaces the stat-wall lead
- Quiet stat cards: system-font numbers (24pt medium, no longer bold mono), centered with dot + label below; removed tinted icon tiles
- Flat cards everywhere: removed drop shadows from cardStyle/statCardStyle (hairline border only)
- Blue-led palette: amber demoted to streak/brand accents only; WPM trend, activity bars, and Top apps bars are monochrome blue; recording level meters (overlay + popover) recolored to recording red
- Period selector (7d/14d/30d) hoisted out of the Activity card to a standalone control that scopes the trend charts; selection persisted via @AppStorage
- Calm content section headers (ContentSectionHeader: small colored icon + sentence-case title) across Home, Settings, Transcripts, popover — replacing uppercase labels
- Custom sidebar: comfortable rows, soft active pill, hover state, muted sentence-case group headers; collapse toggle removed; hidden title bar so the sidebar runs full-height under the traffic lights
- Sidebar bottom anchored with a "Today" mini-summary (words, sessions, streak — editorial colored-data style) above a status footer (engine name + status dot, red while recording) so tall windows don't leave the sidebar visually empty; today/streak stats moved into TranscriptHistoryService and shared with the dashboard
- Shared TranscriptRow across Home/Transcripts/popover: click-to-copy with green "Copied" feedback + subtle animation, pointer-cursor affordance, play/Finder/delete actions; replaced HomeTranscriptRow and TranscriptEntryRow
- Shared SegmentedControl for the dashboard period picker and transcript filter pills (identical fill, font, animation)
- kb/design.md rewritten to codify the refined direction: restraint, data-only color (blue-led), flat cards, editorial voice, component patterns

### Diagnostics
- Diagnostic clipboard export trimmed to session header + last 200 log lines (prevents full 512KB dump)
- Full log still accessible via "Reveal in Finder"

### Step 15: Error Handling
- RecordingOverlayView shows error state (warning icon + message) when recording fails to start or transcription breaks mid-session
- Error overlay auto-dismisses after 3 seconds via `scheduleErrorOverlayDismiss()`
- MenuBarView shows inline error banner with dismiss (X) button when popover is open
- DeepgramService surfaces reconnect exhaustion (3 failed attempts) via `onError` callback
- ViewModel wires up `configureSpeechServiceErrorHandler()` on every speech service creation (init, engine switch, recording start)
- Errors shown for: mic access denied, speech permission denied, missing API key, Deepgram connection failure, speech engine unavailable
- Replaced `print()` with `os.Logger` in TranscriptHistoryService (save failures) and AudioPlaybackService (playback failures)

### Language Preference
- Language setting in Settings (under Deepgram section) with picker for 20 languages
- Defaults to "multi" (auto-detect), single-language selection improves accuracy
- Language passed through SettingsViewModel → TranscriptionViewModel → DeepgramService → WebSocket URL
- Persisted in UserDefaults
- Quick switchers in menu bar popover: language pill in footer (cloud engines only), engine pill in header next to "Recents" — both pipe through SettingsViewModel so persistence/onEngineChanged behave identically to Settings
- Smart formatting toggle pill in popover header (wand icon next to engine pill): brand-colored when on, muted when off, disabled with tooltip when Foundation Models unavailable

### Step 19: SpeechAnalyzer Migration + On-Device Smart Formatting
- Migrated AppleSpeechService from legacy SFSpeechRecognizer to modern SpeechAnalyzer/SpeechTranscriber (macOS 26+ stack from WWDC25)
- ~2× faster than Whisper Large V3 Turbo, no 1-min cap, better distant-mic, model ships with OS (zero bundle bytes, auto-updates)
- DictationTranscriber fallback when SpeechTranscriber.isAvailable is false
- AVAudioConverter bridges mic format (48kHz float) → analyzer's bestAvailableAudioFormat (block-based API, handles sample-rate change)
- Volatile/final reconciliation: finalized segments accumulate, volatile tail appended for live display
- First-run model download via AssetInventory (status/assetInstallationRequest) with "Preparing language…" state in RecordingOverlay (onPreparingChanged callback → isPreparingModel)
- Re-entrancy guard (isStarting) since VM spawns a start task per audio buffer until isTranscribing flips
- TranscriptPolisher (Foundation Models, on-device LLM): optional cleanup pass — fixes punctuation, removes fillers, applies spoken "new line" commands; engine-agnostic, fails open to raw text on unavailable/error
- Wired into TranscriptionViewModel.stopRecording before insertion; "Smart formatting" toggle in Settings (off by default, key "smartFormatting")
- Smart formatting requires Apple Intelligence (Foundation Models). TranscriptPolisher.status maps availability → user-facing reason; Settings toggle is disabled with an amber caption when unavailable (e.g. appleIntelligenceNotEnabled) so the feature never fails silently
- Provenance captured on TranscriptEntry: rawText (original), smartFormatted (bool), formattingModel (label); history row shows a wand badge + "Copy original" action. Polisher logs outcome (OK/skipped-unavailable/failed) to diagnostics

### Step 20: Live Transcription Preview + OpenAI Live Transcribe Streaming
- RecordingOverlay shows the transcript live while speaking: streaming text below the REC/waveform row in a fixed two-line area (bottom-anchored, clipped from the top so the latest words stay visible — SwiftUI multiline head truncation is unreliable). Panel size is constant while streaming, so no per-delta relayout
- Panel re-fits/repositions when the overlay switches modes (recording ↔ formatting/error/preparing/accessibility prompt) via `RecordingOverlay.refreshLayout()` triggered by `.onChange(of: mode)` — pill sizes differ a lot between modes
- Works for all three engines via the shared `transcribedText` observable — Deepgram (interim results) and Apple Speech (volatile segments) already streamed
- OpenAI Live Transcribe uses `gpt-live-transcribe` with provider-neutral captured context (automatic or expected language array, optional prompt and keywords). Turn detection stays off (`NSNull()`); `delay: "low"` remains the default live-caption setting.
- Stop-time commit hitting `input_audio_buffer_commit_empty` (e.g. instant tap with no audio) is treated as a clean stop, not surfaced as an error
- Fixed tail-of-sentence loss on OpenAI Live Transcribe: the 2s stop timeout could expire before the server's final `completed` transcript arrived (deltas lag speech by the `delay` budget), pasting only partial text. Timeout raised to 10s as a pure backstop — `completed` is the normal exit, dead connections resolve via `handleDisconnect` — and timeout expiry now logs to diagnostics

### Step 21: Dictation Latency (bd epic Orathor-qv2)
- Pre-connect on key-down (qv2.1): WS handshake starts from `startRecording` in parallel with audio engine spin-up instead of on the first audio buffer. `TranscriptionService.startTranscribing()` is now formatless; cloud services build their audio converter lazily from the first buffer's format (target rates are fixed: 16k Deepgram, 24k OpenAI)
- Handshake message queue: both cloud services queue outbound messages under a lock until `didOpenWithProtocol`, then flush in order — audio spoken during the handshake is no longer silently dropped. OpenAI's `session.update` moved into `didOpen` (was sent into a not-yet-open socket)
- Stop path (qv2.4): removed the fixed 300ms post-stop sleep (removeTap is synchronous; socket ordering guarantees audio precedes Finalize/commit); Deepgram finalize timeout tightened 2s → 1s
- Latency instrumentation in diagnostics: socket-open and first-transcript ms after connect (per engine), engine-finalized and auto-insert ms after key-up
- OpenAI `delay` is a hidden default for benchmarking minimal vs low (qv2.3): `defaults write segbedji.Orathor whisperTranscriptionDelay minimal`, default "low"
- Measured (diagnostics markers): handshakes ran 0.7–1.9s per dictation (vs 100–400ms estimate); key-up→insert now Apple ~65ms, Deepgram 340–663ms, OpenAI 744–1007ms; no dropped audio across all runs
- Warm connections (qv2.2): speech services are cached in the VM (rebuilt when cache identity changes, including OpenAI context/delay); Deepgram skips CloseStream and sends KeepAlive every 5s, OpenAI pings every 15s; 120s idle limit; stale warm socket falls back to normal connect with the handshake queue as safety net; converters rebuild if mic format changes between dictations

### Step 22: First-Run Onboarding + Permissions
- `PermissionsService` (@Observable) — single source of truth for Microphone (`AVCaptureDevice`), Speech Recognition (`SFSpeechRecognizer`), Accessibility (`AXIsProcessTrusted`); 1s `pollWhileVisible()` from view `.task` since AX has no change notification; System Settings deep links for all three panes
- Onboarding window (id "onboarding", 520×540, hidden title bar): welcome → permissions checklist with live status → try-it step (hotkey chip, in-window text field, listening indicator, success via history count). Auto-presents on first launch via `defaultLaunchBehavior(.presented)` gated on `hasCompletedOnboarding`; closing early counts as done
- `PermissionRow` component shared with the new Settings "Permissions" card (live status + grant/Open Settings actions + "Show welcome guide" re-open row)
- `checkPermissions()` no longer fires the Speech Recognition system dialog on popover open — non-prompting reads only; `startRecording()` keeps the on-demand request as fallback

### Step 27: Distribution Compliance Notices
- `Orathor/Licenses/Sparkle-LICENSE.txt` (verbatim copy of Sparkle's MIT + vendored notices) and `Orathor-Binary-Terms.txt` (proprietary binary terms, references GPL source + trademark policy) ship inside the app at `Contents/Resources/` via the synchronized group — covers Sparkle's MIT redistribution requirement in the release zip
- Binary-terms wording is a first draft — review before relying on it legally

### Step 26: Public Launch of the Monetized Build (0.0.11)
- Repo made public; v0.0.11 released through the new pipeline (first gated official binary)
- Full production flow verified end to end: public download → fresh 7-day trial → Polar production checkout (100% discount code) → key activation in Settings ("Licensed" + purchase email)
- Production Polar product `75f086fc-e3a6-4d0a-ab2b-be711bfd3ac4`; org/product IDs documented in the private OrathorLicensing repo README
- Pre-0.0.11 installs auto-update via the mirrored legacy appcast; legacy repo can be archived once everyone is past 0.0.11
- Still open before promoting: pricing finalization on the Polar product, notarization, repo positioning pass (bead Orathor-3wi.6)

### Step 25: Releases Moved to Main Repo
- Binaries now published as GitHub Releases on `JustinyAhin/Orathor` (tag `v{version}`, zip as asset via `gh release create`); appcast.xml committed at repo root, `SUFeedURL` → raw main-branch URL
- `package.sh` fully automates: build → zip → appcast → GitHub release → appcast commit+push; mirrors the appcast to `../Orathor-releases` so pre-0.0.11 installs (old feed URL) still get updates — archive that repo once everyone's past 0.0.11
- Refuses to re-release an existing tag

### Step 24: License-Key Gating (VoiceInk model)
- `Packages/OrathorLicensing` local SPM package (stub): `LicenseManager` (@MainActor @Observable), `LicenseState`/`LicenseError` — always licensed, `isGated = false`; the public API is the contract with the closed implementation
- Closed implementation in private repo `JustinyAhin/OrathorLicensing`: 7-day trial (Keychain `license.trialStart`, survives reinstall; clock-rollback guard via `license.maxSeenDate`), Polar.sh customer-portal license-key client (activate/validate/deactivate, public endpoints, sandbox in DEBUG), 3-day background re-validation with 14-day offline grace
- Private licensing security suite covers benefit/status/expiry eligibility, activation limits, offline grace, revocation, concurrent refreshes, clock rollback, and fail-closed Keychain errors
- Gate at top of `TranscriptionViewModel.startRecording()` — recording awaits any due license validation before checking entitlement, and key-up cancels a start still waiting on validation or permissions (never interrupts mid-dictation)
- Settings "License" section (shown only when `isGated`): status row (trial days left / licensed / problem), key entry + Activate, Deactivate; MenuBarView trial-status caption line above footer
- `package.sh` exports committed source to a disposable tree, clones the private licensing repo only there, and asserts the built binary contains `api.polar.sh`; the public checkout always retains its stub
- Sparkle updates deliberately ungated; source builds always fully unlocked
- TODO before launch: real Polar org ID in `PolarClient.organizationID`, Polar product + activation limit, sandbox activation test

### Step 23: Licensing + CLA
- GPL v3 `LICENSE` added (full GNU text) — copyleft keeps commercial forks open-source while the official binary is sold separately
- `CLA.md` — individual CLA granting the maintainer rights to sublicense/relicense contributions under any terms (enables proprietary binary distribution); patent grant + originality representations included
- `.github/workflows/cla.yml` — contributor-assistant/github-action v2.6.1; signatures stored in `signatures/cla.json` on a `cla-signatures` branch of this repo; signing via PR comment; maintainer + bots allowlisted
- README License section updated (was "All rights reserved") + new Contributing section pointing to the CLA

## Remaining

### Core Features
- [x] Smart formatting (auto-punctuation, capitalization) — on-device Foundation Models polish, opt-in
- [ ] Command mode ("new line", "select all", "delete that" voice commands) — partial: "new line" handled via smart formatting; structured @Generable command mode still TODO

### Polish
- [x] Error handling with user-facing alerts
- [x] Permission status indicators in settings
- [ ] App icon
- [x] Accessibility permission onboarding flow

### Step 16: Distribution + Auto-Updates
- Sparkle framework integrated via SPM for auto-update support
- EdDSA (Ed25519) signing keys generated for update verification
- Info.plist with SUFeedURL (appcast) and SUPublicEDKey
- "Check for Updates..." menu item in app menu
- CheckForUpdatesViewModel bridges Sparkle KVO to SwiftUI
- Public release repo: github.com/JustinyAhin/Orathor-releases (hosts appcast.xml + zips)
- `scripts/package.sh` builds Release .app and zips with ditto
- Version set to 0.0.1, build 1
- Release flow documented in kb/release.md

### Business/Distribution
- [ ] Free tier with daily dictation limit
