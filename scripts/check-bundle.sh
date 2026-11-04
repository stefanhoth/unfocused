#!/usr/bin/env bash
# Checks a built app bundle: check-bundle.sh <app>
# - the bundle and unfocused-mcp verify with `codesign --verify --strict`
# - unfocused-mcp has the hardened runtime and no entitlements (ADR 0007)
# - unfocused-mcp starts and answers `initialize`
# - reports whether the app's designated requirement pins the certificate (ADR 0003)
set -euo pipefail

APP="$1"
MCP="$APP/Contents/MacOS/unfocused-mcp"

[ -x "$MCP" ] || { echo "missing $MCP" >&2; exit 1; }

codesign --verify --strict --verbose=2 "$APP"
codesign --verify --strict --verbose=2 "$MCP"

flags="$(codesign --display --verbose=2 "$MCP" 2>&1 | grep '^CodeDirectory' || true)"
case "$flags" in
  *runtime*) ;;
  *) echo "unfocused-mcp lacks the hardened runtime: $flags" >&2; exit 1 ;;
esac

if [ -n "$(codesign --display --entitlements - "$MCP" 2>/dev/null)" ]; then
  echo "unfocused-mcp must have no entitlements" >&2
  exit 1
fi

# Ad-hoc signatures (dev builds without the certificate) pin a cdhash, so this only reports.
requirement="$(codesign --display --requirements - "$APP" 2>&1 | grep 'designated' || true)"
case "$requirement" in
  *cdhash*) echo "note: app is signed ad hoc, so permissions won't survive a rebuild ($requirement)" ;;
  *) echo "App requirement pins the certificate ($requirement)" ;;
esac

# An empty HOME keeps it away from real data; it answers the handshake or an error.
reply="$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check-bundle","version":"0"}}}' \
  | HOME="$(mktemp -d)" "$MCP" 2>/dev/null | head -n 1)"
case "$reply" in
  *'"id":1'*'"result"'*) echo "unfocused-mcp answers initialize" ;;
  *) echo "unfocused-mcp did not answer initialize: $reply" >&2; exit 1 ;;
esac
