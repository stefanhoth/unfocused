public import UnfocusedCore

/// Lists the Loops in one state.
public struct ListLoopsTool: MCPTool {
  public init() {}

  public let name = "list_loops"
  public let description = ToolDescription.make(
    "Lists Loops in one state: open, closed or let_go (Let go). Each Loop has an id to pass to get_loop."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": [
      "state": ["type": "string", "enum": ["open", "closed", "let_go"], "description": "Which Loops to list."]
    ],
    "required": ["state"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let state: LoopState
    switch try arguments.optionalString("state") {
    case "open": state = .open
    case "closed": state = .closed
    case "let_go": state = .letGo
    default: throw ToolError("Argument 'state' must be one of: open, closed, let_go.")
    }
    let loops = try core.loops(in: state)
    return JSONValue.object(["loops": .array(loops.map(\.json))]).pretty()
  }
}
