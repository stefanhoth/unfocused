# Local-only native Swift app with on-device AI

unfocused has no server, no account and no sync: data, logs and intelligence all stay on the Mac. It's built in native Swift/SwiftUI because the product depends on system-level integrations (Accessibility, global hotkeys, the menu bar) and on Apple's on-device Foundation Models, and Mac is the only target. Cloud AI providers may be added later as an opt-in, but nothing in the core may depend on one.
