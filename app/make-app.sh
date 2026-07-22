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
# 이미 실행 중인 인스턴스 종료 — `open`은 실행 중이면 기존(구버전) 프로세스를 재실행하지 않고
# 활성화만 하므로, 종료하지 않으면 새 빌드가 아닌 옛 UI가 뜬다.
pkill -x StickyCast 2>/dev/null || true
sleep 0.3
open "$APP"
