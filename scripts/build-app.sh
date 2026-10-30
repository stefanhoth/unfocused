#!/usr/bin/env bash
# Assembles build/Unfocused.app from the SwiftPM release build (ADR 0006).
# Signing here is ad-hoc; the release pipeline re-signs with the stable certificate.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${UNFOCUSED_VERSION:-0.0.0-dev}"
APP="build/Unfocused.app"

swift build -c release -Xswiftc -warnings-as-errors
BIN="$(swift build -c release --show-bin-path)/Unfocused"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Unfocused"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.stefanhoth.unfocused</string>
  <key>CFBundleName</key><string>unfocused</string>
  <key>CFBundleDisplayName</key><string>unfocused</string>
  <key>CFBundleExecutable</key><string>Unfocused</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$APP"
echo "Built $APP ($VERSION)"
