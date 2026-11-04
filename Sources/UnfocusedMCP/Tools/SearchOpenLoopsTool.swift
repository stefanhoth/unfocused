public import UnfocusedCore

/// Finds Open Loops by words, Loose Ends first, like the panel's search.
public struct SearchOpenLoopsTool: MCPTool {
  public init() {}

  public let name = "search_open_loops"
  public let description = ToolDescription.make(
    "Finds Open Loops by words in their title, best match first, Loose Ends before the rest. Returns nothing for an empty query."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": ["query": ["type": "string", "description": "Words to look for in Loop titles."]],
    "required": ["query"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let query = try arguments.string("query")
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return JSONValue.object(["loops": .array([])]).pretty()
    }
    let matches = try core.searchOpenLoops(query)
    let looseEndIDs = Set(try core.looseEnds().map(\.loop.id))
    // Stable partition: Loose Ends first, each group keeping the match order.
    let ordered = matches.filter { looseEndIDs.contains($0.id) } + matches.filter { !looseEndIDs.contains($0.id) }
    let loops = ordered.map { loop -> JSONValue in
      guard case .object(var fields) = loop.json else { return loop.json }
      fields["looseEnd"] = .bool(looseEndIDs.contains(loop.id))
      return .object(fields)
    }
    return JSONValue.object(["loops": .array(loops)]).pretty()
  }
}
