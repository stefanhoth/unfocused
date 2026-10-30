import Foundation

/// The app or system an Anchor points into (see GLOSSARY.md).
public enum Source: Hashable, Sendable {
  case safari
  case chrome
  case firefox
  /// Any other app, by bundle identifier. Its Anchors only reopen the app.
  case app(String)

  /// Stable text form, used for storage.
  public var stored: String {
    switch self {
    case .safari: "safari"
    case .chrome: "chrome"
    case .firefox: "firefox"
    case .app(let bundleID): "app:\(bundleID)"
    }
  }

  public init(stored: String) {
    switch stored {
    case "safari": self = .safari
    case "chrome": self = .chrome
    case "firefox": self = .firefox
    default: self = .app(String(stored.dropFirst("app:".count)))
    }
  }
}

/// A link from a Loop back to the exact spot where the work lives.
public struct Anchor: Hashable, Sendable {
  public let source: Source
  /// Normalised key: two Anchors with the same identifier point at the same spot.
  public let identifier: String
  /// What to open to get back there: a URL, or an app's bundle identifier.
  public let link: String
  public let title: String

  public init(source: Source, identifier: String, link: String, title: String) {
    self.source = source
    self.identifier = identifier
    self.link = link
    self.title = title
  }

  /// A web page open in a browser. `nil` for pages that can't be reopened (blank or browser-internal pages).
  public static func webPage(url: String, title: String, source: Source) -> Anchor? {
    guard
      let components = URLComponents(string: url.trimmingCharacters(in: .whitespaces)),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host?.lowercased(), !host.isEmpty
    else { return nil }

    var path = components.percentEncodedPath
    while path.hasSuffix("/") { path.removeLast() }
    let query = (components.queryItems ?? [])
      .filter { !isTracking($0.name) }
      .map { "\($0.name)=\($0.value ?? "")" }
      .sorted()
      .joined(separator: "&")
    let identifier = "web:\(host)\(path)" + (query.isEmpty ? "" : "?\(query)")
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return Anchor(source: source, identifier: identifier, link: url, title: cleanTitle.isEmpty ? host : cleanTitle)
  }

  /// Fallback for apps unfocused can't look into: the app plus, when known, its window title.
  public static func appWindow(bundleID: String, appName: String, windowTitle: String?) -> Anchor {
    let window = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return Anchor(
      source: .app(bundleID),
      identifier: "app:\(bundleID)|\(window)",
      link: bundleID,
      title: window.isEmpty ? appName : "\(appName): \(window)"
    )
  }

  private static func isTracking(_ name: String) -> Bool {
    let lower = name.lowercased()
    return lower.hasPrefix("utm_")
      || ["fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid"].contains(lower)
  }
}
