#!/bin/bash
# app/make-app.sh — swift build → .app 조립 → Launch Services 등록 → 실행
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="build/StickyCast.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/StickyCast" "$APP/Contents/MacOS/StickyCast"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
open "$APP"
