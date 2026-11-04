public import UnfocusedCore

/// Activity as attributed stretches, with the reason each counts toward a Loop or none.
public struct ActivityTool: MCPTool {
  public init() {}

  public let name = "activity"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Lists the user's Activity as attributed stretches (by default the last 2 hours; pass from and to for another range): what was open, with the page link when it was a web page, for how long (seconds and text), the Loop id it counts toward (null for Unfocused time) and the reason (anchor, focus, unfocused or judged_unrelated). Oldest first; at most 31 days and 500 stretches."
  )
  public let inputSchema: JSONValue = [
    "type": "object", "properties": ActivityTools.rangeProperties,
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let range = try ActivityTools.range(arguments, now: core.now)
    return ActivityTools.stretches(try core.attributedActivity(from: range.from, to: range.to))
  }
}
