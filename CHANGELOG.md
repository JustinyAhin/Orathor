# Changelog

## 0.0.16 — 2026-08-27

### Improvements

- **Independent development build** — local builds now appear as Orathor Dev with their own macOS permission identity while continuing to share settings, API keys, transcripts, recordings, and dictionary data with the customer app

### Fixes

- **Stable popover across Spaces** — the menu bar window stays anchored to its icon instead of sliding across the desktop when macOS restores it from another Space
- **Accessibility permission stability** — rebuilding Orathor Dev no longer invalidates the customer app's Accessibility permission

## 0.0.15 — 2026-08-27

### New

- **Launch at login** — optionally start Orathor automatically when signing in to your Mac

### Improvements

- **Automatic local fallback** — when Deepgram or OpenAI fails during a recording, Orathor transparently finishes the transcription with Apple Speech and marks the engine used in history

### Fixes

- **OpenAI session isolation** — delayed transcript events from an earlier recording can no longer leak into a later dictation
- **Stable menu bar popover** — transcript actions no longer resize the popover repeatedly when hovering between rows

## 0.0.14 — 2026-08-18

### Upgrading from an older build

If Accessibility appears enabled but Orathor still copies text to the clipboard, macOS may still trust an older development-signed build. Quit Orathor, run `tccutil reset Accessibility segbedji.Orathor`, reopen Orathor, and enable it again in System Settings → Privacy & Security → Accessibility. Quit and reopen Orathor once more after enabling it. This is a one-time migration for affected existing users; new installations are unaffected.

### Fixes

- **Microphone access in release builds** — preserve and verify the audio-input entitlement after final Developer ID signing
- **Clear microphone errors** — stop before recording and explain how to grant access when microphone permission is unavailable

## 0.0.13 — 2026-08-17

### Improvements

- **Notarized distribution** — official downloads are signed with a Developer ID certificate, notarized by Apple, and shipped with a stapled ticket so they open normally through Gatekeeper

### Fixes

- **Sparkle helper signatures** — embedded updater components now receive the same Developer ID signature and secure timestamp as the main app

## 0.0.12 — 2026-08-15

### New

- **Personal dictionary** — add, edit, reorder, and delete custom terms and exact replacement rules; export a support-friendly JSON backup from Settings
- **Vocabulary-aware transcription** — optionally send dictionary terms as private cloud hints to Deepgram and OpenAI, then apply deterministic replacements locally while preserving the original transcript

### Improvements

- **OpenAI Live Transcribe** — migrated the OpenAI engine to `gpt-live-transcribe` with language expectations, vocabulary keywords, improved final-transcript assembly, and clearer provider errors
- **More reliable recording overlay** — each dictation now owns an explicit overlay lifecycle, preventing stale updates or dismissals during rapid start, cancel, and restart sequences
- **Smoother audio meter** — coalesced meter publication and a stable 12-step display reduce unnecessary UI work without losing responsive feedback

### Fixes

- **Reduced compositor load** — replaced the recording overlay's backdrop material and window shadow with a compositor-safe solid surface
- **License startup reliability** — recording now waits for license validation before deciding whether dictation is permitted

## 0.0.11 — 2026-06-11

### New

- **Open source** — Orathor's source code is now public under the GPL v3; the official binary is the supported, prebuilt distribution
- **Free trial + licensing** — official binaries start a full-featured 7-day trial; a one-time license key (Settings → License) unlocks Orathor permanently on up to 3 Macs. Building from source stays fully unlocked
- **New update feed** — releases now ship from GitHub Releases on the main repo; updates continue automatically via Sparkle

## 0.0.10 — 2026-06-10

### New

- **First-run onboarding** — a welcome window opens on first launch: grant Microphone, Speech Recognition, and Accessibility with live status, then try your first dictation right in the window; reopen anytime from Settings → Permissions → "Show welcome guide"
- **Permissions in Settings** — new card with live status for all three permissions, grant buttons, and System Settings shortcuts

### Fixes

- **No more surprise permission prompt** — opening the menu bar popover no longer triggers the Speech Recognition system dialog; permissions are requested through onboarding or on first recording

## 0.0.9 — 2026-06-10

### New

- **New local engine (SpeechAnalyzer)** — Apple Speech migrated from the legacy SFSpeechRecognizer to the macOS 26 SpeechAnalyzer/SpeechTranscriber stack: faster, no one-minute cap, model ships with the OS and downloads automatically ("Preparing language…" shown on first use)
- **Smart formatting** — optional on-device polish via Apple Foundation Models: fixes punctuation, removes filler words, applies spoken "new line" commands; toggle in Settings or the wand pill in the popover header; requires Apple Intelligence, original text always preserved ("Copy original")
- **Live transcript preview** — the recording overlay streams your words as you speak, across all three engines
- **Engine switcher pill** — change speech engine straight from the menu bar popover header

### Improvements

- **Faster dictation** — speech sockets pre-connect on hotkey press with audio buffered during the handshake; removed the fixed 300ms post-stop delay; tightened Deepgram finalize timeout; latency instrumentation added to diagnostics
- **Warm cloud connections** — Deepgram and OpenAI sockets stay open between dictations (keepalives, 120s idle close), eliminating the 0.7–1.9s handshake on every recording; stale sockets fall back to a fresh connect automatically
- **Dashboard refinement** — editorial greeting opener, quiet stat cards, flat card surfaces, blue-led palette, chart hover tooltips, sidebar Today summary and engine status footer
- **Unified transcript rows** — click-to-copy with feedback everywhere (Home, Transcripts, popover); recording level meters recolored to red

