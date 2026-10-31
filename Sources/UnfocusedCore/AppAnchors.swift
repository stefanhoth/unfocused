public import Foundation

extension Source {
  static let notionBundleID = "notion.id"
  static let todoistBundleID = "com.todoist.mac.Todoist"
  static let obsidianBundleID = "md.obsidian"
}

extension Anchor {
  // MARK: Files

  /// A file, e.g. selected in Finder or open in a document-based app such as Pages. Reopens the
  /// file in `bundleID`'s app.
  public static func file(url: URL, bundleID: String) -> Anchor? {
    guard url.isFileURL else { return nil }
    let path = url.standardizedFileURL.path
    guard !path.isEmpty, path != "/" else { return nil }
    return Anchor(
      source: .app(bundleID),
      identifier: "file:\(path)",
      link: url.standardizedFileURL.absoluteString,
      title: url.lastPathComponent
    )
  }

  // MARK: Obsidian

  /// "Weekly plan - Work - Obsidian v1.6.7" → the note "Weekly plan" in vault "Work", reopened with
  /// an `obsidian://open` link.
  public static func obsidianWindow(title windowTitle: String) -> Anchor? {
    var parts = windowTitle.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count >= 3, parts.last?.hasPrefix("Obsidian") == true else { return nil }
    parts.removeLast()
    let vault = parts.removeLast()
    let note = parts.joined(separator: " - ")
    guard !note.isEmpty, !vault.isEmpty else { return nil }
    var link = URLComponents()
    link.scheme = "obsidian"
    link.host = "open"
    link.queryItems = [URLQueryItem(name: "vault", value: vault), URLQueryItem(name: "file", value: note)]
    return Anchor(
      source: .app(Source.obsidianBundleID),
      identifier: "obsidian:\(vault)/\(note)",
      link: link.string ?? Source.obsidianBundleID,
      title: note
    )
  }

  // MARK: Firefox

  /// Firefox offers no way to read the URL, so its window title stands in:
  /// "Pricing — Mozilla Firefox". Private windows are reported so they're never recorded.
  public static func firefoxWindow(title windowTitle: String) -> (anchor: Anchor, isPrivate: Bool)? {
    let suffixes: [(String, Bool)] = [
      (" — Mozilla Firefox Private Browsing", true), (" - Mozilla Firefox Private Browsing", true),
      (" — Private Browsing", true), (" - Private Browsing", true),
      (" — Mozilla Firefox", false), (" - Mozilla Firefox", false),
    ]
    for (suffix, isPrivate) in suffixes where windowTitle.hasSuffix(suffix) {
      let page = String(windowTitle.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
      guard !page.isEmpty else { return nil }
      let anchor = Anchor(source: .firefox, identifier: "firefox:\(page)", link: "", title: page)
      return (anchor, isPrivate)
    }
    return nil
  }

  // MARK: Notion and Todoist

  /// Notion's window title is the page title. Good for matching; a copied page link is exact.
  public static func notionWindow(title windowTitle: String) -> Anchor? {
    let page = windowTitle.trimmingCharacters(in: .whitespaces)
    guard !page.isEmpty, page != "Notion" else { return nil }
    return Anchor(
      source: .app(Source.notionBundleID),
      identifier: "notion-window:\(page)",
      link: Source.notionBundleID,
      title: page
    )
  }

  /// A link copied in an app that can't be read directly (Notion's Copy link, Todoist's Copy link
  /// to task), if it belongs to that app. The exact item; reopens through the link.
  public static func copiedLink(_ text: String, for bundleID: String, title: String? = nil) -> Anchor? {
    let hosts: [String: [String]] = [
      Source.notionBundleID: ["notion.so", "www.notion.so"],
      Source.todoistBundleID: ["todoist.com", "app.todoist.com"],
    ]
    guard
      let allowed = hosts[bundleID],
      let host = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased(),
      allowed.contains(host) || host.hasSuffix(".notion.site") && bundleID == Source.notionBundleID,
      let page = Anchor.webPage(url: text, title: title ?? "", source: .app(bundleID))
    else { return nil }
    return page
  }
}
