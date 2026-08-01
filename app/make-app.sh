#!/bin/bash
# app/make-app.sh: swift build → assemble .app → register with Launch Services → run
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
# Kill any running instance. If one is already running, `open` just activates the
# existing (old) process instead of relaunching it, so without this you'd see the old
# UI rather than the new build.
pkill -x StickyCast 2>/dev/null || true
sleep 0.3
open "$APP"
