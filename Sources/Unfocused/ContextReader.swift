import AppKit
import ApplicationServices
import UnfocusedCore

/// What was in front of the user when they opened the panel.
struct CaptureContext {
  let anchor: Anchor
  /// The window title is missing only because Accessibility isn't granted yet.
  let missingAccessibility: Bool
  /// A private (incognito) browser window: fine to capture on purpose, never recorded as Activity.
  var isPrivate = false
}

/// Turns the frontmost app into an Anchor. Best effort: never fails, at worst returns the app itself.
@MainActor
enum ContextReader {
  /// `prompting: false` never triggers a permission prompt (for background Activity recording):
  /// browsers are only asked once the user has allowed it during a Capture.
  static func read(_ app: NSRunningApplication?, prompting: Bool = true) -> CaptureContext? {
    guard
      let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
      let bundleID = app.bundleIdentifier
    else { return nil }

    // Only the apps unfocused scripts need the Automation check, and in the background it must never
    // wait: the system call can block for a long time.
    let mayAsk = prompting || (scriptedApps.contains(bundleID) && automationAllowed(bundleID))
    switch bundleID {
    case "com.apple.Safari" where mayAsk:
      if let (anchor, _) = browserPage(bundleID, source: .safari, script: safariScript) {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    case "com.google.Chrome" where mayAsk:
      if let (anchor, isPrivate) = browserPage(bundleID, source: .chrome, script: chromeScript) {
        return CaptureContext(anchor: anchor, missingAccessibility: false, isPrivate: isPrivate)
      }
    case "com.apple.mail" where mayAsk:
      if let anchor = selectedMailMessage() {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    case "com.apple.finder" where mayAsk:
      if let anchor = selectedFinderItem() {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    default:
      break
    }

    let window = Permissions.hasAccessibility ? focusedWindow(of: app) : nil
    let title = window.flatMap { string($0, kAXTitleAttribute) }
    switch bundleID {
    case "com.tinyspeck.slackmacgap":
      if let anchor = slackAnchor(windowTitle: title, prompting: prompting) {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    case "org.mozilla.firefox":
      if let title, let page = Anchor.firefoxWindow(title: title) {
        return CaptureContext(anchor: page.anchor, missingAccessibility: false, isPrivate: page.isPrivate)
      }
    case "md.obsidian":
      if let anchor = title.flatMap(Anchor.obsidianWindow(title:)) {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    case "notion.id", "com.todoist.mac.Todoist":
      if prompting, let copied = NSPasteboard.general.string(forType: .string),
        let anchor = Anchor.copiedLink(copied, for: bundleID, title: title)
      {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
      if bundleID == "notion.id", let anchor = title.flatMap(Anchor.notionWindow(title:)) {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    default:
      // Document-based apps (Pages, Numbers, Preview, TextEdit, …) name the open file.
      if let document = window.flatMap({ string($0, kAXDocumentAttribute) }), let url = URL(string: document),
        let anchor = Anchor.file(url: url, bundleID: bundleID)
      {
        return CaptureContext(anchor: anchor, missingAccessibility: false)
      }
    }
    let anchor = Anchor.appWindow(bundleID: bundleID, appName: app.localizedName ?? bundleID, windowTitle: title)
    return CaptureContext(anchor: anchor, missingAccessibility: !Permissions.hasAccessibility)
  }

  // MARK: Browsers (Apple Events; macOS asks for Automation permission on first use)

  private static let safariScript = """
    with timeout of 3 seconds
    tell application id "com.apple.Safari"
      if (count of documents) is 0 then return {"", "", ""}
      return {URL of front document, name of front document, ""}
    end tell
    end timeout
    """

  private static let chromeScript = """
    with timeout of 3 seconds
    tell application id "com.google.Chrome"
      if (count of windows) is 0 then return {"", "", ""}
      set t to active tab of front window
      return {URL of t, title of t, mode of front window}
    end tell
    end timeout
    """

  /// The front page and whether its window is private.
  private static func browserPage(_ bundleID: String, source: Source, script: String) -> (Anchor, Bool)? {
    var error: NSDictionary?
    guard
      let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
      result.numberOfItems == 3,
      let url = result.atIndex(1)?.stringValue,
      let title = result.atIndex(2)?.stringValue,
      let anchor = Anchor.webPage(url: url, title: title, source: source)
    else {
      if let error { Log(category: "context", file: nil).info("Couldn't read \(bundleID): \(error)") }
      return nil
    }
    return (anchor, result.atIndex(3)?.stringValue == "incognito")
  }

  // MARK: Mail (Apple Events)

  private static let mailScript = """
    with timeout of 3 seconds
    tell application id "com.apple.mail"
      set picked to selection
      if (count of picked) is 0 then return {"", ""}
      set m to item 1 of picked
      return {message id of m, subject of m}
    end tell
    end timeout
    """

  /// The message selected in Mail, exactly.
  private static func selectedMailMessage() -> Anchor? {
    var error: NSDictionary?
    guard
      let result = NSAppleScript(source: mailScript)?.executeAndReturnError(&error),
      result.numberOfItems == 2,
      let id = result.atIndex(1)?.stringValue,
      let subject = result.atIndex(2)?.stringValue
    else {
      if let error { Log(category: "context", file: nil).info("Couldn't read Mail: \(error)") }
      return nil
    }
    return Anchor.mailMessage(messageID: id, subject: subject)
  }

  // MARK: Finder (Apple Events)

  private static let finderScript = """
    with timeout of 3 seconds
    tell application id "com.apple.finder"
      set picked to selection
      if (count of picked) > 0 then return POSIX path of (item 1 of picked as alias)
      if (count of Finder windows) > 0 then return POSIX path of (target of front Finder window as alias)
      return ""
    end tell
    end timeout
    """

  /// The file or folder selected in Finder, or the front window's folder.
  private static func selectedFinderItem() -> Anchor? {
    var error: NSDictionary?
    guard
      let path = NSAppleScript(source: finderScript)?.executeAndReturnError(&error).stringValue,
      !path.isEmpty
    else {
      if let error { Log(category: "context", file: nil).info("Couldn't read Finder: \(error)") }
      return nil
    }
    return Anchor.file(url: URL(fileURLWithPath: path), bundleID: "com.apple.finder")
  }

  // MARK: Slack (no scripting; a copied message link is exact, the window title is the conversation)

  /// During a Capture, a Slack message link on the clipboard ("Copy link") pins the exact thread.
  /// The clipboard is never read in the background.
  private static func slackAnchor(windowTitle: String?, prompting: Bool) -> Anchor? {
    let fromWindow = windowTitle.flatMap(Anchor.slackWindow(title:))
    if prompting, let copied = NSPasteboard.general.string(forType: .string),
      let link = Anchor.slackLink(copied, title: fromWindow?.title)
    {
      return link
    }
    return fromWindow
  }

  /// Whether the user already allowed sending Apple Events to this app. Never prompts.
  /// Apps unfocused reads over Apple Events.
  private static let scriptedApps: Set<String> = [
    "com.apple.Safari", "com.google.Chrome", "com.apple.mail", "com.apple.finder",
  ]

  /// Known answers to "may unfocused script this app?", refreshed in the background.
  private static var automationAnswers: [String: (allowed: Bool, checked: Date)] = [:]
  private static var automationChecks: Set<String> = []

  /// Whether the user already allowed sending Apple Events to this app. Never prompts and never
  /// blocks: it answers from what's known (false at first) and refreshes that in the background.
  private static func automationAllowed(_ bundleID: String) -> Bool {
    let known = automationAnswers[bundleID]
    if known == nil || Date().timeIntervalSince(known?.checked ?? .distantPast) > 60,
      automationChecks.insert(bundleID).inserted
    {
      Task.detached(priority: .utility) {
        let allowed = determineAutomation(bundleID)
        await MainActor.run {
          automationAnswers[bundleID] = (allowed, Date())
          automationChecks.remove(bundleID)
        }
      }
    }
    return known?.allowed ?? false
  }

  /// The system's answer; may block, so only ever called off the main thread.
  nonisolated private static func determineAutomation(_ bundleID: String) -> Bool {
    var target = AEAddressDesc()
    let bytes = Array(bundleID.utf8)
    guard AECreateDesc(DescType(typeApplicationBundleID), bytes, bytes.count, &target) == noErr else { return false }
    defer { AEDisposeDesc(&target) }
    return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)
      == noErr
  }

  // MARK: Fallback (Accessibility)

  private static func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var window: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
      let window, CFGetTypeID(window) == AXUIElementGetTypeID()
    else { return nil }
    return unsafeDowncast(window, to: AXUIElement.self)
  }

  private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
  }
}

/// System permissions, requested only when a feature first needs them.
@MainActor
enum Permissions {
  static var hasAccessibility: Bool { AXIsProcessTrusted() }

  /// Shows macOS's Accessibility prompt (it opens System Settings).
  /// Adds unfocused to the Accessibility list (the prompt registers it; macOS shows it only once) and
  /// opens that pane.
  static func requestAccessibility() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(pane)
    }
  }
}

/// Opens Anchors: web pages in the browser, apps by bundle identifier.
@MainActor
enum AnchorOpener {
  static func open(_ anchor: Anchor) {
    switch anchor.source {
    case .app(let bundleID):
      // Exact links (a Mail message, a Slack thread) open the item; otherwise just the app.
      if let url = URL(string: anchor.link), url.scheme != nil {
        NSWorkspace.shared.open(url)
        return
      }
      guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
      NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    default:
      if let url = URL(string: anchor.link), url.scheme != nil {
        NSWorkspace.shared.open(url)
      } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: anchor.source.bundleID) {
        // No address to go back to (Firefox): at least bring the app forward.
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
      }
    }
  }
}
