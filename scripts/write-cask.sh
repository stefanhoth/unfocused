#!/usr/bin/env bash
# Prints the Homebrew cask for a release: write-cask.sh <version> <sha256>
set -euo pipefail
VERSION="$1"
SHA256="$2"
cat <<CASK
cask "unfocused" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/stefanhoth/unfocused/releases/download/v#{version}/Unfocused-#{version}.zip"
  name "unfocused"
  desc "Keeps track of the work you've started across your apps"
  homepage "https://github.com/stefanhoth/unfocused"

  depends_on macos: :tahoe

  app "Unfocused.app"

  zap trash: [
    "~/Library/Application Support/unfocused",
    "~/Library/Logs/unfocused",
  ]
end
CASK
