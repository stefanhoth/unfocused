import AppKit
import SwiftUI
import UnfocusedCore

@main
struct UnfocusedApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      if let model = appDelegate.model {
        MenuContent(model: model, panel: appDelegate.panel)
      } else {
        Text("unfocused couldn't start. See ~/Library/Logs/unfocused.")
        Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
      }
    } label: {
      MenuBarLabel(model: appDelegate.model)
    }

    Window("Loops", id: WindowID.loops) {
      if let model = appDelegate.model { LoopsWindow(model: model) }
    }

    Settings {
      if let model = appDelegate.model { SettingsView(model: model) }
    }
  }
}

enum WindowID {
  static let loops = "loops"
}

struct MenuContent: View {
  let model: AppModel
  let panel: PanelController?
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    if let focused = model.focusedLoop {
      Text("Focused: \(focused.title)")
      if let note = focused.whereILeftOff { Text("Where I left off: \(note)") }
      Button("Unfocus") {
        if let left = model.unfocus() { panel?.askWhereILeftOff(left) }
      }
      Button("Close Loop") {
        if let left = model.close(focused) { panel?.askWhereILeftOff(left) }
      }
      Button("Drop Loop") {
        if let left = model.drop(focused) { panel?.askWhereILeftOff(left) }
      }
      Divider()
    } else {
      Text("Unfocused")
      Divider()
    }
    Button("Open Panel (\(model.hotKey.label))") { panel?.show() }
    Button("Loops…") {
      NSApp.activate()
      openWindow(id: WindowID.loops)
    }
    Divider()
    Button("Settings…") {
      NSApp.activate()
      openSettings()
    }
    .keyboardShortcut(",")
    Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}

/// The menu bar item: the ring, plus the Focused Loop's title when there is one.
struct MenuBarLabel: View {
  let model: AppModel?

  var body: some View {
    if let title = model?.focusedLoop?.title {
      Label(title.count > 24 ? title.prefix(23) + "…" : title, systemImage: "scope")
        .labelStyle(.titleAndIcon)
    } else {
      Image(systemName: "circle.dashed")
    }
  }
}

/// Owns app-wide services for the lifetime of the process.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Published private(set) var model: AppModel?
  @Published private(set) var panel: PanelController?

  func applicationWillFinishLaunching(_ notification: Notification) {
    // Menu bar only: no Dock icon, also when run unbundled via `swift run`.
    NSApplication.shared.setActivationPolicy(.accessory)
    do {
      let environment = try AppEnvironment.live()
      let model = AppModel(core: Core(database: environment.database), log: environment.log)
      let panel = PanelController(model: model)
      HotKeyCenter.shared.onPress = { panel.toggle() }
      self.model = model
      self.panel = panel
      environment.log.info("Launched, database ready")
    } catch {
      Log(category: "app", file: nil).error("Startup failed: \(error)")
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard let model, !model.activateSavedHotKey() else { return }
    // First launch with a taken hotkey: ask for another one right away.
    NSApp.activate()
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
  }
}
