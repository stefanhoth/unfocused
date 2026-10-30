import AppKit
import SwiftUI
import UnfocusedCore

@main
struct UnfocusedApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("unfocused", systemImage: "circle.dashed") {
      Text("unfocused")
      Divider()
      Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
        .keyboardShortcut("q")
    }
  }
}

/// Owns app-wide services for the lifetime of the process.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private(set) var environment: AppEnvironment?

  func applicationWillFinishLaunching(_ notification: Notification) {
    // Menu bar only: no Dock icon, also when run unbundled via `swift run`.
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      environment = try AppEnvironment.live()
      environment?.log.info("Launched, database ready")
    } catch {
      let fallback = Log(category: "app", file: nil)
      fallback.error("Startup failed: \(error)")
    }
  }
}
