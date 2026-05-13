# Changelog

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
