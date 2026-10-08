#!/bin/bash
# Builds MacTiler.app (universal: Apple Silicon + Intel).
#
# Signing: set CODESIGN_IDENTITY to a certificate from `security find-identity -v -p codesigning`
# (e.g. "Apple Development: Name (TEAMID)"). With a stable identity, macOS keeps the
# Accessibility permission across rebuilds. Without it the app is ad-hoc signed and
# you have to re-grant Accessibility after every build.
set -euo pipefail

APP=MacTiler.app
BIN_NAME=MacTiler

echo "Building universal release binary..."
swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "Creating app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# SwiftPM records the deployment target as the SDK version (14.0). macOS
# gives apps linked against an older SDK the old look, so without this the
# app misses the macOS 26+ design (Liquid Glass, new window controls).
# Stamp the real SDK version; the minimum macOS version stays 14.0.
SDK_VERSION=$(xcrun --show-sdk-version)
vtool -set-build-version macos 14.0 "$SDK_VERSION" -replace \
    -output "$APP/Contents/MacOS/$BIN_NAME" "$BIN_DIR/mactiler"
cp Sources/mactiler/App/Info.plist "$APP/Contents/"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "Signing with: $CODESIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
else
    echo "Ad-hoc signing (set CODESIGN_IDENTITY to keep Accessibility permission across builds)"
    codesign --force --sign - "$APP"
fi

echo "Done: ./$APP"
echo
echo "Install:  cp -r $APP ~/Applications/"
echo "Run:      open ~/Applications/$APP"
