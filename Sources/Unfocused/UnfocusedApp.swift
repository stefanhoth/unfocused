import AppKit
import SwiftUI
import UnfocusedCore

@main
struct UnfocusedApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      WithModel(app: appDelegate) { model in
        MenuContent(model: model, app: appDelegate, panel: appDelegate.panel, tieOff: appDelegate.tieOff)
      }
    } label: {
      MenuBarLabel(app: appDelegate)
    }

    Window("unfocused", id: WindowID.main) {
      WithModel(app: appDelegate) { MainWindow(model: $0, app: appDelegate) }
    }
    .commands {
      // Settings is a section of the main window, not a window of its own; ⌘, opens it there.
      CommandGroup(replacing: .appSettings) { SettingsCommand(app: appDelegate) }
    }
  }
}

/// Shows `content` once the app delegate has a model. Observed here, in a view of its own: the
/// App's body doesn't re-run for the delegate's published changes, so checking `model` there
/// froze whatever it saw first, e.g. "couldn't start" if the menu was built before launch finished.
struct WithModel<Content: View>: View {
  @ObservedObject var app: AppDelegate
  @ViewBuilder let content: (AppModel) -> Content

  var body: some View {
    if let model = app.model {
      content(model)
    } else if let problem = app.startupProblem {
      Text("unfocused couldn't start: \(problem)")
      Text("Details in ~/Library/Logs/unfocused.")
      Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
    } else {
      Text("unfocused is starting…")
    }
  }
}

enum WindowID {
  static let main = "main"
}

struct MenuContent: View {
  let model: AppModel
  let app: AppDelegate
  let panel: PanelController?
  let tieOff: TieOffController?
  @Environment(\.openWindow) private var openWindow

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
      Button("Let Go of Loop") {
        if let left = model.letGo(focused) { panel?.askWhereILeftOff(left) }
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
    Button("Loops…") { show(.loops) }
    Button("People…") { show(.people) }
    Button("Recap…") { show(.recap) }
    Button("Activity…") { show(.activity) }
    Toggle(
      "Pause Activity Recording",
      isOn: Binding(get: { model.activityPaused }, set: { model.setActivityPaused($0) })
    )
    Divider()
    Button("Settings…") { show(.settings) }
      .keyboardShortcut(",")
    Button("Quit unfocused") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }

  /// Opens the main window at `section`.
  private func show(_ section: AppSection) {
    app.show(section, openWindow: openWindow)
  }
}

/// The app menu's Settings… item (⌘,): the main window's Settings section.
struct SettingsCommand: View {
  let app: AppDelegate
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Settings…") { app.show(.settings, openWindow: openWindow) }
      .keyboardShortcut(",")
  }
}

/// The menu bar item: the ring, plus the Focused Loop's title when there is one.
struct MenuBarLabel: View {
  /// Observed here, in the label's own view: the App's body doesn't re-run for the delegate's
  /// published changes, so a value passed in from there would never update.
  @ObservedObject var app: AppDelegate
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    label.onAppear { app.windowOpener = openWindow }
  }

  @ViewBuilder private var label: some View {
    if let title = app.focusedTitle {
      Label {
        Text(title.count > 18 ? title.prefix(17) + "…" : title)
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
  /// Why startup failed, if it did.
  @Published private(set) var startupProblem: String?
  /// The main window's selected section.
  @Published var section: AppSection? = .loops
  /// Opens the SwiftUI windows from outside a view. Set by the menu bar label, the one view that
  /// is always on screen; until then, `show(_:)` waits for it.
  var windowOpener: OpenWindowAction? {
    didSet { if let pendingSection { show(pendingSection) } }
  }
  private var pendingSection: AppSection?
  @Published private(set) var tieOff: TieOffController?
  /// The Focused Loop's title for the menu bar, `nil` when unfocused.
  @Published private(set) var focusedTitle: String?
  private var focusNotice: FocusNotice?
  @Published private(set) var reminder: TieOffReminder?
  private var recorder: ActivityRecorder?
  private var banner: SwitchBannerController?
  private var editor: EditLoopController?

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
      let editor = EditLoopController(model: model)
      model.editLoop = { editor.show($0) }
      self.editor = editor
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
      startupProblem = error.localizedDescription
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    recorder?.start()
    reminder?.start()
    showForReview()
    guard let model, !model.activateSavedHotKey() else { return }
    // First launch with a taken hotkey: ask for another one right away.
    show(.settings)
  }

  /// Opens the main window at `section`.
  func show(_ section: AppSection, openWindow: OpenWindowAction? = nil) {
    self.section = section
    guard let open = openWindow ?? windowOpener else {
      pendingSection = section
      return
    }
    pendingSection = nil
    NSApp.activate()
    open(id: WindowID.main)
  }

  /// For design review and screenshots: `--show panel`, `--show tie-off`, `--show settings` or
  /// `--show banner` opens that surface right after launch.
  private func showForReview() {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--show"), arguments.indices.contains(index + 1) else { return }
    switch arguments[index + 1] {
    case "panel": panel?.show()
    // Where did you leave off? for the newest Open Loop. Nothing is saved unless ↩ is pressed.
    case "left-off": if let loop = model?.openLoops.first { panel?.askWhereILeftOff(loop) }
    case "tie-off": tieOff?.show()
    case "settings": show(.settings)
    case "banner": banner?.update(model?.openLoops.first)
    // Shows the menu bar label and notice as if a Loop were Focused, without changing any data.
    case "focus-preview":
      let preview = Loop(id: UUID(), title: "Write the onboarding spec", state: .open, capturedAt: Date())
      focusedTitle = preview.title
      focusNotice?.show(focused: preview, left: nil)
    default: break
    }
  }
}
