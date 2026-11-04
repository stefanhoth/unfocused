public import UnfocusedCore

/// Activity as attributed stretches, with the reason each counts toward a Loop or none.
public struct ActivityTool: MCPTool {
  public init() {}

  public let name = "activity"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Lists the user's Activity between two times as attributed stretches: what was open, for how long (seconds and text), the Loop id it counts toward (null for Unfocused time) and the reason (anchor, focus, unfocused or judged_unrelated). Oldest first; at most 31 days and 500 stretches."
  )
  public let inputSchema: JSONValue = [
    "type": "object", "properties": ActivityTools.rangeProperties, "required": ["from", "to"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let range = try ActivityTools.range(arguments)
    return ActivityTools.stretches(try core.attributedActivity(from: range.from, to: range.to))
  }
}
