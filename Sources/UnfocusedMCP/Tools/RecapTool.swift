public import UnfocusedCore

/// The Recap of a day or a week, as the Markdown the app copies.
public struct RecapTool: MCPTool {
  public init() {}

  public let name = "recap"
  public var requiredAccess: AgentAccessScope { .activity }
  public let description = ActivityTools.description(
    "Returns the Recap of a day or a week as Markdown: what was Closed, moved forward and Captured, and the Unfocused time. 'period' is day or week; 'date' (ISO 8601 with offset) picks the day or the week containing it and defaults to now."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": [
      "period": ["type": "string", "enum": ["day", "week"]],
      "date": ["type": "string", "description": "Optional, ISO 8601 with offset. Defaults to now."],
    ],
    "required": ["period"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    guard let period = RecapPeriod(rawValue: try arguments.string("period")) else {
      throw ToolError("Argument 'period' must be 'day' or 'week'.")
    }
    let date = try arguments.optionalString("date") == nil ? core.now : arguments.date("date")
    switch period {
    case .day: return try core.recap(day: date).markdown()
    case .week: return try core.recap(weekOf: date).markdown()
    }
  }
}

private enum RecapPeriod: String {
  case day
  case week
}
