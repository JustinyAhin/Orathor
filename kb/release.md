# Release Flow

Official binaries are published as **GitHub Releases on the main repo** (`JustinyAhin/Orathor`), with the Sparkle appcast committed at the repo root. The old `Orathor-releases` repo is only a legacy feed mirror for installs older than 0.0.11.

## Prerequisites

- Sparkle EdDSA private key in your Keychain (generated once via `generate_keys`)
- `gh` CLI authenticated with push access to the repo
- Access to the private `OrathorLicensing` repo (the script swaps it in over the stub)
- Working tree clean enough to commit `appcast.xml` (the script commits and pushes it)

## Steps

### 1. Bump version and changelog

Update `CHANGELOG.md` with the new version's changes.

In `Orathor.xcodeproj/project.pbxproj`, update both Debug and Release configs:
- `MARKETING_VERSION` — user-facing version (e.g., `0.0.1` → `0.0.2`)
- `CURRENT_PROJECT_VERSION` — build number, always increment (e.g., `1` → `2`)

Sparkle uses `CURRENT_PROJECT_VERSION` to detect updates. Always increment it.

Commit the bump before releasing — the script tags HEAD via the GitHub release.

### 2. Release

```bash
./scripts/package.sh
```

The script does everything:

1. Swaps the closed `OrathorLicensing` module over the committed stub (restored on exit, even on failure).
2. Builds Release, asserts the licensing code is actually in the binary.
3. Zips to `dist/Orathor-{version}-{build}.zip` (ditto).
4. Generates a signed `appcast.xml` (latest version only, no deltas) with download URLs pointing at `github.com/JustinyAhin/Orathor/releases/download/v{version}/`.
5. Creates GitHub release `v{version}` with the zip as asset (fails if the tag already exists — bump the version or delete the release to retry).
6. Copies the appcast to the repo root, commits, and pushes it (that's what `SUFeedURL` points at).
7. If `../Orathor-releases` exists, mirrors the appcast there for pre-0.0.11 installs (their `SUFeedURL` still points at the old repo; the mirrored appcast redirects them to the new download URLs). Delete that clone and archive the repo once everyone has updated.

### 3. Share

Download link:
```
https://github.com/JustinyAhin/Orathor/releases/latest
```

First-time install: right-click → Open to bypass Gatekeeper (until builds are notarized).
After that, Sparkle handles updates automatically.

## Versioning

| Field | Build setting | Example | When to bump |
|-------|--------------|---------|-------------|
| Version | `MARKETING_VERSION` | `0.0.1` | New features, meaningful changes |
| Build | `CURRENT_PROJECT_VERSION` | `1` | Every release, always increment |

`git log v{prev}..v{current}` shows what changed between releases (tags come from the GitHub releases).

## Key locations

- EdDSA private key: your login Keychain
- EdDSA public key: `Info.plist` (`SUPublicEDKey`)
- Appcast: `appcast.xml` at repo root, served via `raw.githubusercontent.com/JustinyAhin/Orathor/main/appcast.xml` (`SUFeedURL`)
- Binaries: GitHub Releases on `JustinyAhin/Orathor`
- Legacy feed mirror (pre-0.0.11 installs): https://github.com/JustinyAhin/Orathor-releases
