# Release Flow

## Prerequisites

- Sparkle EdDSA private key in your Keychain (generated once via `generate_keys`)
- `Orathor-releases` repo cloned at `../Orathor-releases`

## Steps

### 1. Bump version

In `Orathor.xcodeproj/project.pbxproj`, update both Debug and Release configs:
- `MARKETING_VERSION` — user-facing version (e.g., `0.0.1` → `0.0.2`)
- `CURRENT_PROJECT_VERSION` — build number, always increment (e.g., `1` → `2`)

Sparkle uses `CURRENT_PROJECT_VERSION` to detect updates. Always increment it.

### 2. Build and package

```bash
./scripts/package.sh
```

Produces `dist/Orathor-{version}-{build}.zip`.

### 3. Generate appcast

```bash
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin/generate_appcast" 2>/dev/null | head -1)
$SPARKLE_BIN dist/
```

This creates/updates `dist/appcast.xml` with the signed entry for the new build.

### 4. Publish to Orathor-releases

```bash
cp dist/appcast.xml ../Orathor-releases/
cp dist/Orathor-*.zip ../Orathor-releases/
cd ../Orathor-releases
git add -A
git commit -m "Release {version} (build {build})"
git push
```

### 5. Share

Download link for friends:
```
https://raw.githubusercontent.com/JustinyAhin/Orathor-releases/main/Orathor-{version}-{build}.zip
```

First-time install: tell them to right-click → Open to bypass Gatekeeper.
After that, Sparkle handles updates automatically.

## Versioning

| Field | Build setting | Example | When to bump |
|-------|--------------|---------|-------------|
| Version | `MARKETING_VERSION` | `0.0.1` | New features, meaningful changes |
| Build | `CURRENT_PROJECT_VERSION` | `1` | Every release, always increment |

## Key locations

- EdDSA private key: your login Keychain
- EdDSA public key: `Info.plist` (`SUPublicEDKey`)
- Appcast URL: `Info.plist` (`SUFeedURL`)
- Release repo: https://github.com/JustinyAhin/Orathor-releases
