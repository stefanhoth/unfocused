# Domain core as a UI-free Swift package

The rules of unfocused (Loop states, Loose End computation, Activity attribution, People and Loop deduplication) live in a Swift package with no dependency on SwiftUI, AppKit or system permissions, built test-first with Swift Testing. The macOS app is a thin adapter that connects the core to hotkeys, Accessibility, Apple Events and the UI. This keeps the logic fast to test and safe to change, and lets other front ends, such as a CLI for exports or agent access, use the same core and database without going through the app.
