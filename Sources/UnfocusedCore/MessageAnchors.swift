import Foundation

extension Source {
  static let mailBundleID = "com.apple.mail"
  static let slackBundleID = "com.tinyspeck.slackmacgap"
}

extension Anchor {
  // MARK: Mail

  /// The exact Mail message, by its Message-ID header. Reopens with a `message:` link.
  /// `messageID` may come with or without angle brackets.
  public static func mailMessage(messageID: String, subject: String) -> Anchor? {
    var id = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
    if id.hasPrefix("<"), id.hasSuffix(">") { id = String(id.dropFirst().dropLast()) }
    guard !id.isEmpty, !id.contains(where: \.isWhitespace) else { return nil }
    let encoded =
      id.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "@.-_"))) ?? id
    let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
    return Anchor(
      source: .app(Source.mailBundleID),
      identifier: "mail:\(id)",
      link: "message://%3C\(encoded)%3E",
      title: cleanSubject.isEmpty ? "Mail message" : cleanSubject
    )
  }

  // MARK: Slack

  /// The exact Slack conversation or thread, from a message link copied in Slack, e.g.
  /// `https://acme.slack.com/archives/C024BE91L/p1700000000123456?thread_ts=1699999999.000100&cid=C024BE91L`.
  /// A reply and its thread's first message are the same Anchor: the thread.
  public static func slackLink(_ text: String, title: String? = nil) -> Anchor? {
    guard
      let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
      components.scheme == "https",
      let host = components.host?.lowercased(), host.hasSuffix(".slack.com")
    else { return nil }
    let parts = components.path.split(separator: "/").map(String.init)
    guard parts.count >= 2, parts[0] == "archives" else { return nil }
    let workspace = String(host.dropLast(".slack.com".count))
    let channel = parts[1]
    let threadTS =
      components.queryItems?.first { $0.name == "thread_ts" }?.value
      ?? parts.dropFirst(2).first.flatMap(Self.slackTimestamp)
    let identifier = "slack:\(workspace)/\(channel)" + (threadTS.map { "/\($0)" } ?? "")
    let defaultTitle = threadTS == nil ? "Slack conversation in \(workspace)" : "Slack thread in \(workspace)"
    return Anchor(source: .app(Source.slackBundleID), identifier: identifier, link: text, title: title ?? defaultTitle)
  }

  /// Slack's window title, when no message link is at hand: the conversation, not the thread.
  /// Handles "general (Channel) - Acme - Slack", "Ada Lovelace (DM) - Acme - Slack" and
  /// "Slack | general | Acme".
  public static func slackWindow(title windowTitle: String) -> Anchor? {
    var title = windowTitle.trimmingCharacters(in: .whitespaces)
    var parts: [String]
    if title.hasPrefix("Slack | ") {
      title.removeFirst("Slack | ".count)
      parts = title.components(separatedBy: " | ")
    } else if title.hasSuffix(" - Slack") {
      title.removeLast(" - Slack".count)
      parts = title.components(separatedBy: " - ")
    } else {
      return nil
    }
    parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard parts.count >= 2, let workspace = parts.last else { return nil }
    // Some titles lead with a section ("Thread", "Huddle"); the conversation is the part with a kind.
    let conversationPart =
      parts.dropLast().first { $0.hasSuffix(")") || $0.hasPrefix("#") } ?? parts[parts.count - 2]
    var conversation = conversationPart
    for suffix in [" (Channel)", " (Private Channel)", " (DM)", " (Group DM)"] where conversation.hasSuffix(suffix) {
      conversation.removeLast(suffix.count)
    }
    if conversation.hasPrefix("#") { conversation.removeFirst() }
    guard !conversation.isEmpty else { return nil }
    return Anchor(
      source: .app(Source.slackBundleID),
      identifier: "slack-window:\(workspace.lowercased())/\(conversation.lowercased())",
      link: Source.slackBundleID,
      title: "Slack: \(conversation) · \(workspace)"
    )
  }

  /// "p1700000000123456" → "1700000000.123456".
  private static func slackTimestamp(_ part: String) -> String? {
    guard part.hasPrefix("p"), part.count > 7, part.dropFirst().allSatisfy(\.isNumber) else { return nil }
    let digits = part.dropFirst()
    return "\(digits.dropLast(6)).\(digits.suffix(6))"
  }
}
