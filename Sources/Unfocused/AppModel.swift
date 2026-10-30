import AppKit
import Observation
import UnfocusedCore

/// App-wide state for the UI. Every change goes through Core; the model only mirrors it.
@MainActor
@Observable
final class AppModel {
  private(set) var openLoops: [Loop] = []
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
