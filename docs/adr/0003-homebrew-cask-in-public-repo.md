---
status: accepted
---

# Ship via a Homebrew cask in this public repo, without a paid Developer ID for now

unfocused is distributed as a Homebrew cask, not through the Mac App Store, because the App Store sandbox blocks the Accessibility and Apple Events access that Capture and Activity depend on.

The cask (`Casks/unfocused.rb`) lives in this repo, which is tapped directly with `brew tap stefanhoth/unfocused https://github.com/stefanhoth/unfocused`. The release workflow updates the cask in the same repo, so there's no separate tap to keep in sync and no cross-repo token. The repo is public because brew can't download release files from a private repo without token workarounds. Being public also makes GitHub-hosted macOS runners free, so all CI runs on GitHub-hosted runners and no self-hosted runner is needed.

Until the app has proven its value, we don't pay for the Apple Developer Program. Builds are signed with a stable self-signed certificate, kept in Actions secrets, so the Accessibility permission survives updates. They aren't notarized, so Gatekeeper asks for approval on install and update. That friction is acceptable while the author's two Macs are the only users. Developer ID signing and notarization is the planned step before anyone else uses unfocused, and the pipeline is built so that the switch only touches the signing step.
