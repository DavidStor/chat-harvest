#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun clang -fobjc-arc -Wno-deprecated-declarations -c Sources/Decode.m -o build/Decode.o
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache -import-objc-header Sources/Decode.h Sources/Core.swift Sources/Search.swift Tests/main.swift build/Decode.o -o build/core-tests -framework AppKit -lsqlite3
./build/core-tests "$@"
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache -import-objc-header Sources/Decode.h Sources/Core.swift Sources/Search.swift Sources/DemoData.swift Sources/Store.swift Tests/SearchConcurrency.swift build/Decode.o -o build/search-concurrency-tests -framework SwiftUI -framework AppKit -framework Contacts -lsqlite3
./build/search-concurrency-tests
