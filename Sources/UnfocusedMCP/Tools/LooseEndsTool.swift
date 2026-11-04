public import UnfocusedCore

/// The Loose Ends, in the order Tie-off walks them.
public struct LooseEndsTool: MCPTool {
  public init() {}

  public let name = "loose_ends"
  public let description = ToolDescription.make(
    "Lists the Loose Ends: Open Loops with at least the threshold of active days without Engagement, most aged first. Each has its active days without Engagement and, for a Waiting Loop, the People to follow up with."
  )
  public let inputSchema: JSONValue = ["type": "object", "properties": [:]]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let looseEnds = try core.looseEnds()
    let items: [JSONValue] = looseEnds.map { aging in
      [
        "loop": aging.loop.json,
        "activeDaysWithoutEngagement": .number(Double(aging.activeDaysWithoutEngagement)),
        "followUp": .array(aging.followUp.map(\.json)),
      ]
    }
    return JSONValue.object([
      "threshold": .number(Double(try core.looseEndThreshold())),
      "looseEnds": .array(items),
    ]).pretty()
  }
}

extension Person {
  /// A Person as the Agent sees them.
  var json: JSONValue { ["id": .string(id.uuidString), "name": .string(name)] }
}
