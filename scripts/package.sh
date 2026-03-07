#!/bin/bash
set -e

cd /Users/iamsegbedji/work/projects/Orathor

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

echo ""
echo "Done! Ready to share:"
echo "  $ZIP_PATH"
echo "  $(du -h "$ZIP_PATH" | cut -f1) compressed"
echo ""
echo "Tell your friends: right-click > Open the first time."
