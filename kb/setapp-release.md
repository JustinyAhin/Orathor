# Setapp release

Orathor has two distribution targets backed by the same Swift source:

- `Orathor` — direct build with Polar licensing and Sparkle updates.
- `Orathor Setapp` — Setapp membership, no Polar licensing, no Sparkle.

The apps use separate bundle identifiers and separate settings, keychain, transcript, dictionary, and diagnostic storage. They can be installed at the same time without overwriting each other's data.

## One-time Setapp setup

1. Create Orathor in the Setapp developer account.
2. Confirm the registered macOS bundle identifier is `segbedji.Orathor-setapp`. If Setapp assigns a different identifier, update the target and packaging check together before uploading.
3. Download the app-specific Setapp public key (`setappPublicKey.pem`). Never commit it.
4. Publish `landing/privacy.html`, `landing/terms.html`, and `landing/support.html`; add their public URLs to the Setapp listing. Review the legal text before relying on it.
5. Complete the listing metadata, screenshots, description, and review notes.

Use `kb/setapp-listing.md` as the prepared listing copy and submission checklist.

## Local verification

Resolve packages and build both channels:

```bash
xcodebuild -scheme Orathor -configuration Debug build
xcodebuild -scheme "Orathor Setapp" -configuration Debug build
```

The Setapp SDK expects the Setapp desktop client and app-specific public key when the app runs. A normal compile does not require the key.

## Submission archive

From a clean, committed revision:

```bash
SETAPP_PUBLIC_KEY_PATH=/absolute/path/to/setappPublicKey.pem \
  ./scripts/package-setapp.sh
```

The script builds a universal `arm64`/`x86_64` app, checks that Setapp is linked and Polar/Sparkle are absent, embeds the public key, signs, notarizes, staples, validates with Gatekeeper, and writes a Setapp-only archive under `dist/`. The archive contains `Orathor.app` and the required 1024×1024 `AppIcon.png` in one folder.

Before uploading, install the archive through the Setapp developer workflow and verify:

- first launch and membership status;
- menu-bar interaction reporting;
- microphone, speech-recognition, and Accessibility permission guidance;
- dictation into another app;
- local Apple transcription and both bring-your-own-key cloud engines;
- inactive-membership behavior;
- no in-app license, trial, purchase, or update UI;
- release notes after an update.

The direct release remains independent and continues to use `scripts/package.sh`.
