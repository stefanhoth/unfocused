public import UnfocusedCore

/// When, where and why time went toward one Loop.
public struct WorkLogTool: MCPTool {
  public init() {}

  public let name = "work_log"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Lists when, where and why time went toward one Loop between two times, oldest first, each with seconds, text and the reason (anchor or focus). Get Loop ids from list_loops. At most 31 days and 500 stretches."
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
    let log = try core.workLog(for: loop.id, from: range.from, to: range.to)
    return ActivityTools.stretches(
      log,
      extra: ["loopId": .string(loop.id.uuidString), "title": .string(loop.title)]
    )
  }
}
