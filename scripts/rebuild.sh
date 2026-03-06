#!/bin/bash
pkill -x Orathor
cd /Users/iamsegbedji/work/projects/Orathor
xcodebuild -scheme Orathor -configuration Debug build 2>&1 | tail -3
if [ $? -eq 0 ]; then
    open /Users/iamsegbedji/Library/Developer/Xcode/DerivedData/Orathor-gszamdvwlizewjfhqoplhongiyqt/Build/Products/Debug/Orathor.app
fi
