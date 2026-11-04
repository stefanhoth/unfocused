/// The one list of tools. `tools/list` and `tools/call` both read it, so they cannot drift apart.
///
/// One tool per line, each in its own file under `Tools/`. Keep the entries sorted by name so
/// tickets adding tools rarely touch the same line.
public enum ToolRegistry {
  public static let all: [any MCPTool] = [
    FocusedLoopTool()
  ]
}
