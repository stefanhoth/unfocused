#!/usr/bin/env bash
# Assembles the app bundle from the SwiftPM release build (ADR 0006): build/Unfocused.app for a
# release (UNFOCUSED_VERSION set), build/Unfocused Dev.app for a local build. macOS lists apps by
# their file name in places like Privacy & Security, so a dev build can't be mistaken for a release.
# Signing here is ad-hoc; the release pipeline re-signs with the stable certificate.
set -euo pipefail

cd "$(dirname "$0")/.."
SDK_26="$(xcode-select -p 2>/dev/null)/SDKs/MacOSX26.sdk"
if [[ -z "${SDKROOT:-}" && -d "$SDK_26" ]]; then
  export SDKROOT="$SDK_26"
fi
VERSION="${UNFOCUSED_VERSION:-0.0.0-dev}"
case "$VERSION" in
  *-dev) APP="build/Unfocused Dev.app" ;;
  *) APP="build/Unfocused.app" ;;
esac

swift build -c release -Xswiftc -warnings-as-errors
BIN="$(swift build -c release --show-bin-path)/Unfocused"

rm -rf build/*.app
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

# Local builds carry a "dev" qualifier in system lists (Accessibility, notifications, Activity
# Monitor), so they can't be mistaken for a release.
DISPLAY_NAME="unfocused"
case "$VERSION" in *-dev) DISPLAY_NAME="unfocused dev" ;; esac

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.stefanhoth.unfocused</string>
  <key>CFBundleName</key><string>${DISPLAY_NAME}</string>
  <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
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

# Dev builds: sign with the stable self-signed certificate when it's on this Mac, so macOS keeps
# permissions (Accessibility, Automation) across rebuilds, like it does across releases.
# Otherwise sign ad hoc; then every rebuild looks like a new app and permissions must be re-granted.
SIGNING_DIR="${UNFOCUSED_SIGNING_DIR:-$HOME/Library/Application Support/unfocused-dev/signing}"
if [ -z "${CI:-}" ] && [ -f "$SIGNING_DIR/unfocused-signing.p12" ] && [ -f "$SIGNING_DIR/p12-password.txt" ]; then
  P12_BASE64="$(base64 < "$SIGNING_DIR/unfocused-signing.p12")" \
    P12_PASSWORD="$(cat "$SIGNING_DIR/p12-password.txt")" \
    "$(dirname "$0")/sign-app.sh" "$APP" >/dev/null
  echo "Signed with the stable certificate"
else
  codesign --force --sign - --timestamp=none "$APP"
fi
echo "Built $APP ($VERSION)"
