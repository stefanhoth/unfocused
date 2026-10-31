import AppKit
import SwiftUI
import UnfocusedCore

@main
struct UnfocusedApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      if let model = appDelegate.model {
        MenuContent(model: model, panel: appDelegate.panel, tieOff: appDelegate.tieOff)
      } else {
        Text("unfocused couldn't start. See ~/Library/Logs/unfocused.")
        Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
      }
    } label: {
      MenuBarLabel(focusedTitle: appDelegate.focusedTitle)
    }

    Window("Loops", id: WindowID.loops) {
      if let model = appDelegate.model { LoopsWindow(model: model) }
    }

    Window("Activity", id: WindowID.activity) {
      if let model = appDelegate.model { ActivityWindow(model: model) }
    }

    Window("Recap", id: WindowID.recap) {
      if let model = appDelegate.model { RecapWindow(model: model) }
    }

    Window("People", id: WindowID.people) {
      if let model = appDelegate.model { PeopleWindow(model: model) }
    }

    Settings {
      if let model = appDelegate.model { SettingsView(model: model, reminder: appDelegate.reminder) }
    }
  }
}

enum WindowID {
  static let loops = "loops"
  static let people = "people"
  static let activity = "activity"
  static let recap = "recap"
}

struct MenuContent: View {
  let model: AppModel
  let panel: PanelController?
  let tieOff: TieOffController?
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
    Button(model.looseEnds.isEmpty ? "Tie-off…" : "Tie-off (\(model.looseEnds.count) Loose Ends)…") {
      tieOff?.show()
    }
    Button("Loops…") {
      NSApp.activate()
      openWindow(id: WindowID.loops)
    }
    Button("People…") {
      NSApp.activate()
      openWindow(id: WindowID.people)
    }
    Button("Recap…") {
      NSApp.activate()
      openWindow(id: WindowID.recap)
    }
    Button("Activity…") {
      NSApp.activate()
      openWindow(id: WindowID.activity)
    }
    Toggle(
      "Pause Activity Recording",
      isOn: Binding(get: { model.activityPaused }, set: { model.setActivityPaused($0) })
    )
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
  /// From the app delegate rather than the model: menu bar labels reliably redraw for published
  /// properties of the app delegate, not always for changes inside an observed model.
  let focusedTitle: String?

  var body: some View {
    if let title = focusedTitle {
      Label {
        Text(title.count > 24 ? title.prefix(23) + "…" : title)
      } icon: {
        Image(nsImage: MenuBarGlyph.image(focused: true))
      }
      .labelStyle(.titleAndIcon)
    } else {
      Image(nsImage: MenuBarGlyph.image(focused: false))
    }
  }
}

/// Owns app-wide services for the lifetime of the process.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Published private(set) var model: AppModel?
  @Published private(set) var panel: PanelController?
  @Published private(set) var tieOff: TieOffController?
  /// The Focused Loop's title for the menu bar, `nil` when unfocused.
  @Published private(set) var focusedTitle: String?
  private var focusNotice: FocusNotice?
  @Published private(set) var reminder: TieOffReminder?
  private var recorder: ActivityRecorder?
  private var banner: SwitchBannerController?

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
      let recorder = ActivityRecorder(core: model.core, log: environment.log)
      recorder.onReturn = { [weak model] interruption in
        model?.refresh()
        panel.askAboutInterruption(interruption)
      }
      let banner = SwitchBannerController(model: model, panelController: panel)
      recorder.onSwitchSuggestion = { banner.update($0) }
      self.banner = banner
      self.recorder = recorder
      let tieOff = TieOffController(model: model)
      self.tieOff = tieOff
      reminder = TieOffReminder(model: model, tieOff: tieOff)
      let notice = FocusNotice()
      focusNotice = notice
      focusedTitle = model.focusedLoop?.title
      model.onFocusChange = { [weak self] now, before in
        self?.focusedTitle = now?.title
        notice.show(focused: now, left: before)
      }
      recorder.onFocusInterrupted = { [weak model] in model?.refresh() }
      model.endStaleFocus()
      environment.log.info("Launched, database ready")
    } catch {
      Log(category: "app", file: nil).error("Startup failed: \(error)")
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    recorder?.start()
    reminder?.start()
    showForReview()
    guard let model, !model.activateSavedHotKey() else { return }
    // First launch with a taken hotkey: ask for another one right away.
    NSApp.activate()
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
  }

  /// For design review and screenshots: `--show panel`, `--show tie-off` or `--show banner` opens
  /// that surface right after launch.
  private func showForReview() {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--show"), arguments.indices.contains(index + 1) else { return }
    switch arguments[index + 1] {
    case "panel": panel?.show()
    case "tie-off": tieOff?.show()
    case "banner": banner?.update(model?.openLoops.first)
    default: break
    }
  }
}
