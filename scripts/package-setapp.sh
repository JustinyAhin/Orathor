#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPO_ROOT="$PWD"
DEVELOPER_TEAM="4235L6T592"
DEVELOPER_IDENTITY="Developer ID Application: SEGBEDJI JUSTIN AHINON (4235L6T592)"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-OrathorNotary}"
SETAPP_KEY="${SETAPP_PUBLIC_KEY_PATH:-}"
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

if [ -z "$SETAPP_KEY" ] || [ ! -f "$SETAPP_KEY" ]; then
    echo "FATAL: SETAPP_PUBLIC_KEY_PATH must point to the setappPublicKey.pem downloaded from Setapp."
    exit 1
fi
grep -F -- "-----BEGIN PUBLIC KEY-----" "$SETAPP_KEY" >/dev/null \
    || { echo "FATAL: SETAPP_PUBLIC_KEY_PATH is not a PEM public key."; exit 1; }
security find-identity -v -p codesigning | grep -F "$DEVELOPER_IDENTITY" >/dev/null \
    || { echo "FATAL: Developer ID Application identity is unavailable."; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null \
    || { echo "FATAL: notarization credentials '$NOTARY_PROFILE' are unavailable or invalid."; exit 1; }

# Setapp builds come from committed source, just like direct releases, but do
# not clone or include OrathorLicensing.
RELEASE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/orathor-setapp-release.XXXXXX")
RELEASE_SOURCE="$RELEASE_ROOT/Orathor"
BUILD_ROOT="$RELEASE_ROOT/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
BUILD_LOG="$BUILD_ROOT/xcodebuild.log"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Orathor.app"

mkdir -p "$RELEASE_SOURCE" "$BUILD_ROOT"
git archive --format=tar HEAD | tar -xf - -C "$RELEASE_SOURCE"

echo "Building universal Orathor for Setapp (Release)..."
if ! (
    cd "$RELEASE_SOURCE"
    xcodebuild \
        -scheme "Orathor Setapp" \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="Developer ID Application" \
        DEVELOPMENT_TEAM="$DEVELOPER_TEAM" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
        OTHER_CODE_SIGN_FLAGS="--timestamp" \
        build
) >"$BUILD_LOG" 2>&1; then
    echo "FATAL: Setapp release build failed. Last 50 log lines:"
    tail -50 "$BUILD_LOG"
    exit 1
fi
tail -5 "$BUILD_LOG"

if [ ! -d "$APP_PATH" ]; then
    echo "FATAL: expected release app was not produced at $APP_PATH."
    exit 1
fi

cp "$SETAPP_KEY" "$APP_PATH/Contents/Resources/setappPublicKey.pem"

BINARY="$APP_PATH/Contents/MacOS/Orathor"
ARCHITECTURES=$(lipo -archs "$BINARY")
case " $ARCHITECTURES " in
    *" arm64 "*) ;;
    *) echo "FATAL: Setapp binary is missing arm64."; exit 1 ;;
esac
case " $ARCHITECTURES " in
    *" x86_64 "*) ;;
    *) echo "FATAL: Setapp binary is missing x86_64."; exit 1 ;;
esac

if find "$APP_PATH/Contents" -iname '*Sparkle*' -print -quit | grep -q .; then
    echo "FATAL: Sparkle was embedded in the Setapp build."
    exit 1
fi
if strings "$BINARY" | grep -F "api.polar.sh" >/dev/null; then
    echo "FATAL: Polar licensing code was embedded in the Setapp build."
    exit 1
fi
nm -a "$BINARY" | grep -F '_OBJC_CLASS_$_STPManager' >/dev/null \
    || { echo "FATAL: Setapp SDK symbols are not linked."; exit 1; }

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")" != "segbedji.Orathor-setapp" ]; then
    echo "FATAL: Setapp bundle identifier is incorrect."
    exit 1
fi
for required_key in CFBundleName CFBundleIconFile CFBundleVersion CFBundleShortVersionString; do
    /usr/libexec/PlistBuddy -c "Print :$required_key" "$INFO_PLIST" >/dev/null 2>&1 \
        || { echo "FATAL: required Info.plist key $required_key is missing."; exit 1; }
done
/usr/libexec/PlistBuddy -c 'Print :NSUpdateSecurityPolicy:AllowProcesses:MEHY5QF425:0' "$INFO_PLIST" \
    | grep -Fx "com.setapp.DesktopClient.SetappAgent" >/dev/null \
    || { echo "FATAL: required Setapp NSUpdateSecurityPolicy is missing."; exit 1; }

