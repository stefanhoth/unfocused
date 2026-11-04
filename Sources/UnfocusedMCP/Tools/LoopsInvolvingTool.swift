import Foundation
public import UnfocusedCore

/// A Person's Open Loops, with the direction (Owed or Waiting).
public struct LoopsInvolvingTool: MCPTool {
  public init() {}

  public let name = "loops_involving"
  public let description = ToolDescription.make(
    "Lists the Open Loops a Person is involved in, each with its direction: owed (the Person is waiting on the user) or waiting (the user is waiting on the Person). The name may be partial and in any case. If several People match, the candidates are returned instead of a guess: ask the user which one is meant."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": ["person": ["type": "string", "description": "A name or part of a name."]],
    "required": ["person"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let query = try arguments.string("person").trimmingCharacters(in: .whitespacesAndNewlines)
    let matches = try core.searchPeople(query)
    guard !matches.isEmpty else {
      return JSONValue.object(["message": .string("No Person called \"\(query)\".")]).pretty()
    }
    let exact = matches.filter { Self.key($0.name) == Self.key(query) }
    let resolved = exact.count == 1 ? exact[0] : (matches.count == 1 ? matches[0] : nil)
    guard let person = resolved else {
      return JSONValue.object([
        "message": .string("\(matches.count) People match \"\(query)\". Which one is meant? Ask the user."),
        "candidates": .array(matches.map(\.json)),
      ]).pretty()
    }
    let loops: [JSONValue] = try core.loops(involving: person.id)
      .filter { $0.state == .open }
      .map { loop in
        let direction = try core.people(of: loop.id).first { $0.person.id == person.id }?.direction
        var json = loop.json.object ?? [:]
        json["direction"] = direction.map { .string($0.rawValue) } ?? .null
        return .object(json)
      }
    return JSONValue.object(["person": person.json, "loops": .array(loops)]).pretty()
  }

  private static func key(_ name: String) -> String {
    name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }
}
