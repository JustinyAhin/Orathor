# Release Flow

Official binaries are published as **GitHub Releases on the main repo** (`JustinyAhin/Orathor`), with the Sparkle appcast committed at the repo root. The old `Orathor-releases` repo is only a legacy feed mirror for installs older than 0.0.11.

## Prerequisites

- Sparkle EdDSA private key in your Keychain (generated once via `generate_keys`)
- Developer ID Application certificate and private key in your login Keychain
- Valid `notarytool` credentials stored as the `OrathorNotary` Keychain profile
- `gh` CLI authenticated with push access to the repo
- Access to the private `OrathorLicensing` repo (the script clones it into a disposable release tree)
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

1. Exports committed source to a disposable tree and clones the closed `OrathorLicensing` module there, leaving the public checkout untouched.
2. Builds Release with the Developer ID Application identity and a secure timestamp.
3. Verifies the production licensing code, hardened signature, expected identity, and absence of `get-task-allow`.
4. Submits a temporary archive to Apple's notary service and requires an `Accepted` result.
5. Staples and validates the notarization ticket, then requires Gatekeeper assessment to pass.
6. Zips the stapled app to `dist/Orathor-{version}-{build}.zip` (ditto).
7. Generates a signed `appcast.xml` (latest version only, no deltas) with download URLs pointing at `github.com/JustinyAhin/Orathor/releases/download/v{version}/`.
8. Creates GitHub release `v{version}` with the zip as asset (fails if the tag already exists — bump the version or delete the release to retry).
9. Copies the appcast to the repo root, commits, and pushes it (that's what `SUFeedURL` points at).
10. If `../Orathor-releases` exists, mirrors the appcast there for pre-0.0.11 installs (their `SUFeedURL` still points at the old repo; the mirrored appcast redirects them to the new download URLs). Delete that clone and archive the repo once everyone has updated.

### 3. Share

Download link:
```
https://github.com/JustinyAhin/Orathor/releases/latest
```

Notarized releases open normally on first launch without the previous right-click workaround.
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
