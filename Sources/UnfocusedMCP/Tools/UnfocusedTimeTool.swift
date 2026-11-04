public import UnfocusedCore

/// Unfocused time in a range: Activity that didn't go toward the Focused Loop.
public struct UnfocusedTimeTool: MCPTool {
  public init() {}

  public let name = "unfocused_time"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Returns the Unfocused time between two times: Activity that didn't go toward the Focused Loop, in seconds and as text. It is reported plainly, not judged. At most 31 days."
  )
  public let inputSchema: JSONValue = [
    "type": "object", "properties": ActivityTools.rangeProperties, "required": ["from", "to"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let range = try ActivityTools.range(arguments)
    let time = try core.unfocusedTime(from: range.from, to: range.to)
    return JSONValue.object(ActivityTools.seconds(time)).pretty()
  }
}
