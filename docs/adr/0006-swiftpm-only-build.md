---
status: accepted
---

# SwiftPM-only build, no Xcode project

The app is built entirely with Swift Package Manager: `Package.swift` defines the Core library, the app executable and the tests, and a script assembles the `.app` bundle (Info.plist, signing) from the release binary. We chose this over an Xcode project (or a generator like XcodeGen/Tuist) because the Command Line Tools already ship SwiftUI, AppKit, FoundationModels and Swift Testing, so no full Xcode install is required, there's no merge-hostile `.pbxproj`, and agents, CI and developers all run the same `make` commands. The cost: no asset catalogs (the app icon is an `.icns` built with `iconutil`), no SwiftUI previews outside Xcode, and bundle details live in a script. `Package.swift` still opens in Xcode when its debugger or previews are wanted.
