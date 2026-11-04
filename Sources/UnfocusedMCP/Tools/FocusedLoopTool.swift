public import UnfocusedCore

/// Which Loop is Focused, with its Where I left off.
public struct FocusedLoopTool: MCPTool {
  public init() {}

  public let name = "focused_loop"
  public let description = ToolDescription.make(
    "Returns the Loop that is Focused right now, with its Where I left off, or null if no Loop is Focused."
  )
  public let inputSchema: JSONValue = ["type": "object", "properties": [:]]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let focused = try core.focusedLoop()
    return JSONValue.object(["focused": focused?.json ?? .null]).pretty()
  }
}
