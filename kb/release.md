# Release Flow

## Prerequisites

- Sparkle EdDSA private key in your Keychain (generated once via `generate_keys`)
- `Orathor-releases` repo cloned at `../Orathor-releases`

## Steps

### 1. Bump version and changelog

Update `CHANGELOG.md` with the new version's changes.

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
$SPARKLE_BIN --download-url-prefix "https://raw.githubusercontent.com/JustinyAhin/Orathor-releases/main/releases/" dist/
```

This creates/updates `dist/appcast.xml` with the signed entry for the new build.
Download URLs in the appcast will point to the `releases/` folder.

### 4. Publish to Orathor-releases

```bash
mkdir -p ../Orathor-releases/releases
cp dist/appcast.xml ../Orathor-releases/
cp dist/Orathor-*.zip ../Orathor-releases/releases/
cd ../Orathor-releases
git add -A
git commit -m "Release {version} (build {build})"
git push
```

### 5. Share

Download link for friends:
```
https://raw.githubusercontent.com/JustinyAhin/Orathor-releases/main/releases/Orathor-{version}-{build}.zip
```

First-time install: tell them to right-click → Open to bypass Gatekeeper.
After that, Sparkle handles updates automatically.

### 6. Tag the release

Create an empty commit to mark the version boundary in git history:

```bash
git commit --allow-empty -m "v{version}"
```

This makes it easy to see what changed between releases with `git log v{prev}..v{current}`.

## One-time migration (before next release)

Move existing zips into the `releases/` folder:

```bash
cd ../Orathor-releases
mkdir -p releases
mv Orathor-*.zip releases/
git add -A
git commit -m "Move zips to releases/ folder"
git push
```

Then on the next release, `generate_appcast` with `--download-url-prefix` will regenerate all URLs to point to `releases/`.

**Delete this section after completing the migration.**

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
