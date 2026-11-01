#!/bin/bash
# Launch the dev build on made-up data, for screenshots (site, docs, issues).
#
#   scripts/demo-app.sh [--focused] [--show <surface>]
#
# The app runs with its home folder in build/demo-home (or build/demo-home-focused), so it never
# touches the real database. --focused leaves one Loop Focused. --show is passed through
# (panel, left-off, banner, loops, recap, activity, people, settings; see docs/local-development.md).
set -euo pipefail
cd "$(dirname "$0")/.."

focused=""
show=()
while [ $# -gt 0 ]; do
  case "$1" in
    --focused) focused="--focused"; shift ;;
    --show) show=(--args --show "$2"); shift 2 ;;
    *) echo "usage: $0 [--focused] [--show <surface>]" >&2; exit 2 ;;
  esac
done

app="build/Unfocused Dev.app"
[ -d "$app" ] || { echo "Build the app first: make app" >&2; exit 1; }
home="$PWD/build/demo-home${focused:+-focused}"
db="$home/Library/Application Support/unfocused/unfocused.sqlite"
binary="$PWD/$app/Contents/MacOS/Unfocused"

# Quit a dev build from this checkout that is still running (open -n would start a second one).
pkill -f "^$binary" 2>/dev/null || true
sleep 1

launch() { open -n --env HOME="$home" --env CFFIXED_USER_HOME="$home" "$app" "$@"; }

if [ ! -f "$db" ]; then
  mkdir -p "$home"
  launch # the first launch creates the database
  for _ in $(seq 1 20); do [ -f "$db" ] && break; sleep 0.5; done
  sleep 1
  pkill -f "^$binary" || true
  sleep 1
fi

python3 scripts/demo-data.py "$db" $focused
launch "${show[@]}"
