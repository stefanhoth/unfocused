public import UnfocusedCore

/// One Loop in full: Anchors, People, Where I left off, history and past Focus.
public struct GetLoopTool: MCPTool {
  public init() {}

  public let name = "get_loop"
  public let description = ToolDescription.make(
    "Returns one Loop in full: title, state, Anchors, People with direction (owed or waiting), Where I left off, history and past Focus. Get ids from list_loops or search_open_loops."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": ["id": ["type": "string", "description": "The Loop id, as returned by list_loops."]],
    "required": ["id"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let id = try arguments.uuid("id")
    guard let loop = try core.loop(id) else {
      throw ToolError("No Loop with id \(id.uuidString). Use list_loops or search_open_loops to find Loop ids.")
    }
    guard case .object(var fields) = loop.json else { return loop.json.pretty() }

    fields["anchors"] = .array(
      try core.anchors(of: id).map {
        [
          "source": .string($0.source.stored),
          "title": .string($0.title),
          "link": .string($0.link),
        ]
      }
    )
    fields["people"] = .array(
      try core.people(of: id).map {
        ["name": .string($0.person.name), "direction": .string($0.direction.rawValue)]
      }
    )
    fields["history"] = .array(
      try core.history(for: id).map {
        [
          "change": .string($0.change == .letGo ? "let_go" : $0.change.rawValue),
          "at": .string(ISO8601.string($0.at)),
        ]
      }
    )
    fields["pastFocus"] = .array(
      try core.focusSessions(for: id).map {
        [
          "start": .string(ISO8601.string($0.start)),
          "end": $0.end.map { .string(ISO8601.string($0)) } ?? .null,
          "seconds": .number($0.duration.rounded()),
        ]
      }
    )
    return JSONValue.object(fields).pretty()
  }
}
