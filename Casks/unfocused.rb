cask "unfocused" do
  version "2026.11.01"
  sha256 "900b1c1918af6fef8fe34ebcffde4dc54c2cd12a44af47f13954f7e9e2bc5c42"

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
