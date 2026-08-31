# Setapp listing draft

All listing fields must use plain text except release notes, which may use Markdown.

## Key benefit

Private, native dictation that types wherever your cursor is

## Description

Orathor is a native macOS dictation app for people who would rather speak than type.

Hold your shortcut, say what you need, and release it. Orathor transcribes your speech and inserts the result into the app under your cursor. It stays in the menu bar until you need it, so dictation is available in notes, messages, documents, browsers, and development tools without interrupting your work.

Apple Speech is the default engine and processes speech on your Mac. Orathor can also use Deepgram or OpenAI when you deliberately select one of those engines and supply your own API key.

Smart formatting fixes punctuation, capitalization, paragraph breaks, and common filler words on-device. A personal dictionary helps Orathor preserve names, technical terms, and preferred replacements. Transcript history makes recent work easy to find, reuse, or delete.

Orathor includes configurable shortcuts, optional clipboard mode, recording feedback, launch-at-login controls, light and dark appearances, and clear permission guidance for Microphone, Speech Recognition, and Accessibility.

No Orathor account is required. The Setapp edition contains no separate license purchase, trial, store, advertising, or updater.

## Initial release notes

### Orathor is now on Setapp

- Dictate into any Mac app with a hold-to-talk shortcut.
- Keep speech on-device with Apple Speech by default.
- Clean up punctuation and filler words with on-device smart formatting.
- Teach Orathor names and technical vocabulary with the personal dictionary.
- Review and reuse recent dictation from transcript history.

## Review notes

- Orathor is a menu-bar app. Click the waveform icon to open its popover; this action reports Setapp's `userInteraction` usage event.
- The default insert shortcut is the Right Option key. Hold it while speaking and release it to finish.
- Microphone permission is required to record. Speech Recognition is required for Apple Speech. Accessibility is required only to insert text into the frontmost app; clipboard mode remains available without it.
- Apple Speech provides the complete core dictation workflow without a third-party account. Deepgram and OpenAI are optional bring-your-own-key engines and are not required.
- Launch at login is disabled until the user explicitly enables it in Settings.
- The Setapp edition displays membership status in Settings and contains no Polar licensing or Sparkle updater code.
- The minimum OS is macOS 26.2 because Orathor uses SpeechAnalyzer and Foundation Models. The submitted executable is universal (`arm64` and `x86_64`); smart formatting gracefully reports when the on-device model is unavailable.

## Policy and support URLs

- Privacy: `https://orathor.com/privacy`
- Terms: `https://orathor.com/terms`
- Support: `https://orathor.com/support`

These URLs must return HTTP 200 before the version is submitted.

## Screenshot checklist

- Up to 5 PNG or JPEG screenshots.
- Exactly 16:10, minimum 1280 × 800 pixels.
- Show only the real application UI and real functionality.
- Recommended sequence: dashboard, active dictation overlay, transcript history, personal dictionary, settings with Setapp membership.
- Avoid private transcript text, API keys, license keys, or third-party content without permission.
