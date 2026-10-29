#!/bin/bash
# Assembles "dist/My KVM.app" from the SPM release binary.
# Signs with MK_SIGN_IDENTITY when set, otherwise ad-hoc. The app needs no
# TCC permissions, so an ad-hoc signature is enough.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/My KVM.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/MyKVM "$APP/Contents/MacOS/MyKVM"

codesign --force --deep --sign "${MK_SIGN_IDENTITY:--}" "$APP"
echo "Bundled: $APP"
