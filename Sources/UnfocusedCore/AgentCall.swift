public import Foundation

/// One `tools/call` an Agent made through `unfocused-mcp` (ADR 0007): when, who, which tool, and
/// whether it was refused because Agent access was off. It deliberately holds nothing else: no
/// Loop titles, Anchors, People, Activity or arguments, so the log line and the hand-off file made
/// from it can't leak them.
public struct AgentCall: Sendable, Equatable, Codable {
  public static let unknownAgent = "unknown"
  public static let maxAgentLength = 60

  public let date: Date
  /// The Agent's name from `clientInfo`, cleaned; `unknown` when it sent none.
  public let agent: String
  /// A tool unfocused offers, or `unknown` for any other name an Agent sent.
  public let tool: String
  public let refused: Bool

  public init(date: Date, agent: String?, tool: String, refused: Bool) {
    self.date = date
    self.agent = Self.clean(agent)
    self.tool = tool
    self.refused = refused
  }

  /// The one line written to the rotating log file.
  public var logLine: String {
    "tools/call \(tool) by \(agent)" + (refused ? " (refused: access was off)" : "")
  }

  /// The name is sent by the Agent, so it is trimmed, stripped of control characters and capped.
  private static func clean(_ name: String?) -> String {
    let flattened = String(
      String.UnicodeScalarView((name ?? "").unicodeScalars.map { $0.properties.generalCategory == .control ? " " : $0 })
    )
    let trimmed = String(flattened.trimmingCharacters(in: .whitespaces).prefix(maxAgentLength))
      .trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? unknownAgent : trimmed
  }
}

/// The hand-off from `unfocused-mcp` to Settings (docs/DECISIONS.md, 2026-11-04): the last call as a
/// small JSON file next to the logs, replaced atomically on every call. The binary opens the database
/// read-only, so the file is how the app learns of the last use.
public struct AgentCallStore: Sendable {
  public let fileURL: URL

  public init(directory: URL) {
    fileURL = directory.appendingPathComponent("agent-last-call.json")
  }

  /// Best effort: a failure to write must never fail the Agent's call.
  public func record(_ call: AgentCall) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(call) else { return }
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? data.write(to: fileURL, options: .atomic)
  }

  /// The last call, or `nil` when there was none or the file can't be read.
  public func last() -> AgentCall? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(AgentCall.self, from: data)
  }
}
