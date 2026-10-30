import AppKit
import Observation
import UnfocusedCore

/// App-wide state for the UI. Every change goes through Core; the model only mirrors it.
@MainActor
@Observable
final class AppModel {
  private(set) var openLoops: [Loop] = []
  private(set) var focusedLoop: Loop?
  private(set) var hotKey: HotKeyChoice = .default
  /// Why the chosen hotkey can't be used, shown in Settings.
  private(set) var hotKeyProblem: String?
  private(set) var lastError: String?

  @ObservationIgnored let core: Core
  @ObservationIgnored let log: Log

  init(core: Core, log: Log) {
    self.core = core
    self.log = log
    refresh()
  }

  func refresh() {
    do {
      openLoops = try core.openLoops()
      focusedLoop = try core.focusedLoop()
    } catch {
      report(error, while: "loading Loops")
    }
  }

  func search(_ query: String) -> [Loop] {
    (try? core.searchOpenLoops(query)) ?? []
  }

  /// Returns the new Loop, or `nil` if nothing was captured.
  @discardableResult
  func capture(title: String) -> Loop? {
    do {
      let loop = try core.capture(title: title)
      log.info("Captured Loop \(loop.id)")
      refresh()
      return loop
    } catch CoreError.emptyTitle {
      return nil
    } catch {
      report(error, while: "capturing")
      return nil
    }
  }

  /// Focuses `loop`. Returns the Loop the user just left, so they can say where they left off.
  @discardableResult
  func focus(_ loop: Loop) -> Loop? {
    let previous = focusedLoop
    do {
      try core.focus(loop.id)
      log.info("Focused Loop \(loop.id)")
    } catch {
      report(error, while: "focusing")
    }
    refresh()
    return previous?.id == loop.id ? nil : previous
  }

  /// Ends the current Focus. Returns the Loop the user just left.
  @discardableResult
  func unfocus() -> Loop? {
    let previous = focusedLoop
    do {
      try core.unfocus()
      log.info("Unfocused")
    } catch {
      report(error, while: "unfocusing")
    }
    refresh()
    return previous
  }

  /// Closes `loop`. Returns it when it was the Focused Loop, so the user can say where they left off.
  @discardableResult
  func close(_ loop: Loop) -> Loop? {
    changeState(of: loop, "closing") { try core.close(loop.id) }
  }

  /// Drops `loop`. Returns it when it was the Focused Loop.
  @discardableResult
  func drop(_ loop: Loop) -> Loop? {
    changeState(of: loop, "dropping") { try core.drop(loop.id) }
  }

  func reopen(_ loop: Loop) {
    _ = changeState(of: loop, "reopening") { try core.reopen(loop.id) }
  }

  func loops(in state: LoopState) -> [Loop] {
    (try? core.loops(in: state)) ?? []
  }

  func history(for loop: Loop) -> [LoopEvent] {
    (try? core.history(for: loop.id)) ?? []
  }

  func focusSessions(for loop: Loop) -> [FocusSession] {
    (try? core.focusSessions(for: loop.id)) ?? []
  }

  private func changeState(of loop: Loop, _ action: String, _ change: () throws -> Void) -> Loop? {
    let wasFocused = focusedLoop?.id == loop.id
    do {
      try change()
      log.info("Finished \(action) Loop \(loop.id)")
    } catch {
      report(error, while: "\(action) a Loop")
    }
    refresh()
    return wasFocused ? loop : nil
  }

  func setWhereILeftOff(_ loop: Loop, to note: String) {
    do {
      try core.setWhereILeftOff(loop.id, to: note)
    } catch {
      report(error, while: "saving where you left off")
    }
    refresh()
  }

  // MARK: Hotkey

  /// Loads the saved hotkey and registers it. Returns `false` when it conflicts.
  @discardableResult
  func activateSavedHotKey() -> Bool {
    let saved = (try? core.database.setting(HotKeyChoice.settingKey)).flatMap(HotKeyChoice.init(rawValue:))
    return useHotKey(saved ?? .default)
  }

  @discardableResult
  func useHotKey(_ choice: HotKeyChoice) -> Bool {
    hotKey = choice
    try? core.database.setSetting(HotKeyChoice.settingKey, to: choice.rawValue)
    if let conflict = SystemShortcuts.conflict(for: choice) {
      HotKeyCenter.shared.unregister()
      hotKeyProblem = "\(choice.label) is already used by macOS (“\(conflict)”). Pick another key."
    } else if !HotKeyCenter.shared.register(choice) {
      hotKeyProblem = "\(choice.label) is already used by another app. Pick another key."
    } else {
      hotKeyProblem = nil
    }
    if let hotKeyProblem { log.info("Hotkey unavailable: \(hotKeyProblem)") }
    return hotKeyProblem == nil
  }

  private func report(_ error: any Error, while action: String) {
    lastError = "Something went wrong while \(action)."
    log.error("Failed while \(action): \(error)")
  }
}
