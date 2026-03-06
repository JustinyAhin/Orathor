# Orathor — Product Brief

## One-liner

Voice dictation for macOS that just works — fast, accurate, and out of your way.

## Problem

Typing is slow. Most people think at 3-5x the speed they can type. Existing dictation tools are either inaccurate, laggy, or buried behind clunky interfaces. macOS built-in dictation is limited and unreliable for extended use. Power users — writers, developers, founders, professionals — need something better.

## Solution

Orathor is a native macOS app that turns speech into text instantly, anywhere on your system. No setup, no learning curve. Press a shortcut, speak, and your words appear — accurately — wherever your cursor is.

## Core Principles

### 1. Ease of use
- Works anywhere: any text field, any app, system-wide
- Single keyboard shortcut to start/stop
- Zero configuration needed out of the box
- No accounts, no sign-up required to get started
- Lives in the menu bar — always accessible, never in the way

### 2. Fast
- Native macOS app — no Electron, no web views
- Real-time transcription with minimal latency
- Text appears as you speak, not after you stop
- Lightweight: negligible CPU and memory footprint
- Instant launch, instant response

### 3. Accurate
- State-of-the-art speech recognition (Whisper / on-device ML)
- Handles punctuation, formatting, and natural pauses intelligently
- Supports multiple languages and accents
- Context-aware corrections — understands technical terms, proper nouns
- Improves over time with usage

## Target Audience

- **Writers and bloggers** — draft articles and posts at the speed of thought
- **Developers** — dictate documentation, commit messages, comments, emails
- **Founders and executives** — quick emails, Slack messages, notes between meetings
- **Students and researchers** — capture ideas and notes without breaking flow
- **Anyone with RSI or accessibility needs** — reduce keyboard strain

## Key Features

- **System-wide dictation** — works in any app, any text field
- **Menu bar app** — always one shortcut away
- **Real-time transcription** — see words as you speak
- **Smart formatting** — auto-punctuation, capitalization, paragraph breaks
- **Command mode** — "new line", "select all", "delete that" voice commands
- **History** — searchable log of everything you've dictated
- **Privacy-first** — on-device processing option, no audio stored on servers
- **Clipboard mode** — dictate to clipboard instead of active field

## Competitive Landscape

| Product | Weakness Orathor addresses |
|---------|---------------------------|
| macOS Dictation | Limited duration, inconsistent accuracy, no history |
| Monologue | Orathor focuses on speed and system-wide integration |
| Whisper Transcription | Not real-time, file-based workflow |
| Otter.ai | Meeting-focused, subscription-heavy, not system-wide |
| SuperWhisper | Orathor aims for simpler UX and faster response |

## Tech Stack (Suggested)

- **Language:** Swift / SwiftUI
- **Speech engine (cloud):** Deepgram Nova (default) — more cloud providers later
- **Speech engine (local):** Apple Speech framework
- **Distribution:** Direct download + Mac App Store
- **Requirements:** macOS 14 Sonoma or later

## Business Model

- Free tier with daily dictation limit
- One-time purchase or annual subscription for unlimited use
- No account required for free tier

## Success Metrics

- Time from install to first dictation < 30 seconds
- Transcription latency < 500ms
- Word accuracy rate > 95%
- Daily active usage retention > 40% at 30 days

## Brand Voice

Orathor is confident but not loud. Technical but not intimidating. The name blends "orate" (to speak) with "author" (to write) — speak it, author it. The brand should feel sharp, fast, and trustworthy.
