#!/usr/bin/env bash
# Enforces DESIGN.md's window rules that code can check. Run by `make lint` (and so by CI).
set -euo pipefail
cd "$(dirname "$0")/.."
status=0

fail() {
  echo "DESIGN.md: $1"
  echo "$2" | sed 's/^/  /'
  status=1
}

# List selection follows the system accent and can't be tinted: use SelectableList.
if hits=$(grep -rn --include=*.swift -E '(^|[^A-Za-z])List\([^)]*selection:' Sources/Unfocused); then
  fail "use SelectableList instead of List(selection:) (see Window rules)" "$hits"
fi
# Split views drift and clip the detail: use a fixed-width list in an HStack.
if hits=$(grep -rn --include=*.swift -E '\bHSplitView\b' Sources/Unfocused); then
  fail "no HSplitView in sections; use a fixed-width list next to the detail" "$hits"
fi
# The only navigation split view is the main window's sidebar.
if hits=$(grep -rn --include=*.swift -E '\bNavigationSplitView\b' Sources/Unfocused | grep -v '^Sources/Unfocused/MainWindow.swift:'); then
  fail "NavigationSplitView only in MainWindow.swift" "$hits"
fi
# The system accent never carries meaning (it can be red).
if hits=$(grep -rn --include=*.swift -E 'Color\.accentColor|\.accentColor\b' Sources/Unfocused); then
  fail "don't use the system accent color; use Style.brand or the logo gradient" "$hits"
fi

exit $status
