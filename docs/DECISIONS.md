# Decisions

Smaller calls that don't warrant an ADR. Newest first; add entries in the PR that makes the decision.

- **2026-10-30**: Builds use the macOS 26 SDK (`SDKROOT` set in the Makefile and app script). With only the Command Line Tools, the macOS 27 SDK's SwiftUI macros (`@State`) fail because their compiler plugin ships with full Xcode only.
- **2026-10-30**: The panel hotkey is a fixed set of choices (⌃Space default, ⌥Space, ⌃⌥Space, ⌃⇧Space, ⌘⇧Space), registered through Carbon (no permission needed). A choice conflicts if another app holds it or an enabled macOS shortcut uses it; input-source switching only counts when more than one input source is enabled.
- **2026-10-30**: Core is a separate *module* (library target) in the root package rather than its own package. Target dependencies already keep it free of SwiftUI/AppKit, and a future CLI can depend on the same library product.
- **2026-10-30**: Lint is `swift format` (bundled with the toolchain) plus a build with warnings as errors; no SwiftLint, to avoid a second tool that needs installing.
- **2026-10-30**: Bundle identifier `com.stefanhoth.unfocused`; the same string is the `os.Logger` subsystem.
- **2026-10-30**: Swift tools version 6.2 with Swift 6 language mode and the `ExistentialAny` and `InternalImportsByDefault` upcoming features, so CI's Xcode 26 toolchain and newer local toolchains both build it.
