#!/usr/bin/env bash
# Assembles build/Unfocused.app from the SwiftPM release build (ADR 0006).
# Signing here is ad-hoc; the release pipeline re-signs with the stable certificate.
set -euo pipefail

cd "$(dirname "$0")/.."
SDK_26="$(xcode-select -p 2>/dev/null)/SDKs/MacOSX26.sdk"
if [[ -z "${SDKROOT:-}" && -d "$SDK_26" ]]; then
  export SDKROOT="$SDK_26"
fi
VERSION="${UNFOCUSED_VERSION:-0.0.0-dev}"
APP="build/Unfocused.app"

swift build -c release -Xswiftc -warnings-as-errors
BIN="$(swift build -c release --show-bin-path)/Unfocused"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Unfocused"

# App icon: a 1024×1024 PNG in Branding/AppIcon.png becomes AppIcon.icns (all sizes).
ICON_KEY=""
if [ -f Branding/AppIcon.png ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size Branding/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Branding/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

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
  ${ICON_KEY}
  <key>NSAppleEventsUsageDescription</key><string>unfocused reads the page or item in front of you when you capture a Loop, so it can take you back there later.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$APP"
echo "Built $APP ($VERSION)"
