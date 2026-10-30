import AppKit
import Carbon.HIToolbox

/// The hotkeys the user can pick for opening the panel.
enum HotKeyChoice: String, CaseIterable, Identifiable {
  case controlSpace
  case optionSpace
  case controlOptionSpace
  case controlShiftSpace
  case commandShiftSpace

  static let `default` = HotKeyChoice.controlSpace
  static let settingKey = "hotkey"

  var id: String { rawValue }
  var keyCode: UInt32 { UInt32(kVK_Space) }

  var label: String {
    switch self {
    case .controlSpace: "⌃Space"
    case .optionSpace: "⌥Space"
    case .controlOptionSpace: "⌃⌥Space"
    case .controlShiftSpace: "⌃⇧Space"
    case .commandShiftSpace: "⌘⇧Space"
    }
  }

  var carbonModifiers: UInt32 {
    switch self {
    case .controlSpace: UInt32(controlKey)
    case .optionSpace: UInt32(optionKey)
    case .controlOptionSpace: UInt32(controlKey | optionKey)
    case .controlShiftSpace: UInt32(controlKey | shiftKey)
    case .commandShiftSpace: UInt32(cmdKey | shiftKey)
    }
  }

  /// The same modifiers as Cocoa flags, the format macOS uses for its own shortcuts.
  var cocoaModifiers: NSEvent.ModifierFlags {
    switch self {
    case .controlSpace: [.control]
    case .optionSpace: [.option]
    case .controlOptionSpace: [.control, .option]
    case .controlShiftSpace: [.control, .shift]
    case .commandShiftSpace: [.command, .shift]
    }
  }
}

/// Registers one global hotkey through Carbon, which needs no permissions.
@MainActor
final class HotKeyCenter {
  static let shared = HotKeyCenter()

  var onPress: (() -> Void)?
  private var registered: EventHotKeyRef?
  private var handlerInstalled = false

  /// Registers `choice`, replacing any previous hotkey. Returns `false` if another app holds it.
  func register(_ choice: HotKeyChoice) -> Bool {
    unregister()
    installHandlerIfNeeded()
    var reference: EventHotKeyRef?
    let id = EventHotKeyID(signature: OSType(0x554E_4643), id: 1)  // "UNFC"
    let status = RegisterEventHotKey(
      choice.keyCode,
      choice.carbonModifiers,
      id,
      GetApplicationEventTarget(),
      0,
      &reference
    )
    guard status == noErr else { return false }
    registered = reference
    return true
  }

  func unregister() {
    if let registered { UnregisterEventHotKey(registered) }
    registered = nil
  }

  private func installHandlerIfNeeded() {
    guard !handlerInstalled else { return }
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, _ in
        // Carbon delivers hotkey events on the main thread.
        MainActor.assumeIsolated { HotKeyCenter.shared.onPress?() }
        return noErr
      },
      1,
      &spec,
      nil,
      nil
    )
    handlerInstalled = true
  }
}

/// Finds macOS's own keyboard shortcuts that would swallow a hotkey.
enum SystemShortcuts {
  private static let names: [String: String] = [
    "60": "Select the previous input source",
    "61": "Select next source in Input menu",
    "64": "Show Spotlight search",
    "65": "Show Finder search window",
  ]

  /// The name of the enabled system shortcut using `choice`, if any.
  static func conflict(for choice: HotKeyChoice) -> String? {
    guard
      let shortcuts = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
        .dictionary(forKey: "AppleSymbolicHotKeys")
    else { return nil }
    let relevantFlags: NSEvent.ModifierFlags = [.control, .option, .command, .shift]
    for (id, value) in shortcuts {
      guard
        let entry = value as? [String: Any],
        (entry["enabled"] as? Bool) == true,
        let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
        parameters.count == 3,
        parameters[1] == Int(choice.keyCode),
        NSEvent.ModifierFlags(rawValue: UInt(parameters[2])).intersection(relevantFlags) == choice.cocoaModifiers
      else { continue }
      // Input-source switching only matters with more than one input source.
      if id == "60" || id == "61", enabledInputSourceCount() < 2 { continue }
      return names[id] ?? "A macOS keyboard shortcut"
    }
    return nil
  }

  private static func enabledInputSourceCount() -> Int {
    let filter = [kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
      return 0
    }
    return list.filter { source in
      guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else { return false }
      let category = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
      return category == kTISCategoryKeyboardInputSource as String
    }.count
  }
}
