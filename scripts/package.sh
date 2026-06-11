#!/bin/bash
set -e

cd /Users/iamsegbedji/work/projects/Orathor

# Swap in the closed licensing module (official builds enforce trial + license
# keys; the committed stub is always-licensed for open-source builds).
LICENSING_DIR="Packages/OrathorLicensing"
PRIVATE_REPO="git@github.com:JustinyAhin/OrathorLicensing.git"

restore_stub() {
    rm -rf "$LICENSING_DIR"
    git checkout -- "$LICENSING_DIR"
    echo "Stub licensing package restored."
}

git ls-remote "$PRIVATE_REPO" HEAD >/dev/null || { echo "FATAL: private licensing repo unreachable."; exit 1; }
[ -z "$(git status --porcelain "$LICENSING_DIR")" ] || { echo "FATAL: uncommitted changes in $LICENSING_DIR — commit or discard first."; exit 1; }

trap restore_stub EXIT
rm -rf "$LICENSING_DIR"
git clone -q --depth 1 "$PRIVATE_REPO" "$LICENSING_DIR"
rm -rf "$LICENSING_DIR/.git"
echo "Closed licensing module swapped in."

# Build release
echo "Building Orathor (Release)..."
xcodebuild -scheme Orathor -configuration Release build 2>&1 | tail -5

# Find the built app
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
APP_PATH=$(find "$DERIVED_DATA" -path "*/Build/Products/Release/Orathor.app" -maxdepth 5 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find Orathor.app in Release build products."
    exit 1
fi

# Make sure the closed module actually got compiled in (not the stub).
strings "$APP_PATH/Contents/MacOS/Orathor" | grep -q "api.polar.sh" \
    || { echo "FATAL: built binary does not contain licensing code — stub compiled into release."; exit 1; }

# Get version from the app's Info.plist
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "0")

# Output directory
OUT_DIR="./dist"
mkdir -p "$OUT_DIR"

ZIP_NAME="Orathor-${VERSION}-${BUILD}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

# Remove old zip if it exists
rm -f "$ZIP_PATH"

# Create zip (using ditto for proper macOS app bundling)
echo "Packaging $ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# Generate signed appcast (latest version only).
# Deltas are disabled: re-running this script regenerates the current version's
# zip from a fresh, non-reproducible build, so deltas computed against it no
# longer match what users actually installed (Sparkle "source hash" failures).
# At ~2MB zipped, full downloads cost nothing.
SPARKLE_BIN=$(find "$DERIVED_DATA" -path "*/artifacts/sparkle/Sparkle/bin/generate_appcast" 2>/dev/null | head -1)
if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: generate_appcast not found in DerivedData."
    exit 1
fi
echo "Generating appcast..."
"$SPARKLE_BIN" --maximum-versions 1 --maximum-deltas 0 --download-url-prefix "https://github.com/JustinyAhin/Orathor/releases/download/v${VERSION}/" "$OUT_DIR"

# Publish: GitHub release with the zip as asset, then the appcast committed
# to the repo root (SUFeedURL points at its raw URL on main).
TAG="v${VERSION}"
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "FATAL: release $TAG already exists. Bump the version, or 'gh release delete $TAG' to re-release."
    exit 1
fi
echo "Creating GitHub release $TAG..."
gh release create "$TAG" "$ZIP_PATH" --title "$TAG" --generate-notes

cp "$OUT_DIR/appcast.xml" ./appcast.xml
git add appcast.xml
git commit -m "[infra] release ${VERSION} (build ${BUILD})"
git push

# Legacy feed mirror: installs older than 0.0.11 still poll the Orathor-releases
# repo. The mirrored appcast points them at the new download URLs. Drop this
# (and the old repo) once everyone has updated past 0.0.11.
LEGACY_REPO="../Orathor-releases"
if [ -d "$LEGACY_REPO" ]; then
    cp "$OUT_DIR/appcast.xml" "$LEGACY_REPO/appcast.xml"
    git -C "$LEGACY_REPO" commit -qam "appcast for ${VERSION}" && git -C "$LEGACY_REPO" push -q
    echo "Legacy appcast mirrored to Orathor-releases."
fi

echo ""
echo "Done! Released:"
echo "  https://github.com/JustinyAhin/Orathor/releases/tag/$TAG"
echo "  appcast.xml committed and pushed"
echo ""
echo "Tell your friends: right-click > Open the first time."
