# Local development

How to build, run and check unfocused on your own Mac, and the macOS details that make it work. CI and releases are in [github-repo-settings.md](github-repo-settings.md) and [release-checklist.md](release-checklist.md).

## Toolchain

- Swift Package Manager only, no Xcode project ([ADR 0006](adr/0006-swiftpm-only-build.md)). Every command goes through the Makefile, the same targets CI runs.
- **Command Line Tools are enough** (`xcode-select --install`, Swift 6.2 or later). With only the Command Line Tools selected, the Makefile and `scripts/build-app.sh` pin the **macOS 26 SDK**: the macOS 27 SDK's SwiftUI macros (`@State`, `@Entry`) need compiler plugins that ship with full Xcode only.
  - With the 26 SDK overridden, SwiftPM no longer finds the Swift Testing macro plugin, so `make test` passes `-plugin-path` to it explicitly.
- **With full Xcode selected** (`sudo xcode-select -s /Applications/Xcode.app`), the pin doesn't apply and local builds use the macOS 27 SDK. The app still targets macOS 26. CI builds with Xcode 26, so APIs renamed in the 27 SDK are picked with `#if compiler(>=6.4)`. The 27 SDK also adds a SwiftUI `Anchor` type, so code in the app target spells ours as `UnfocusedCore.Anchor` where both are visible.
- Check what's selected with `xcode-select -p`.

## Commands

```bash
make setup   # once: use the repo's pre-commit hook (swift format lint)
make lint    # format check + build with warnings as errors + scripts/check-design.sh
make format  # fix formatting
make test    # Swift Testing suite
make app     # assemble build/Unfocused Dev.app
make run     # make app, then open it
```

`make app` builds the release configuration and wraps it into a bundle with `scripts/build-app.sh` (Info.plist, icon from `Branding/AppIcon.png`, signing).

## Dev builds vs. releases

| | Local (`make app`) | Release (CI, `UNFOCUSED_VERSION` set) |
|---|---|---|
| Bundle | `build/Unfocused Dev.app` | `build/Unfocused.app` |
| Display name | "unfocused dev" | "unfocused" |
| Version | `0.0.0-dev` | CalVer |

- The different file name keeps them apart in **System Settings → Privacy & Security**, which lists apps by file name. The display name shows in notifications and Activity Monitor.
- **Both use the same bundle ID** (`com.stefanhoth.unfocused`) **and the same data**: the database in `~/Library/Application Support/unfocused/`, logs in `~/Library/Logs/unfocused/`. Testing a dev build changes your real Loops. Back up `unfocused.sqlite*` first if you're about to try something destructive.
- The app is a menu bar app (`LSUIElement`): no Dock icon. Run one copy at a time.

## Signing and permissions

macOS ties Accessibility and Automation permissions to the app's **code signature**, not its name. An ad-hoc signed build gets a new signature on every rebuild, so macOS treats each one as a new app: the switch in System Settings stays on but points at a build that no longer exists, and the "can't see window titles" note never goes away.

So dev builds are signed with the **same stable self-signed certificate as releases** ([ADR 0003](adr/0003-homebrew-cask-in-public-repo.md)):

- `build-app.sh` looks in `~/Library/Application Support/unfocused-dev/signing/` (override with `UNFOCUSED_SIGNING_DIR`) for `unfocused-signing.p12` and `p12-password.txt`. If both are there, it calls `scripts/sign-app.sh` and prints "Signed with the stable certificate". Otherwise it signs ad hoc, and permissions must be granted again after every rebuild.
- `sign-app.sh` imports the certificate into a throwaway keychain, adds it to the search list, signs by the certificate's SHA-1 hash (`codesign` doesn't find a name in a keychain it only just added), and restores your keychain search list on exit. The certificate **doesn't need to be trusted**, so no sudo. The designated requirement pins the certificate leaf, which is what lets macOS keep the grant.
- The same certificate is in the Actions secrets `SIGNING_CERT_P12_BASE64` and `SIGNING_CERT_PASSWORD`. **Keep it.** A new certificate makes every Mac forget the Accessibility grant once.
- On another Mac, copy the whole `signing/` folder (mode 700, files 600). Never commit it.