# The public key is added after compilation, so perform the definitive signing
# pass only after every bundle resource is in place.
codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_IDENTITY" "$APP_PATH"
codesign --force --options runtime --timestamp \
    --entitlements "$RELEASE_SOURCE/Orathor/Orathor.entitlements" \
    --sign "$DEVELOPER_IDENTITY" "$APP_PATH"

ENTITLEMENTS="$BUILD_ROOT/entitlements.plist"
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS" 2>/dev/null
if [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "$ENTITLEMENTS" 2>/dev/null || true)" != "true" ]; then
    echo "FATAL: release app is missing the microphone audio-input entitlement."
    exit 1
fi
if plutil -p "$ENTITLEMENTS" | grep -F 'com.apple.security.get-task-allow' >/dev/null; then
    echo "FATAL: release app contains the development-only get-task-allow entitlement."
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
OUT_DIR="$REPO_ROOT/dist"
ZIP_NAME="Orathor-Setapp-${VERSION}-${BUILD}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"
NOTARY_ZIP="$BUILD_ROOT/Orathor-Setapp-notarization.zip"
NOTARY_RESULT="$BUILD_ROOT/notary-result.json"
NOTARY_LOG="$BUILD_ROOT/notary-log.json"

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
echo "Submitting Setapp build to Apple notary service..."
xcrun notarytool submit "$NOTARY_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json >"$NOTARY_RESULT"
NOTARY_STATUS=$(plutil -extract status raw -o - "$NOTARY_RESULT")
NOTARY_ID=$(plutil -extract id raw -o - "$NOTARY_RESULT")
if [ "$NOTARY_STATUS" != "Accepted" ]; then
    xcrun notarytool log "$NOTARY_ID" \
        --keychain-profile "$NOTARY_PROFILE" \
        "$NOTARY_LOG" || true
    echo "FATAL: Apple notarization status is $NOTARY_STATUS."
    if [ -f "$NOTARY_LOG" ]; then
        cat "$NOTARY_LOG"
    fi
    exit 1
fi

xcrun stapler staple -v "$APP_PATH"
xcrun stapler validate -v "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

STAGING_DIR="$BUILD_ROOT/Orathor-Setapp-${VERSION}-${BUILD}"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/Orathor.app"
cp "$RELEASE_SOURCE/Orathor/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" \
    "$STAGING_DIR/AppIcon.png"
ICON_WIDTH=$(sips -g pixelWidth "$STAGING_DIR/AppIcon.png" | awk '/pixelWidth/ { print $2 }')
ICON_HEIGHT=$(sips -g pixelHeight "$STAGING_DIR/AppIcon.png" | awk '/pixelHeight/ { print $2 }')
if [ "$ICON_WIDTH" != "1024" ] || [ "$ICON_HEIGHT" != "1024" ]; then
    echo "FATAL: AppIcon.png must be exactly 1024 x 1024 pixels."
    exit 1
fi

# Setapp rejects Finder-style metadata folders, so do not use
# --sequesterRsrc for the submission archive.
ditto -c -k --keepParent "$STAGING_DIR" "$ZIP_PATH"

VERIFY_DIR="$BUILD_ROOT/archive-verification"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
EXTRACTED_ROOT="$VERIFY_DIR/$(basename "$STAGING_DIR")"
if find "$VERIFY_DIR" -name __MACOSX -print -quit | grep -q .; then
    echo "FATAL: submission archive contains a __MACOSX metadata directory."
    exit 1
fi
if [ "$(find "$VERIFY_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" != "1" ] \
    || [ ! -d "$EXTRACTED_ROOT/Orathor.app" ] \
    || [ ! -f "$EXTRACTED_ROOT/AppIcon.png" ]; then
    echo "FATAL: archive must contain one directory with Orathor.app and AppIcon.png."
    exit 1
fi
ARCHIVE_SIZE=$(stat -f %z "$ZIP_PATH")
if [ "$ARCHIVE_SIZE" -gt 1073741824 ]; then
    echo "FATAL: Setapp submission archive exceeds 1 GB."
    exit 1
fi

echo ""
echo "Setapp submission archive ready:"
echo "  $ZIP_PATH"
echo ""
echo "This archive is intentionally separate from the GitHub/Sparkle direct release."
