#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPO_ROOT="$PWD"
PRIVATE_REPO="git@github.com:JustinyAhin/OrathorLicensing.git"
RELEASE_ROOT=""

cleanup() {
    if [ -n "$RELEASE_ROOT" ] && [ -d "$RELEASE_ROOT" ]; then
        rm -rf "$RELEASE_ROOT"
    fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

git ls-remote "$PRIVATE_REPO" HEAD >/dev/null || { echo "FATAL: private licensing repo unreachable."; exit 1; }

# Build from committed source in a disposable tree. The closed licensing source
# never enters the public checkout, even if the release is interrupted.
RELEASE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/orathor-release.XXXXXX")
RELEASE_SOURCE="$RELEASE_ROOT/Orathor"
PRIVATE_PACKAGE_DIR="$RELEASE_SOURCE/Packages/OrathorLicensing"

mkdir -p "$RELEASE_SOURCE"
git archive --format=tar HEAD | tar -xf - -C "$RELEASE_SOURCE"
rm -rf "$PRIVATE_PACKAGE_DIR"
git clone -q --depth 1 "$PRIVATE_REPO" "$PRIVATE_PACKAGE_DIR"
rm -rf "$PRIVATE_PACKAGE_DIR/.git" "$PRIVATE_PACKAGE_DIR/.build"
echo "Disposable release source prepared with closed licensing module."

# Build release
BUILD_ROOT="$RELEASE_ROOT/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
BUILD_LOG="$BUILD_ROOT/xcodebuild.log"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Orathor.app"

mkdir -p "$BUILD_ROOT"

echo "Building Orathor (Release)..."
if ! (
    cd "$RELEASE_SOURCE"
    xcodebuild \
        -scheme Orathor \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        build
) >"$BUILD_LOG" 2>&1; then
    echo "FATAL: Release build failed. Last 50 log lines:"
    tail -50 "$BUILD_LOG"
    exit 1
fi
tail -5 "$BUILD_LOG"

if [ ! -d "$APP_PATH" ]; then
    echo "FATAL: expected release app was not produced at $APP_PATH."
    exit 1
fi

# Make sure the closed module actually got compiled in (not the stub).
strings "$APP_PATH/Contents/MacOS/Orathor" | grep -F "api.polar.sh" >/dev/null \
    || { echo "FATAL: built binary does not contain licensing code — stub compiled into release."; exit 1; }

# Get version from the app's Info.plist
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "0")

# Output directory
OUT_DIR="$REPO_ROOT/dist"
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
SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [ ! -x "$SPARKLE_BIN" ]; then
    echo "FATAL: generate_appcast not found at $SPARKLE_BIN."
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

cp "$OUT_DIR/appcast.xml" "$REPO_ROOT/appcast.xml"
git add appcast.xml
git commit -m "[infra] release ${VERSION} (build ${BUILD})"
git push

# Legacy feed mirror: installs older than 0.0.11 still poll the Orathor-releases
# repo. The mirrored appcast points them at the new download URLs. Drop this
# (and the old repo) once everyone has updated past 0.0.11.
LEGACY_REPO="$REPO_ROOT/../Orathor-releases"
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
