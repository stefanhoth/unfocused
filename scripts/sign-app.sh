#!/usr/bin/env bash
# Signs an app bundle with the stable self-signed certificate (ADR 0003).
# Expects P12_BASE64 and P12_PASSWORD in the environment. CI only: trusting the
# certificate for code signing needs sudo.
set -euo pipefail

APP="$1"
WORK="$(mktemp -d)"
KEYCHAIN="$WORK/signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
trap 'security delete-keychain "$KEYCHAIN" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "$P12_BASE64" | base64 --decode > "$WORK/signing.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/signing.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# codesign only uses identities whose certificate is trusted for code signing.
openssl pkcs12 -in "$WORK/signing.p12" -passin "pass:$P12_PASSWORD" -nokeys -legacy -out "$WORK/cert.pem" 2>/dev/null \
  || openssl pkcs12 -in "$WORK/signing.p12" -passin "pass:$P12_PASSWORD" -nokeys -out "$WORK/cert.pem"
sudo security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$WORK/cert.pem"

IDENTITY="$(openssl x509 -in "$WORK/cert.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"
codesign --force --options runtime --timestamp=none --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign --display --requirements - "$APP"
