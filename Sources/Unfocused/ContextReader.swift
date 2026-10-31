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

    let mayAsk = prompting || automationAllowed(bundleID)
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
    default:
      break
    }

    let title = Permissions.hasAccessibility ? focusedWindowTitle(of: app) : nil
    if bundleID == "com.tinyspeck.slackmacgap", let anchor = slackAnchor(windowTitle: title, prompting: prompting) {
      return CaptureContext(anchor: anchor, missingAccessibility: false)
    }
    let anchor = Anchor.appWindow(bundleID: bundleID, appName: app.localizedName ?? bundleID, windowTitle: title)
    return CaptureContext(anchor: anchor, missingAccessibility: !Permissions.hasAccessibility)
  }

  // MARK: Browsers (Apple Events; macOS asks for Automation permission on first use)

  private static let safariScript = """
    tell application id "com.apple.Safari"
      if (count of documents) is 0 then return {"", "", ""}
      return {URL of front document, name of front document, ""}
    end tell
    """

  private static let chromeScript = """
    tell application id "com.google.Chrome"
      if (count of windows) is 0 then return {"", "", ""}
      set t to active tab of front window
      return {URL of t, title of t, mode of front window}
    end tell
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
    tell application id "com.apple.mail"
      set picked to selection
      if (count of picked) is 0 then return {"", ""}
      set m to item 1 of picked
      return {message id of m, subject of m}
    end tell
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
  private static func automationAllowed(_ bundleID: String) -> Bool {
    var target = AEAddressDesc()
    let bytes = Array(bundleID.utf8)
    guard AECreateDesc(DescType(typeApplicationBundleID), bytes, bytes.count, &target) == noErr else { return false }
    defer { AEDisposeDesc(&target) }
    return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)
      == noErr
  }

  // MARK: Fallback (Accessibility)

  private static func focusedWindowTitle(of app: NSRunningApplication) -> String? {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var window: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
      let window, CFGetTypeID(window) == AXUIElementGetTypeID()
    else { return nil }
    var title: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        unsafeDowncast(window, to: AXUIElement.self),
        kAXTitleAttribute as CFString,
        &title
      ) == .success
    else { return nil }
    return title as? String
  }
}

/// System permissions, requested only when a feature first needs them.
@MainActor
enum Permissions {
  static var hasAccessibility: Bool { AXIsProcessTrusted() }

  /// Shows macOS's Accessibility prompt (it opens System Settings).
  static func requestAccessibility() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
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
      guard let url = URL(string: anchor.link) else { return }
      NSWorkspace.shared.open(url)
    }
  }
}
