cask "unfocused" do
  version "2026.11.02"
  sha256 "30da4b0c7f82e17e427c4bf1457bd0408d6179561ee7e652f19b6ac405f93470"

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
