#!/usr/bin/env bash
# Signs an app bundle with the stable self-signed certificate (ADR 0003).
# Expects P12_BASE64 and P12_PASSWORD in the environment.
#
# The certificate doesn't need to be trusted: codesign only needs its keychain in
# the search list. The resulting designated requirement pins the certificate
# ("certificate leaf = H…"), so macOS keeps permissions across updates.
set -euo pipefail

APP="$1"
ENTITLEMENTS="$(cd "$(dirname "$0")" && pwd)/Unfocused.entitlements"
WORK="$(mktemp -d)"
KEYCHAIN="$WORK/signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
ORIGINAL_KEYCHAINS="$(security list-keychains -d user | tr -d '"' | xargs)"

cleanup() {
  # shellcheck disable=SC2086 # the list is intentionally split into separate paths
  security list-keychains -d user -s $ORIGINAL_KEYCHAINS
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "$P12_BASE64" | base64 --decode > "$WORK/signing.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/signing.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $ORIGINAL_KEYCHAINS

IDENTITY="$(security find-certificate -a -Z "$KEYCHAIN" | awk '/SHA-1 hash:/ { print $3; exit }')"
codesign --force --options runtime --timestamp=none --entitlements "$ENTITLEMENTS" \
  --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign --display --requirements - "$APP"
