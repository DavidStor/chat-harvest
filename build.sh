#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache 'Chat Harvest.app/Contents/MacOS' 'Chat Harvest.app/Contents/Resources'
xcrun clang -mmacosx-version-min=13.0 -fobjc-arc -Wno-deprecated-declarations -c Sources/Decode.m -o build/Decode.o
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -O -module-cache-path build/module-cache -import-objc-header Sources/Decode.h Sources/Core.swift Sources/Search.swift Sources/DateRangePicker.swift Sources/DemoData.swift Sources/Store.swift Sources/App.swift build/Decode.o -o 'Chat Harvest.app/Contents/MacOS/ChatHarvest' -framework SwiftUI -framework AppKit -framework Contacts -lsqlite3
xcrun swift -module-cache-path build/module-cache Sources/Icon.swift build/AppIcon.iconset
cp build/AppIcon.icns 'Chat Harvest.app/Contents/Resources/AppIcon.icns'
cp Info.plist 'Chat Harvest.app/Contents/Info.plist'
codesign --force --sign - 'Chat Harvest.app'
echo 'Built Chat Harvest.app'
