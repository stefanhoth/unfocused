public import UnfocusedCore

/// Time that went toward one Loop in a range.
public struct TimeSpentTool: MCPTool {
  public init() {}

  public let name = "time_spent"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Returns the time that went toward one Loop between two times, in seconds and as text. Get Loop ids from list_loops. At most 31 days."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": [
      "loop": ["type": "string", "description": "The Loop id, as returned by list_loops."],
      "from": ActivityTools.rangeProperties.object?["from"] ?? .null,
      "to": ActivityTools.rangeProperties.object?["to"] ?? .null,
    ],
    "required": ["loop", "from", "to"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let loop = try ActivityTools.requireLoop(arguments, core: core)
    let range = try ActivityTools.range(arguments)
    var fields = ActivityTools.seconds(try core.timeSpent(on: loop.id, from: range.from, to: range.to))
    fields["loopId"] = .string(loop.id.uuidString)
    fields["title"] = .string(loop.title)
    return JSONValue.object(fields).pretty()
  }
}
