#!/bin/bash
set -o pipefail

DEBUG_APP="/Users/iamsegbedji/Library/Developer/Xcode/DerivedData/Orathor-gszamdvwlizewjfhqoplhongiyqt/Build/Products/Debug/Orathor Dev.app"
DEBUG_EXECUTABLE="$DEBUG_APP/Contents/MacOS/Orathor Dev"
LEGACY_DEBUG_APP=/Users/iamsegbedji/Library/Developer/Xcode/DerivedData/Orathor-gszamdvwlizewjfhqoplhongiyqt/Build/Products/Debug/Orathor.app

pkill -f "^${DEBUG_EXECUTABLE}$" 2>/dev/null || true
pkill -f "^${LEGACY_DEBUG_APP}/Contents/MacOS/Orathor Dev$" 2>/dev/null || true
pkill -f "^${LEGACY_DEBUG_APP}/Contents/MacOS/Orathor$" 2>/dev/null || true
cd /Users/iamsegbedji/work/projects/Orathor
START=$(date +%s)
xcodebuild -scheme Orathor -configuration Debug build 2>&1 | tail -3
STATUS=$?
END=$(date +%s)
echo "Build duration: $((END - START))s"
if [ $STATUS -eq 0 ]; then
    open "$DEBUG_APP"
fi