### Fixes

- **Whisper sentence tails** — stopping no longer cuts the end of your last sentence; the final transcript always lands before insertion
- **Overlay preview** — latest words stay visible in the two-line preview; panel re-fits when the overlay switches modes
- **Swift 6 warnings** — DiagnosticLogger actor isolation cleanup

## 0.0.8 — 2026-05-13

### New

- **OpenAI Whisper engine** — new cloud transcription option using OpenAI's realtime `gpt-realtime-whisper` model over WebSocket
- **OpenAI API key setting** — store your OpenAI key securely in Keychain and switch engines from Settings

### Fixes

- **OpenAI realtime session setup** — use transcription sessions and disable unsupported turn detection for `gpt-realtime-whisper`
- **OpenAI transcript finalization** — prevent interim and completed transcript events from being joined as duplicate text

## 0.0.7 — 2026-03-14

### New

- **Language preference** — pick a primary language for Deepgram transcription (20 options) instead of always using auto-detect; single-language mode dramatically improves accuracy
- **Quick language switch** — globe pill in menu bar footer lets you change language without opening settings

## 0.0.6 — 2026-03-08

### Improvements

- **Readout-inspired UI overhaul** — sidebar navigation with grouped sections, cool neutral color palette, multi-color indicator system for data types and status
- **Diagnostic clipboard export** — trimmed to session header + last 200 lines for manageable size
- **Session-start diagnostic logging** — captures system and settings info at launch for debugging

## 0.0.5 — 2026-03-08

### Improvements

- **Accessibility permission fallback** — when accessibility permission is missing, text is copied to clipboard instead of silently failing; overlay prompts user to open Settings and grant permission

## 0.0.4 — 2026-03-08

### New

- **Dashboard: activity streak grid** — GitHub-style heatmap showing daily dictation activity with streak counter
- **Dashboard: top apps section** — ranked bar chart of most-used apps with icons
- **Speech engine tracking** — each transcription records which engine (Apple/Deepgram) was used

### Improvements

- **Diagnostic logging** — debug logger for text insertion issues with export from Settings

## 0.0.3 — 2026-03-08

### Improvements

- **Multilingual dictation** — Deepgram now uses `language=multi` for automatic language detection; speak in French, Spanish, German, and 40+ other languages without changing settings
- **Window management** — proper main window lifecycle, dock icon toggle, version display, and menu bar polish
- **Dock icon hidden by default** — new installs start as a menu-bar-only app; toggle in Settings

## 0.0.2 — 2026-03-08

### Branding

- **App icon** — amber microphone on dark background, programmatically generated at all 10 macOS sizes
- **Debug build icon** — distinct orange menu bar icon to tell debug and release apart
- **Retina fix** — correct pixel sizes for app icon on HiDPI displays

### Bug Fixes

- **Show in Finder** — fix recording files not opening from transcript actions
- **Popover dismiss** — close menu bar popover when opening the main window

## 0.0.1 — 2026-03-07

First release of Orathor — voice dictation for macOS that just works.

### Core

- **System-wide dictation** — speak and text appears wherever your cursor is
- **Dual speech engines** — Apple Speech (local, offline) and Deepgram Nova 3 (cloud, streaming via WebSocket)
- **Engine switching** — swap between local and cloud in Settings at any time
- **Global hotkeys** — hold or double-tap to record; configurable modifier key (Right Option default)
- **Two recording modes** — insert at cursor (simulates Cmd+V) or copy to clipboard
- **Clipboard mode hotkey** — separate optional hotkey for dictate-to-clipboard
- **Floating overlay** — non-activating recording indicator with pulsing dot and audio level bars
- **Escape to cancel** — press Escape during recording to discard without inserting

### History & Persistence

- **Transcript history** — every dictation saved with text, timestamp, duration, word count, and source app
- **Persistent storage** — transcripts saved as JSON in `~/Library/Application Support/segbedji.Orathor/`
- **Audio recordings** — each session saved as .m4a with playback support
- **Searchable history** — filter transcripts by text or app name with match highlighting
- **Transcript actions** — copy, play audio, show in Finder, delete

### Interface

- **Menu bar app** — lives in the menu bar, no Dock icon (LSUIElement)
- **Menu bar popover** — recent transcripts list with amber accent bars, search, recording status
- **Main window** — tabbed layout (Home / Transcripts / Settings) opened from popover
- **Home tab** — stats strip (total words, time saved, avg WPM) and recent transcripts
- **Transcripts tab** — date-grouped entries in left-accent cards with inline search
- **Frontmost app detection** — records which app you dictated into, shows app icon

### Design

- **Amber brand palette** — rich amber (#D97706) to warm gold (#F59E0B) gradient
- **Warm stone neutrals** — Tailwind stone scale for surfaces, borders, text
- **Dark mode hero** — deep warm blacks, warm elevated surfaces
- **Design token system** — Theme.swift with consistent spacing, radii, typography
- **13 custom color sets** — light/dark variants in asset catalog

### Settings

- **Hotkey configuration** — press-to-record capture UI with key cap display
- **Customizable sounds** — system sound picker for start/stop/cancel feedback
- **Deepgram API key** — stored securely in Keychain
- **Auto-updates** — Sparkle framework with EdDSA signing, toggle and manual check in Settings

### Error Handling

- **Recording errors** — overlay shows warning icon with auto-dismiss
- **Menu bar errors** — inline banner with dismiss button
- **Covered scenarios** — mic access denied, speech permission denied, missing API key, Deepgram connection failure, engine unavailable
- **Structured logging** — `os.Logger` for service-level failures