How the certificate was made, for the record (only if it's ever lost; this resets the grants):

```bash
# cert.cnf: CN = unfocused self-signed, O = Stefan Hoth,
# basicConstraints = critical,CA:false, keyUsage = critical,digitalSignature,
# extendedKeyUsage = critical,codeSigning
openssl req -x509 -newkey rsa:3072 -nodes -keyout key.pem -out cert.pem -days 7300 -config cert.cnf
openssl pkcs12 -export -inkey key.pem -in cert.pem -out unfocused-signing.p12 -passout "pass:$PW" -legacy
```

`-legacy` is needed because macOS's `security import` can't read OpenSSL 3's default PKCS#12 encryption.

Check a build's signature:

```bash
codesign -d -r- "build/Unfocused Dev.app"
```

It should show `certificate leaf = H"…"`, not `cdhash`, which means it was signed ad hoc.

### Granting Accessibility

- macOS only adds the app to the Accessibility list when it asks with the prompt option. The panel's "unfocused can't see window titles yet" note has **Open Settings**, which does that.
- After switching from ad-hoc to stable signing, or from `Unfocused.app` to `Unfocused Dev.app`, remove the stale entry with **−** and switch on the new one. After that, rebuilds keep the grant.
- The Automation prompts (Safari, Chrome, Mail, Finder) appear the first time unfocused reads from each app.

## Running and reviewing surfaces

`--show` opens one surface right after launch, for design review and screenshots:

```bash
open "build/Unfocused Dev.app" --args --show panel
```

| Value | Opens |
|---|---|
| `panel` | the panel |
| `left-off` | Where did you leave off? for the newest Open Loop (nothing is saved unless ↩ is pressed) |
| `tie-off` | the Tie-off (the finish screen when there are no Loose Ends) |
| `banner` | the Switch Focus banner for the newest Open Loop |
| `settings` | the main window at Settings |
| `focus-preview` | the Focus notice and menu bar title for a made-up Loop, without changing data |

- **`open` ignores `--args` when the app is already running**; it just brings it forward. Quit the running copy first:

  ```bash
  pkill -f "Unfocused Dev.app/Contents/MacOS/Unfocused"; sleep 1; open "build/Unfocused Dev.app" --args --show panel
  ```

- The panel hides as soon as another window becomes active, such as a terminal or this chat. ⌃Space brings it back.
- The menu bar item can be hidden under the camera notch on a full menu bar. ⌘-drag it further right.

### Screenshots without clicking

The app has no Dock icon and the panel hides when it loses focus, so tools that drive apps by name may not find the dev build. A window can still be captured by its ID:

```bash
cat > /tmp/wins.swift <<'EOF'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where ((w[kCGWindowOwnerName as String] as? String) ?? "").lowercased().contains("unfocused") {
  print(w[kCGWindowNumber as String]!, w[kCGWindowLayer as String]!, w[kCGWindowBounds as String]!)
}
EOF
swift /tmp/wins.swift              # window ID, layer, bounds
screencapture -x -o -l <id> /tmp/unfocused.png
```

The owner name is the display name ("unfocused dev"), in lower case.

## Logs and diagnostics

- App log: `~/Library/Logs/unfocused/unfocused.log` (rotating). Unified log: subsystem `com.stefanhoth.unfocused`:

  ```bash
  log show --last 30m --predicate 'subsystem == "com.stefanhoth.unfocused"' --style compact
  ```

- After each showing, the panel logs `Panel text field has the cursor: true/false`. Use it to check the cursor without typing (DESIGN.md checklist).
- If the app hangs, sample the main thread:

  ```bash
  sample "$(pgrep -f 'Unfocused Dev.app/Contents/MacOS/Unfocused')" 3 -file /tmp/unfocused-sample.txt
  ```

  This is how the Automation-permission hang was found: a system call made on the main thread on every Activity sample.
- **Settings → Troubleshooting → Export diagnostics** collects logs and the app version, with no Loops, People or Activity.

## Git

- Commits are signed through the 1Password SSH agent. If 1Password is locked, `git commit` fails; unlock it rather than turning signing off.
- Dependent PRs go through `gh stack`, not by setting `--base` and rebasing by hand.
