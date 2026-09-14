#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
./test.sh
codesign --verify --deep --strict 'Chat Harvest.app'
mkdir -p build/release
artifact="Chat-Harvest-macOS-$(uname -m).zip"
# Package only the app; never package databases, preferences, or exports.
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent 'Chat Harvest.app' "build/release/$artifact"
(cd build/release && shasum -a 256 "$artifact" > "$artifact.sha256")
echo "Release ready: build/release/$artifact"
