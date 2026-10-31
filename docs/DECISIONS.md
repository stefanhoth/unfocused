# Decisions

Smaller calls that don't warrant an ADR. Newest first; add entries in the PR that makes the decision.

- **2026-10-31**: The release pushes the cask to `main` with a write deploy key in its own job, because personal repos can't add "GitHub Actions" to a ruleset bypass list. Only that job holds the key, and it runs nothing but `scripts/write-cask.sh`.
- **2026-10-31**: No PR auto-update workflow. Branch updates pushed with the built-in `GITHUB_TOKEN` don't trigger CI, so an updated PR loses its required checks and blocks. Out-of-date PRs are rebased by whoever drives them.
- **2026-10-30**: Releases are CalVer (`YYYY.MM.DD`, then `.2`, `.3` on the same day) and run by hand from the Release workflow, not on every merge. Every update of an unnotarized app needs a Gatekeeper approval, so frequent automatic releases would cost the user more than they'd gain.
- **2026-10-30**: Release signing runs in a separate job from the build, so the job holding the certificate never resolves or compiles dependencies.
- **2026-10-30**: Builds use the macOS 26 SDK (`SDKROOT` set in the Makefile and app script). With only the Command Line Tools, the macOS 27 SDK's SwiftUI macros (`@State`) fail because their compiler plugin ships with full Xcode only.
- **2026-10-30**: The panel hotkey is a fixed set of choices (⌃Space default, ⌥Space, ⌃⌥Space, ⌃⇧Space, ⌘⇧Space), registered through Carbon (no permission needed). A choice conflicts if another app holds it or an enabled macOS shortcut uses it; input-source switching only counts when more than one input source is enabled.
- **2026-10-30**: Core is a separate *module* (library target) in the root package rather than its own package. Target dependencies already keep it free of SwiftUI/AppKit, and a future CLI can depend on the same library product.
- **2026-10-30**: Lint is `swift format` (bundled with the toolchain) plus a build with warnings as errors; no SwiftLint, to avoid a second tool that needs installing.
- **2026-10-30**: Bundle identifier `com.stefanhoth.unfocused`; the same string is the `os.Logger` subsystem.
- **2026-10-30**: Swift tools version 6.2 with Swift 6 language mode and the `ExistentialAny` and `InternalImportsByDefault` upcoming features, so CI's Xcode 26 toolchain and newer local toolchains both build it.
