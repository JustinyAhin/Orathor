# Changelog

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
